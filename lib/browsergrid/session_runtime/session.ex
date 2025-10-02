defmodule Browsergrid.SessionRuntime.Session do
  @moduledoc """
  Session actor responsible for orchestrating the lifecycle of a per-session
  browser pod and persisting runtime metadata. The actor keeps the legacy API
  surface (describe, endpoint, metadata updates) while delegating process
  management to Kubernetes via `Browsergrid.SessionRuntime.Browser`.
  """
  use GenServer, restart: :transient

  alias Browsergrid.SessionRuntime
  alias Browsergrid.SessionRuntime.Browser
  alias Browsergrid.SessionRuntime.StateStore

  require Logger

  defmodule State do
    @moduledoc false
    @enforce_keys [:id, :profile_dir]
    defstruct [
      :id,
      :profile_dir,
      :browser,
      :checkpoint_ref,
      :endpoint,
      :last_error,
      browser_type: :chrome,
      metadata: %{},
      owner: nil,
      limits: %{},
      profile_snapshot: nil,
      ready?: false,
      last_heartbeat_at: nil,
      started_at: nil,
      restart_attempts: 0
    ]
  end


  def child_spec(opts) do
    session_id = Keyword.fetch!(opts, :session_id)

    %{
      id: {:session, session_id},
      start: {__MODULE__, :start_link, [opts]},
      restart: :transient,
      shutdown: 30_000
    }
  end

  def start_link(opts) do
    session_id = Keyword.fetch!(opts, :session_id)
    GenServer.start_link(__MODULE__, opts, name: SessionRuntime.via_tuple(session_id))
  end

  @impl true
  def init(opts) do
    Process.flag(:trap_exit, true)

    session_id = Keyword.fetch!(opts, :session_id)
    Logger.metadata(session: session_id)
    Logger.info("Starting session actor")

    with {:ok, snapshot} <- fetch_or_default_snapshot(session_id),
         {:ok, state} <- build_initial_state(session_id, opts, snapshot),
         {:ok, browser} <- start_and_wait_for_browser(state),
         state <- finalize_state(state, browser) do
      StateStore.put(session_id, build_snapshot(state))
      {:ok, schedule_checkpoint(state)}
    else
      {:error, reason} = error ->
        Logger.error("Session init failed: #{inspect(reason)}")
        {:stop, reason}
    end
  end

  @impl true
  def handle_call(:describe, _from, state) do
    {:reply, {:ok, describe(state)}, state}
  end

  def handle_call(:endpoint, _from, %{endpoint: nil} = state) do
    {:reply, {:error, :not_ready}, state}
  end

  def handle_call(:endpoint, _from, state) do
    {:reply, {:ok, state.endpoint}, state}
  end

  @impl true
  def handle_cast({:update_metadata, fun}, state) when is_function(fun, 1) do
    {:noreply, %{state | metadata: fun.(state.metadata)}}
  end

  def handle_cast(:heartbeat, state) do
    now = DateTime.utc_now()
    StateStore.put(state.id, build_snapshot(%{state | last_heartbeat_at: now}))
    {:noreply, %{state | last_heartbeat_at: now}}
  end

  @impl true
  def handle_info(:checkpoint, state) do
    StateStore.put(state.id, build_snapshot(state))
    {:noreply, schedule_checkpoint(state)}
  end

  def handle_info(msg, state) do
    Logger.debug("Unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end

  @impl true
  def terminate(reason, state) do
    Logger.info("Terminating session #{state.id}, reason: #{inspect(reason)}")

    if state.checkpoint_ref, do: Process.cancel_timer(state.checkpoint_ref)
    if state.browser, do: Browser.stop(state.browser)

    StateStore.put(state.id, build_snapshot(state))
    :ok
  end

  defp fetch_or_default_snapshot(session_id) do
    case StateStore.get(session_id) do
      {:ok, snap} -> {:ok, snap}
      :error -> {:ok, %{}}
    end
  end

  defp build_initial_state(session_id, opts, snapshot) do
    with {:ok, profile_dir} <- ensure_profile_dir(session_id, snapshot),
         metadata <- merge_metadata(opts, snapshot),
         browser_type <- determine_browser_type(opts, snapshot, metadata) do
      state = %State{
        id: session_id,
        profile_dir: profile_dir,
        browser_type: browser_type,
        metadata: Map.put(metadata, "browser_type", browser_type),
        owner: Keyword.get(opts, :owner) || snapshot["owner"],
        limits: Map.merge(snapshot["limits"] || %{}, Keyword.get(opts, :limits, %{})),
        profile_snapshot: snapshot["profile_snapshot"],
        last_heartbeat_at: snapshot["last_seen_at"],
        started_at: DateTime.utc_now()
      }

      {:ok, state}
    end
  end

  defp start_and_wait_for_browser(state) do
    browser_opts = []
    browser_config = SessionRuntime.browser_config()
    context = build_context(state)

    with {:ok, browser} <- Browser.start(state.id, nil, state.profile_dir, browser_opts, context, state.browser_type),
         {:ok, ready_browser} <- Browser.wait_until_ready(browser, browser_config) do
      {:ok, ready_browser}
    else
      {:error, reason} ->
        {:error, {:browser_failed, reason}}
    end
  end

  defp finalize_state(state, browser) do
    %{state |
      browser: browser,
      endpoint: build_endpoint(browser),
      ready?: true
    }
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

  defp merge_metadata(opts, snapshot) do
    snapshot_metadata = snapshot["metadata"] || %{}
    opts_metadata = Keyword.get(opts, :metadata, %{})
    Map.merge(snapshot_metadata, opts_metadata)
  end

  defp determine_browser_type(opts, snapshot, metadata) do
    [
      opts[:browser] && Keyword.get(opts[:browser], :type),
      snapshot["browser_type"],
      Map.get(metadata, "browser_type")
    ]
    |> Enum.find(&normalize_browser_type/1)
    |> normalize_browser_type()
    |> Kernel.||(:chrome)
  end

  defp normalize_browser_type(type) when type in [:chrome, :chromium, :firefox], do: type
  defp normalize_browser_type(type) when is_binary(type) do
    case String.downcase(type) do
      "chrome" -> :chrome
      "chromium" -> :chromium
      "firefox" -> :firefox
      _ -> nil
    end
  end
  defp normalize_browser_type(_), do: nil

  defp build_context(state) do
    metadata = state.metadata || %{}

    %{
      session_id: state.id,
      profile_dir: state.profile_dir,
      browser_type: state.browser_type,
      screen_width: get_in(metadata, ["screen", "width"]),
      screen_height: get_in(metadata, ["screen", "height"]),
      device_scale_factor: get_in(metadata, ["screen", "scale"]),
      screen_dpi: get_in(metadata, ["screen", "dpi"]),
      headless: metadata["headless"] == true
    }
  end

  defp build_endpoint(nil), do: nil
  defp build_endpoint(%{pod_ip: host, http_port: port, vnc_port: vnc}) do
    %{host: host, port: port, vnc_port: vnc, scheme: "http"}
  end

  defp describe(state) do
    %{
      id: state.id,
      browser_type: state.browser_type,
      profile_dir: state.profile_dir,
      metadata: state.metadata,
      owner: state.owner,
      limits: state.limits,
      ready?: state.ready?,
      node: Node.self(),
      checkpoint_at: state.last_heartbeat_at,
      started_at: state.started_at,
      endpoint: state.endpoint
    }
  end

  defp build_snapshot(state) do
    now = DateTime.utc_now()

    %{
      "id" => state.id,
      "node" => Atom.to_string(Node.self()),
      "browser_type" => state.browser_type,
      "profile_dir" => state.profile_dir,
      "profile_snapshot" => state.profile_snapshot,
      "metadata" => state.metadata,
      "owner" => state.owner,
      "limits" => state.limits,
      "ready" => state.ready?,
      "endpoint" => serialize_endpoint(state.endpoint),
      "last_seen_at" => state.last_heartbeat_at || now,
      "updated_at" => now
    }
  end

  defp serialize_endpoint(nil), do: nil
  defp serialize_endpoint(%{host: host, port: port} = endpoint) do
    base = %{"host" => host, "port" => port, "scheme" => Map.get(endpoint, :scheme, "http")}

    case Map.get(endpoint, :vnc_port) do
      nil -> base
      vnc -> Map.put(base, "vnc_port", vnc)
    end
  end

  defp schedule_checkpoint(state) do
    interval = SessionRuntime.checkpoint_interval_ms()

    if state.checkpoint_ref, do: Process.cancel_timer(state.checkpoint_ref)

    ref = Process.send_after(self(), :checkpoint, interval)
    %{state | checkpoint_ref: ref, last_heartbeat_at: DateTime.utc_now()}
  end
end
