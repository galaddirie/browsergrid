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
    profile_dir = Keyword.fetch!(opts, :profile_dir)
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
    ready_path = opts[:ready_path] || SessionRuntime.cdp_config()[:ready_path] || "/healthz"

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
    args =
      Keyword.get(config, :args, []) ++
        ["--port", Integer.to_string(port), "--profile", profile_dir]

    env = Keyword.get(config, :env, [])
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
        request = "GET #{path} HTTP/1.1\r\nHost: 127.0.0.1\r\nConnection: close\r\n\r\n"
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
end
