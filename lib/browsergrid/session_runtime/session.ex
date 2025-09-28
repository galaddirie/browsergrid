defmodule Browsergrid.SessionRuntime.Session do
  @moduledoc """
  Session actor supervising the per-session CDP process and persistence lifecycle.
  """
  use GenServer, restart: :transient

  alias Browsergrid.SessionRuntime
  alias Browsergrid.SessionRuntime.Browser
  alias Browsergrid.SessionRuntime.CDP
  alias Browsergrid.SessionRuntime.PortAllocator
  alias Browsergrid.SessionRuntime.StateStore
  alias Browsergrid.SessionRuntime.SupportProcess

  require Logger

  @type option ::
          {:session_id, String.t()}
          | {:metadata, map()}
          | {:owner, map()}
          | {:limits, map()}
          | {:cdp, keyword()}
          | {:browser, keyword()}
          | {:support_processes, list()}

  defmodule State do
    @moduledoc false
    @enforce_keys [:id, :port, :browser_port, :profile_dir]
    defstruct id: nil,
              port: nil,
              browser_port: nil,
              browser_port_key: nil,
              browser_type: :chrome,
              profile_dir: nil,
              cdp: nil,
              browser: nil,
              support_processes: [],
              metadata: %{},
              owner: nil,
              limits: %{},
              profile_snapshot: nil,
              ready?: false,
              checkpoint_ref: nil,
              last_heartbeat_at: nil,
              started_at: nil,
              restart_attempts: 0,
              cdp_opts: []
  end

  @spec child_spec(keyword()) :: Supervisor.child_spec()
  def child_spec(opts) do
    session_id = Keyword.fetch!(opts, :session_id)

    %{
      id: {:session, session_id},
      start: {__MODULE__, :start_link, [opts]},
      restart: :transient,
      shutdown: 30_000
    }
  end

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    session_id = Keyword.fetch!(opts, :session_id)
    GenServer.start_link(__MODULE__, opts, name: SessionRuntime.via_tuple(session_id))
  end

  @impl true
  def init(opts) do
    Process.flag(:trap_exit, true)

    session_id = Keyword.fetch!(opts, :session_id)
    owner = Keyword.get(opts, :owner)
    metadata = Keyword.get(opts, :metadata, %{})
    limits = Keyword.get(opts, :limits, %{})

    Logger.metadata(session: session_id)
    Logger.info("starting session actor")

    snapshot =
      case StateStore.get(session_id) do
        {:ok, snap} -> snap
        :error -> %{}
      end

    case ensure_profile_dir(session_id, snapshot) do
      {:ok, profile_dir} ->
        preferred_opts = preferred_port_opts(snapshot)
        preferred_browser_opts = preferred_browser_port_opts(snapshot)

        cdp_opts = Keyword.get(opts, :cdp, [])
        browser_opts = Keyword.get(opts, :browser, [])
        browser_type = determine_browser_type(opts, snapshot, metadata)
        browser_opts = Keyword.put(browser_opts, :type, browser_type)
        browser_config =
          SessionRuntime.browser_config()
          |> Keyword.merge(browser_opts)
          |> Keyword.put(:type, browser_type)

        support_process_configs =
          SessionRuntime.support_processes_config() ++ Keyword.get(opts, :support_processes, [])

        browser_port_key = browser_port_key(session_id)

        support_processes = []
        browser = nil
        cdp = nil
        port = nil
        browser_port = nil

        with {:ok, browser_port} <- lease_browser_port(browser_port_key, preferred_browser_opts),
             {:ok, port} <- lease_cdp_port(session_id, preferred_opts),
             context <-
               build_process_context(session_id, profile_dir, browser_port, port, browser_type),
             {:ok, support_processes} <- start_support_processes(session_id, support_process_configs, context),
             {:ok, browser} <-
               wrap_browser_start(
                 Browser.start(session_id, browser_port, profile_dir, browser_opts, context, browser_type)
               ),
             :ok <- wrap_browser_ready(Browser.wait_until_ready(browser, browser_config)),
             {:ok, cdp_opts} <- ensure_browser_url(cdp_opts, browser_port),
             {:ok, cdp} <- wrap_cdp_start(start_cdp(session_id, port, profile_dir, cdp_opts)),
             :ok <- wrap_cdp_ready(CDP.wait_until_ready(cdp, SessionRuntime.cdp_config())) do
          state = %State{
            id: session_id,
            port: port,
            browser_port: browser_port,
            browser_port_key: browser_port_key,
            profile_dir: profile_dir,
            cdp: cdp,
            browser: browser,
            support_processes: support_processes,
            metadata: Map.merge(snapshot["metadata"] || %{}, metadata),
            owner: owner || snapshot["owner"],
            limits: Map.merge(snapshot["limits"] || %{}, limits),
            profile_snapshot: snapshot["profile_snapshot"],
            ready?: true,
            last_heartbeat_at: snapshot["last_seen_at"],
            started_at: DateTime.utc_now(),
            cdp_opts: cdp_opts,
            browser_type: browser_type
          }

          :ok = StateStore.put(session_id, build_snapshot(state))
          {:ok, schedule_checkpoint(state)}
        else
          {:error, reason} ->
            Logger.error("session init failed: #{inspect(reason)}")
            maybe_stop_cdp(cdp)
            maybe_stop_browser(browser)
            stop_support_processes(support_processes)
            if port, do: PortAllocator.release(session_id)
            if browser_port, do: PortAllocator.release(browser_port_key)
            {:stop, reason}
        end

      {:error, reason} ->
        Logger.error("session init failed to prepare profile dir: #{inspect(reason)}")
        {:stop, {:profile_dir_failed, reason}}
    end
  end

  @impl true
  def handle_call(:describe, _from, state) do
    description = %{
      id: state.id,
      port: state.port,
      browser_port: state.browser_port,
      browser_type: state.browser_type,
      profile_dir: state.profile_dir,
      metadata: state.metadata,
      owner: state.owner,
      limits: state.limits,
      ready?: state.ready?,
      node: Node.self(),
      checkpoint_at: state.last_heartbeat_at,
      started_at: state.started_at
    }

    {:reply, {:ok, description}, state}
  end

  def handle_call(:port, _from, state) do
    {:reply, {:ok, state.port}, state}
  end

  def handle_call(:snapshot, _from, state) do
    {:reply, {:ok, build_snapshot(state)}, state}
  end

  @impl true
  def handle_cast({:update_metadata, fun}, state) when is_function(fun, 1) do
    new_metadata = fun.(state.metadata)
    {:noreply, %{state | metadata: new_metadata}}
  end

  def handle_cast(:heartbeat, state) do
    now = DateTime.utc_now()
    :ok = StateStore.put(state.id, build_snapshot(%{state | last_heartbeat_at: now}))
    {:noreply, %{state | last_heartbeat_at: now}}
  end

  @impl true
  def handle_info(:checkpoint, state) do
    :ok = StateStore.put(state.id, build_snapshot(state))
    {:noreply, schedule_checkpoint(state)}
  end

  def handle_info({:DOWN, ref, :process, _pid, reason}, %{browser: %{ref: ref}} = state) do
    Logger.error("browser process exited reason=#{inspect(reason)}")
    {:stop, {:browser_exit, reason}, %{state | browser: nil}}
  end

  def handle_info({:DOWN, ref, :process, _pid, reason}, state) do
    case pop_support_process(state.support_processes, ref) do
      {nil, _remaining} ->
        handle_cdp_down(ref, reason, state)

      {%{name: name}, remaining} ->
        Logger.error("support process #{inspect(name)} exited reason=#{inspect(reason)}")
        {:stop, {:support_process_exit, {name, reason}}, %{state | support_processes: remaining}}
    end
  end

  defp handle_cdp_down(ref, reason, %{cdp: %{ref: ref}} = state) do
    Logger.warning("cdp exited reason=#{inspect(reason)}")

    if state.restart_attempts < 3 do
      backoff_ms = trunc(:math.pow(2, state.restart_attempts) * 1_000)
      Process.send_after(self(), {:restart_cdp, state.restart_attempts + 1}, backoff_ms)
      {:noreply, %{state | cdp: nil, ready?: false, restart_attempts: state.restart_attempts + 1}}
    else
      {:stop, {:cdp_crashed, reason}, %{state | cdp: nil}}
    end
  end

  defp handle_cdp_down(_ref, reason, state) do
    Logger.debug("unexpected process DOWN message reason=#{inspect(reason)}")
    {:noreply, state}
  end

  def handle_info({:restart_cdp, attempt}, state) do
    Logger.info("restarting cdp attempt=#{attempt}")

    case start_cdp(state.id, state.port, state.profile_dir, state.cdp_opts) do
      {:ok, cdp} ->
        case CDP.wait_until_ready(cdp, SessionRuntime.cdp_config()) do
          :ok ->
            Logger.info("cdp restarted successfully")
            {:noreply, %{state | cdp: cdp, ready?: true, restart_attempts: 0}}

          {:error, reason} ->
            Logger.error("cdp restart readiness failed: #{inspect(reason)}")
            CDP.stop(cdp)
            {:stop, {:cdp_restart_failed, reason}, state}
        end

      {:error, reason} ->
        Logger.error("cdp restart failed: #{inspect(reason)}")
        {:stop, {:cdp_restart_failed, reason}, state}
    end
  end

  def handle_info(message, state) do
    Logger.debug("unexpected session message: #{inspect(message)}")
    {:noreply, state}
  end

  @impl true
  def terminate(reason, state) do
    Logger.info("terminating session #{state.id} reason=#{inspect(reason)}")

    if state.checkpoint_ref do
      Process.cancel_timer(state.checkpoint_ref)
    end

    maybe_stop_cdp(state.cdp)
    maybe_stop_browser(state.browser)
    stop_support_processes(state.support_processes)

    PortAllocator.release(state.id)
    if state.browser_port_key, do: PortAllocator.release(state.browser_port_key)

    final_snapshot = build_snapshot(state)
    StateStore.put(state.id, final_snapshot)

    :ok
  end

  defp ensure_profile_dir(session_id, snapshot) do
    path = snapshot["profile_dir"] || default_profile_dir(session_id)

    case File.mkdir_p(path) do
      :ok -> {:ok, path}
      {:error, reason} -> {:error, {:profile_dir, reason}}
    end
  end

  defp default_profile_dir(session_id) do
    base = Application.get_env(:browsergrid, :session_profiles_path, System.tmp_dir!())
    Path.join([base, "sessions", session_id])
  end

  defp preferred_port_opts(%{"port" => port}) when is_integer(port), do: [preferred_port: port]

  defp preferred_port_opts(%{"port" => port}) when is_binary(port) do
    case Integer.parse(port) do
      {int, _} -> [preferred_port: int]
      :error -> []
    end
  end

  defp preferred_port_opts(_), do: []

  defp preferred_browser_port_opts(%{"browser_port" => port}) when is_integer(port),
    do: [preferred_port: port]

  defp preferred_browser_port_opts(%{"browser_port" => port}) when is_binary(port) do
    case Integer.parse(port) do
      {int, _} -> [preferred_port: int]
      :error -> []
    end
  end

  defp preferred_browser_port_opts(_), do: []

  defp lease_browser_port(key, opts) do
    case PortAllocator.lease(key, opts) do
      {:ok, port} -> {:ok, port}
      {:error, reason} -> {:error, {:browser_port_allocation_failed, reason}}
    end
  end

  defp lease_cdp_port(session_id, opts) do
    case PortAllocator.lease(session_id, opts) do
      {:ok, port} -> {:ok, port}
      {:error, reason} -> {:error, {:port_allocation_failed, reason}}
    end
  end

  defp build_process_context(session_id, profile_dir, browser_port, cdp_port, browser_type) do
    %{
      session_id: session_id,
      profile_dir: profile_dir,
      browser_port: browser_port,
      remote_debugging_port: browser_port,
      cdp_port: cdp_port,
      browser_type: browser_type
    }
  end

  defp start_support_processes(_session_id, [], _context), do: {:ok, []}

  defp start_support_processes(session_id, configs, context) do
    Enum.reduce_while(configs, {:ok, []}, fn config, {:ok, acc} ->
      case SupportProcess.start(session_id, config, context) do
        {:ok, process} -> {:cont, {:ok, [process | acc]}}
        {:error, reason} ->
          name = Keyword.get(config, :name, :support)
          {:halt, {:error, {:support_process_failed, name, reason, acc}}}
      end
    end)
    |> case do
      {:ok, processes} -> {:ok, Enum.reverse(processes)}
      {:error, {:support_process_failed, name, reason, started}} ->
        Enum.each(started, &SupportProcess.stop/1)
        {:error, {:support_process_failed, name, reason}}
    end
  end

  defp ensure_browser_url(cdp_opts, browser_port) do
    if Keyword.has_key?(cdp_opts, :browser_url) do
      {:ok, cdp_opts}
    else
      {:ok, Keyword.put(cdp_opts, :browser_url, "ws://127.0.0.1:#{browser_port}/devtools/browser")}
    end
  end

  defp determine_browser_type(opts, snapshot, metadata) do
    opts
    |> Keyword.get(:browser_type)
    |> case do
      nil -> snapshot_browser_type(snapshot, metadata)
      type -> normalize_browser_type(type)
    end
  end

  defp snapshot_browser_type(snapshot, metadata) do
    metadata_type =
      metadata["browser_type"] ||
        get_in(metadata, ["options", "browser_type"])

    snapshot_type =
      snapshot["browser_type"] ||
        get_in(snapshot, ["metadata", "browser_type"]) ||
        get_in(snapshot, ["metadata", "options", "browser_type"])

    metadata_type || snapshot_type || :chrome
    |> normalize_browser_type()
  end

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

  defp normalize_browser_type(_), do: :chrome

  defp wrap_browser_start({:ok, browser}), do: {:ok, browser}
  defp wrap_browser_start({:error, reason}), do: {:error, {:browser_start_failed, reason}}

  defp wrap_browser_ready(:ok), do: :ok
  defp wrap_browser_ready({:error, reason}), do: {:error, {:browser_not_ready, reason}}

  defp wrap_cdp_start({:ok, cdp}), do: {:ok, cdp}
  defp wrap_cdp_start({:error, reason}), do: {:error, {:cdp_launch_failed, reason}}

  defp wrap_cdp_ready(:ok), do: :ok
  defp wrap_cdp_ready({:error, reason}), do: {:error, {:cdp_not_ready, reason}}

  defp maybe_stop_cdp(nil), do: :ok
  defp maybe_stop_cdp(cdp), do: CDP.stop(cdp)

  defp maybe_stop_browser(nil), do: :ok
  defp maybe_stop_browser(browser), do: Browser.stop(browser)

  defp stop_support_processes(processes) do
    Enum.each(processes, &SupportProcess.stop/1)
  end

  defp pop_support_process(processes, ref) do
    {matched, remaining} = Enum.split_with(processes, fn p -> p.ref == ref end)

    case matched do
      [process | _] -> {process, remaining}
      [] -> {nil, processes}
    end
  end

  defp browser_port_key(session_id), do: session_id <> "-browser"

  defp start_cdp(session_id, port, profile_dir, opts) do
    case CDP.start(session_id, port, profile_dir: profile_dir, cdp: opts) do
      {:ok, cdp} -> {:ok, cdp}
      {:error, reason} -> {:error, reason}
    end
  end

  defp build_snapshot(state) do
    now = DateTime.utc_now()

    %{
      "id" => state.id,
      "node" => Atom.to_string(Node.self()),
      "port" => state.port,
      "browser_port" => state.browser_port,
      "browser_type" => state.browser_type,
      "profile_dir" => state.profile_dir,
      "profile_snapshot" => state.profile_snapshot,
      "metadata" => state.metadata,
      "owner" => state.owner,
      "limits" => state.limits,
      "ready" => state.ready?,
      "last_seen_at" => state.last_heartbeat_at || now,
      "updated_at" => now
    }
  end

  defp schedule_checkpoint(%State{} = state) do
    interval = SessionRuntime.checkpoint_interval_ms()

    if state.checkpoint_ref do
      Process.cancel_timer(state.checkpoint_ref)
    end

    ref = Process.send_after(self(), :checkpoint, interval)
    %{state | checkpoint_ref: ref, last_heartbeat_at: DateTime.utc_now()}
  end
end
