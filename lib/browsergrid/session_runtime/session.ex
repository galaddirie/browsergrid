defmodule Browsergrid.SessionRuntime.Session do
  @moduledoc """
  Session actor supervising the per-session CDP process and persistence lifecycle.
  """
  use GenServer, restart: :transient

  alias Browsergrid.SessionRuntime
  alias Browsergrid.SessionRuntime.CDP
  alias Browsergrid.SessionRuntime.PortAllocator
  alias Browsergrid.SessionRuntime.StateStore

  require Logger

  @type option :: {:session_id, String.t()} | {:metadata, map()} | {:owner, map()} | {:limits, map()} | {:cdp, keyword()}

  defmodule State do
    @moduledoc false
    @enforce_keys [:id, :port, :profile_dir]
    defstruct id: nil,
              port: nil,
              profile_dir: nil,
              cdp: nil,
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
        cdp_opts = Keyword.get(opts, :cdp, [])

        case PortAllocator.lease(session_id, preferred_opts) do
          {:ok, port} ->
            case start_cdp(session_id, port, profile_dir, cdp_opts) do
              {:ok, cdp} ->
                case CDP.wait_until_ready(cdp, SessionRuntime.cdp_config()) do
                  :ok ->
                    state = %State{
                      id: session_id,
                      port: port,
                      profile_dir: profile_dir,
                      cdp: cdp,
                      metadata: Map.merge(snapshot["metadata"] || %{}, metadata),
                      owner: owner || snapshot["owner"],
                      limits: Map.merge(snapshot["limits"] || %{}, limits),
                      profile_snapshot: snapshot["profile_snapshot"],
                      ready?: true,
                      last_heartbeat_at: snapshot["last_seen_at"],
                      started_at: DateTime.utc_now(),
                      cdp_opts: cdp_opts
                    }

                    :ok = StateStore.put(session_id, build_snapshot(state))
                    {:ok, schedule_checkpoint(state)}

                  {:error, reason} ->
                    Logger.error("cdp readiness failed: #{inspect(reason)}")
                    CDP.stop(cdp)
                    PortAllocator.release(session_id)
                    {:stop, {:cdp_not_ready, reason}}
                end

              {:error, reason} ->
                Logger.error("session init failed to launch CDP: #{inspect(reason)}")
                PortAllocator.release(session_id)
                {:stop, {:cdp_launch_failed, reason}}
            end

          {:error, reason} ->
            Logger.error("session init failed to lease port: #{inspect(reason)}")
            {:stop, {:port_allocation_failed, reason}}
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

  def handle_info({:DOWN, ref, :process, _pid, reason}, %{cdp: %{ref: ref}} = state) do
    Logger.warning("cdp exited reason=#{inspect(reason)}")

    if state.restart_attempts < 3 do
      backoff_ms = trunc(:math.pow(2, state.restart_attempts) * 1_000)
      Process.send_after(self(), {:restart_cdp, state.restart_attempts + 1}, backoff_ms)
      {:noreply, %{state | cdp: nil, ready?: false, restart_attempts: state.restart_attempts + 1}}
    else
      {:stop, {:cdp_crashed, reason}, %{state | cdp: nil}}
    end
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

    if state.cdp do
      CDP.stop(state.cdp)
    end

    PortAllocator.release(state.id)

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
