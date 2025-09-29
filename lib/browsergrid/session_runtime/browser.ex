defmodule Browsergrid.SessionRuntime.Browser do
  @moduledoc """
  Launches and monitors the per-session browser process that exposes a local
  DevTools endpoint.
  """

  alias Browsergrid.SessionRuntime
  alias Browsergrid.SessionRuntime.Browser.Adapters.{Chrome, Chromium, Firefox, Default}

  require Logger

  @type t :: %{
          mode: :stub | :command,
          pid: pid(),
          ref: reference() | nil,
          port: non_neg_integer(),
          profile_dir: String.t(),
          command: String.t() | nil
        }

  @adapters %{
    chrome: Chrome,
    chromium: Chromium,
    firefox: Firefox
  }

  @spec start(String.t(), non_neg_integer(), String.t(), keyword(), map(), atom()) ::
          {:ok, t()} | {:error, term()}
  def start(session_id, port, profile_dir, opts, context, browser_type \\ :chrome) do
    config = Keyword.merge(SessionRuntime.browser_config(), opts)
    mode = Keyword.get(config, :mode, :command)
    type = normalize_browser_type(Keyword.get(config, :type, browser_type))
    adapter = adapter_for(type)

    context =
      context
      |> Map.put(:profile_dir, profile_dir)
      |> Map.put(:remote_debugging_port, port)
      |> Map.put(:browser_type, type)

    case mode do
      :stub ->
        pid = spawn_link(fn -> stub_loop() end)
        ref = Process.monitor(pid)
        {:ok, %{mode: :stub, pid: pid, ref: ref, port: port, profile_dir: profile_dir, command: nil}}

      _ ->
        launch_browser(session_id, port, profile_dir, config, adapter, context)
    end
  end

  defp launch_browser(session_id, port, profile_dir, config, adapter, context) do
    with {:ok, command} <- resolve_command(config, adapter),
         {:ok, env} <- build_env(config, adapter, context),
         {:ok, args} <- build_args(config, adapter, context) do
      cd = Keyword.get(config, :cd)
      log_prefix = "session=#{session_id}"

      muon_opts = maybe_put([stderr_to_stdout: true, env: env], :cd, cd)

      Logger.info(
        "launching #{context.browser_type} browser command '#{command}' with args #{inspect(args)}"
      )

      case MuonTrap.Daemon.start_link(command, args, muon_opts) do
        {:ok, pid} ->
          ref = Process.monitor(pid)
          Logger.metadata(session: session_id)
          Logger.info("browser process spawned pid=#{inspect(pid)} #{log_prefix}")

          {:ok,
           %{
             mode: :command,
             pid: pid,
             ref: ref,
             port: port,
             profile_dir: profile_dir,
             command: command
           }}

        {:error, reason} ->
          Logger.error("failed to spawn browser process: #{inspect(reason)}")
          {:error, reason}
      end
    end
  end

  @spec wait_until_ready(t(), keyword()) :: :ok | {:error, :timeout | term()}
  def wait_until_ready(%{mode: :stub}, _config), do: :ok

  def wait_until_ready(%{mode: :command} = state, config) do
    poll_ms = Keyword.get(config, :ready_poll_interval_ms) || 200
    timeout_ms = Keyword.get(config, :ready_timeout_ms) || 15_000
    ready_path = Keyword.get(config, :ready_path) || "/json/version"
    started_at = System.monotonic_time(:millisecond)

    wait_loop(state, ready_path, poll_ms, timeout_ms, started_at)
  end

  @spec stop(t()) :: :ok
  def stop(%{mode: :stub, pid: pid, ref: ref}) do
    if Process.alive?(pid), do: Process.exit(pid, :normal)
    if ref, do: Process.demonitor(ref, [:flush])
    :ok
  end

  def stop(%{mode: :command, pid: pid, ref: ref}) do
    if Process.alive?(pid), do: Process.exit(pid, :shutdown)
    if ref, do: Process.demonitor(ref, [:flush])
    :ok
  end

  defp resolve_command(config, adapter) do
    case config |> Keyword.get(:command) |> blank_to_nil() do
      command when is_binary(command) ->
        {:ok, command}

      _ ->
        case blank_to_nil(System.get_env("BROWSERGRID_BROWSER_BIN")) do
          command when is_binary(command) ->
            {:ok, command}

          _ ->
            candidates =
              config
              |> Keyword.get(:command_candidates, [])
              |> List.wrap()
              |> Enum.map(&to_string/1)
              |> Enum.concat(adapter.command_candidates())

            case find_executable(candidates) do
              {:ok, command} -> {:ok, command}
              :error ->
                Logger.error(
                  "unable to locate browser executable. searched candidates=#{inspect(candidates)}"
                )

                {:error, {:command_not_found, candidates}}
            end
        end
    end
  end

  defp build_env(config, adapter, context) do
    adapter_env = normalize_env(adapter.default_env(context))
    config_env = normalize_env(Keyword.get(config, :env, []))

    env =
      adapter_env
      |> env_to_map()
      |> Map.merge(env_to_map(config_env))
      |> Enum.map(fn {key, value} -> {key, render(value, context)} end)

    {:ok, env}
  end

  defp build_args(config, adapter, context) do
    inject_defaults? = Keyword.get(config, :inject_defaults?, true)

    defaults =
      if inject_defaults? do
        base_args =
          []
          |> push_arg("--remote-debugging-port", context.remote_debugging_port)
          |> push_arg(
            "--remote-debugging-address",
            Keyword.get(config, :remote_debugging_address, "127.0.0.1")
          )
          |> push_arg("--user-data-dir", context.profile_dir)

        base_args
        |> maybe_push_headless(context)
        |> maybe_push_window_size(context)
        |> maybe_push_scale(context)
        |> append_args(adapter.default_args(context), context)
        |> append_args(Keyword.get(config, :default_args, []), context)
      else
        []
      end

    final_args = append_args(defaults, Keyword.get(config, :args, []), context)
    {:ok, final_args}
  end

  defp wait_loop(state, path, poll_ms, timeout_ms, started_at) do
    now = System.monotonic_time(:millisecond)
    elapsed = now - started_at

    cond do
      elapsed > timeout_ms ->
        {:error, :timeout}

      not Process.alive?(state.pid) ->
        {:error, :process_exit}

      ready?(state.port, path) ->
        :ok

      true ->
        Process.sleep(poll_ms)
        wait_loop(state, path, poll_ms, timeout_ms, started_at)
    end
  end

  defp ready?(port, path) do
    case :gen_tcp.connect({127, 0, 0, 1}, port, [:binary, active: false], 500) do
      {:ok, socket} ->
        request =
          "GET #{path} HTTP/1.1\r\nHost: 127.0.0.1:#{port}\r\nConnection: close\r\n\r\n"

        :gen_tcp.send(socket, request)
        result = :gen_tcp.recv(socket, 0, 500)
        :gen_tcp.close(socket)
        match?({:ok, _}, result)

      {:error, _reason} ->
        false
    end
  end

  defp stub_loop do
    receive do
      :stop -> :ok
    after
      60_000 -> stub_loop()
    end
  end

  defp append_args(args, additions, context) do
    additions
    |> List.wrap()
    |> Enum.reduce(args, fn addition, acc ->
      case addition do
        {flag, value} ->
          flag = render(flag, context)

          case value do
            nil -> push_flag_list(acc, [flag])
            _ -> push_arg(acc, flag, render(value, context))
          end

        value ->
          push_flag_list(acc, [render(value, context)])
      end
    end)
  end

  defp push_arg(args, _flag, nil), do: args

  defp push_arg(args, flag, value) do
    args ++ [to_string(flag), to_string(value)]
  end

  defp push_flag_list(args, []), do: args

  defp push_flag_list(args, list) when is_list(list) do
    args ++ Enum.map(list, &to_string/1)
  end

  defp maybe_push_headless(args, %{headless: true}) do
    push_flag_list(args, ["--headless=new"])
  end

  defp maybe_push_headless(args, %{headless: false}) do
    case headless_requirement() do
      :ok ->
        args

      {:force, reason} ->
        Logger.warning("Forcing headless mode for browser session (#{format_headless_reason(reason)})")
        push_flag_list(args, ["--headless=new"])
    end
  end

  defp maybe_push_headless(args, _), do: args

  defp headless_requirement do
    case System.get_env("DISPLAY") do
      nil -> {:force, :display_not_set}
      "" -> {:force, :display_not_set}
      display ->
        if display_available?(display) do
          :ok
        else
          {:force, {:display_unreachable, display}}
        end
    end
  end

  defp display_available?(display) when is_binary(display) do
    trimmed = String.trim(display)

    cond do
      trimmed == "" -> false

      String.starts_with?(trimmed, ":") ->
        trimmed
        |> String.trim_leading(":")
        |> parse_display_number()
        |> case do
          {:ok, number} ->
            unix_display_available?(number) or tcp_display_reachable?("127.0.0.1", 6_000 + number)

          :error ->
            false
        end

      true ->
        case String.split(trimmed, ":", parts: 2) do
          [host_part, rest] ->
            host = if host_part in [nil, ""], do: "127.0.0.1", else: host_part

            rest
            |> parse_display_number()
            |> case do
              {:ok, number} -> tcp_display_reachable?(host, 6_000 + number)
              :error -> false
            end

          _other ->
            false
        end
    end
  end

  defp display_available?(_), do: false

  defp parse_display_number(value) do
    value
    |> String.split(".", parts: 2)
    |> List.first()
    |> case do
      nil -> :error
      digits ->
        case Integer.parse(digits) do
          {number, _rest} -> {:ok, number}
          :error -> :error
        end
    end
  end

  defp unix_display_available?(number) when is_integer(number) and number >= 0 do
    path = "/tmp/.X11-unix/X" <> Integer.to_string(number)
    File.exists?(path)
  end

  defp unix_display_available?(_), do: false

  defp tcp_display_reachable?(host, port) when is_binary(host) and is_integer(port) do
    try do
      case :gen_tcp.connect(String.to_charlist(host), port, [:binary, active: false], 200) do
        {:ok, socket} ->
          :gen_tcp.close(socket)
          true

        {:error, _reason} ->
          false
      end
    rescue
      _ -> false
    end
  end

  defp tcp_display_reachable?(_, _), do: false

  defp format_headless_reason(:display_not_set), do: "DISPLAY not set"

  defp format_headless_reason({:display_unreachable, display}) do
    "DISPLAY '#{display}' is not reachable"
  end

  defp format_headless_reason(_), do: "unknown reason"

  defp maybe_push_window_size(args, %{screen_width: width, screen_height: height})
       when is_number(width) and is_number(height) do
    size = "#{round(width)},#{round(height)}"
    push_flag_list(args, ["--window-size=#{size}"])
  end

  defp maybe_push_window_size(args, _context), do: args

  defp maybe_push_scale(args, %{screen_scale: scale}) when is_number(scale) and scale > 0 do
    formatted = format_scale(scale)
    scaled_args = ["--force-device-scale-factor=#{formatted}", "--high-dpi-support=#{formatted}"]
    push_flag_list(args, scaled_args)
  end

  defp maybe_push_scale(args, %{screen_dpi: dpi}) when is_number(dpi) and dpi > 0 do
    factor = dpi / 96
    formatted = format_scale(factor)
    push_flag_list(args, ["--force-device-scale-factor=#{formatted}", "--high-dpi-support=#{formatted}"])
  end

  defp maybe_push_scale(args, _context), do: args

  defp format_scale(value) when is_integer(value), do: Integer.to_string(value)

  defp format_scale(value) when is_float(value) do
    value
    |> Float.round(4)
    |> :erlang.float_to_binary([:compact])
  end

  defp format_scale(value), do: to_string(value)

  defp render(value, context) when is_binary(value), do: interpolate(value, context)
  defp render(value, _context) when is_atom(value), do: Atom.to_string(value)
  defp render(value, _context), do: to_string(value)

  defp interpolate(value, context) when is_binary(value) do
    Enum.reduce(context, value, fn {key, replacement}, acc ->
      String.replace(acc, "{#{key}}", to_string(replacement || ""))
    end)
  end

  defp interpolate(value, _context), do: to_string(value || "")

  defp find_executable(candidates) do
    candidates
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.reduce_while(:error, fn candidate, _acc ->
      case executable_from_candidate(candidate) do
        {:ok, path} -> {:halt, {:ok, path}}
        :error -> {:cont, :error}
      end
    end)
  end

  defp executable_from_candidate(candidate) do
    cond do
      Path.type(candidate) in [:absolute, :volumetric] or
          String.starts_with?(candidate, "./") or
          String.starts_with?(candidate, "../") ->
        if executable?(candidate), do: {:ok, candidate}, else: :error

      true ->
        case System.find_executable(candidate) do
          nil ->
            if executable?(candidate), do: {:ok, candidate}, else: :error

          path ->
            {:ok, path}
        end
    end
  end

  defp executable?(path) do
    File.exists?(path) and File.regular?(path) and File.access?(path, :execute)
  end

  defp blank_to_nil(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp blank_to_nil(value), do: value

  defp normalize_env(env) do
    env
    |> List.wrap()
    |> Enum.reduce([], fn
      {key, value}, acc -> [{to_string(key), to_string(value)} | acc]
      binary, acc when is_binary(binary) ->
        case String.split(binary, "=", parts: 2) do
          [k, v] -> [{k, v} | acc]
          _ -> acc
        end
      _other, acc -> acc
    end)
    |> Enum.reverse()
  end

  defp env_to_map(list), do: Map.new(list)

  defp maybe_put(list, _key, nil), do: list
  defp maybe_put(list, key, value), do: Keyword.put(list, key, value)

  defp normalize_browser_type(nil), do: :chrome

  defp normalize_browser_type(type) when is_atom(type) do
    case type do
      :chrome -> :chrome
      :chromium -> :chromium
      :firefox -> :firefox
      _ -> :chrome
    end
  end

  defp normalize_browser_type(type) when is_binary(type) do
    case String.downcase(type) do
      "chrome" -> :chrome
      "chromium" -> :chromium
      "firefox" -> :firefox
      _ -> :chrome
    end
  end

  defp adapter_for(type) do
    Map.get(@adapters, type, Default)
  end
end
