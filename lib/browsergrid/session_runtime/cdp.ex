defmodule Browsergrid.SessionRuntime.CDP do
  @moduledoc """
  Launches and monitors the per-session Go CDP API process.
  """
  alias Browsergrid.SessionRuntime

  require Logger

  @type t :: %{
          mode: :stub | :command,
          pid: pid(),
          ref: reference() | nil,
          port: non_neg_integer(),
          profile_dir: String.t()
        }

  @spec start(String.t(), non_neg_integer(), keyword()) :: {:ok, t()} | {:error, term()}
  def start(session_id, port, opts) do
    profile_dir = Keyword.get(opts, :profile_dir)
    config = Keyword.merge(SessionRuntime.cdp_config(), Keyword.get(opts, :cdp, []))
    mode = Keyword.get(config, :mode, :command)

    case mode do
      :stub ->
        pid = spawn_link(fn -> stub_loop() end)
        ref = Process.monitor(pid)
        {:ok, %{mode: :stub, pid: pid, ref: ref, port: port, profile_dir: profile_dir}}

      _ ->
        command = Keyword.get(config, :command)

        if command do
          do_start_process(session_id, command, port, profile_dir, config)
        else
          Logger.error("No CDP command configured; falling back to stub mode")
          pid = spawn_link(fn -> stub_loop() end)
          ref = Process.monitor(pid)
          {:ok, %{mode: :stub, pid: pid, ref: ref, port: port, profile_dir: profile_dir}}
        end
    end
  end

  @spec wait_until_ready(t(), keyword()) :: :ok | {:error, :timeout | term()}
  def wait_until_ready(%{mode: :stub}, _opts), do: :ok

  def wait_until_ready(%{mode: :command} = state, opts) do
    poll_ms = opts[:ready_poll_interval_ms] || SessionRuntime.cdp_config()[:ready_poll_interval_ms] || 200
    timeout_ms = opts[:ready_timeout_ms] || SessionRuntime.cdp_config()[:ready_timeout_ms] || 5_000
    started_at = System.monotonic_time(:millisecond)
    ready_path = opts[:ready_path] || SessionRuntime.cdp_config()[:ready_path] || "/health"

    wait_loop(state, poll_ms, timeout_ms, started_at, ready_path)
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

  defp do_start_process(session_id, command, port, profile_dir, config) do
    with {:ok, env} <- build_env(config),
         {:ok, args} <- build_args(port, config) do
      cd = Keyword.get(config, :cd)
      log_prefix = "session=#{session_id}"

      muon_opts = maybe_put([stderr_to_stdout: true, env: env], :cd, cd)

      Logger.info("launching CDP command '#{command}' with args #{inspect(args)}")

      case MuonTrap.Daemon.start_link(command, args, muon_opts) do
        {:ok, pid} ->
          ref = Process.monitor(pid)
          Logger.metadata(session: session_id)
          Logger.info("cdp process spawned pid=#{inspect(pid)} #{log_prefix}")
          {:ok, %{mode: :command, pid: pid, ref: ref, port: port, profile_dir: profile_dir}}

        {:error, reason} ->
          Logger.error("failed to spawn cdp process: #{inspect(reason)}")
          {:error, reason}
      end
    end
  end

  defp stub_loop do
    receive do
      :stop -> :ok
    after
      60_000 -> stub_loop()
    end
  end

  defp wait_loop(state, poll_ms, timeout_ms, started_at, ready_path) do
    now = System.monotonic_time(:millisecond)
    elapsed = now - started_at

    cond do
      elapsed > timeout_ms ->
        {:error, :timeout}

      not Process.alive?(state.pid) ->
        {:error, :process_exit}

      ready?(state.port, ready_path) ->
        :ok

      true ->
        Process.sleep(poll_ms)
        wait_loop(state, poll_ms, timeout_ms, started_at, ready_path)
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

  defp maybe_put(list, _key, nil), do: list
  defp maybe_put(list, key, value), do: Keyword.put(list, key, value)

  defp build_env(config) do
    env = config |> Keyword.get(:env, []) |> normalize_env()
    {:ok, env}
  end

  defp build_args(port, config) do
    with {:ok, browser_url} <- fetch_browser_url(config) do
      dynamic_args =
        []
        |> push_arg("--port", Integer.to_string(port))
        |> push_arg("--browser-url", browser_url)
        |> push_arg("--frontend-url", Keyword.get(config, :frontend_url))
        |> push_arg("--max-message-size", maybe_to_string(Keyword.get(config, :max_message_size)))
        |> push_arg(
          "--connection-timeout",
          maybe_to_string(Keyword.get(config, :connection_timeout_seconds))
        )

      user_args =
        config
        |> Keyword.get(:args, [])
        |> List.wrap()
        |> Enum.map(&to_string/1)

      {:ok, dynamic_args ++ user_args}
    end
  end

  defp normalize_env(env) when is_list(env) do
    Enum.reduce(env, [], fn
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

  defp normalize_env(_), do: []

  defp maybe_to_string(nil), do: nil
  defp maybe_to_string(value), do: to_string(value)

  defp push_arg(args, _flag, nil), do: args
  defp push_arg(args, _flag, ""), do: args
  defp push_arg(args, flag, value), do: args ++ [flag, to_string(value)]

  defp fetch_browser_url(config) do
    case Keyword.get(config, :browser_url) do
      url when is_binary(url) and url != "" -> {:ok, url}
      nil ->
        Logger.error(
          "BrowserMux requires a browser_url; provide it via :browser_url in SessionRuntime config or options.browser_mux"
        )

        {:error, :missing_browser_url}

      other ->
        Logger.error("Invalid browser_url configuration: #{inspect(other)}")
        {:error, :invalid_browser_url}
    end
  end
end
