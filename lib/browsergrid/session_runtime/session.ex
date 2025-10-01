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

  @type option ::
          {:session_id, String.t()}
          | {:metadata, map()}
          | {:owner, map()}
          | {:limits, map()}
          | {:browser, keyword()}

  defmodule State do
    @moduledoc false
    @enforce_keys [:id, :profile_dir]
    defstruct id: nil,
              profile_dir: nil,
              browser: nil,
              browser_type: :chrome,
              metadata: %{},
              owner: nil,
              limits: %{},
              profile_snapshot: nil,
              ready?: false,
              checkpoint_ref: nil,
              last_heartbeat_at: nil,
              started_at: nil,
              endpoint: nil,
              restart_attempts: 0,
              last_error: nil
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

    with {:ok, profile_dir} <- ensure_profile_dir(session_id, snapshot) do
      snapshot_metadata = snapshot["metadata"] || %{}
      merged_metadata = Map.merge(snapshot_metadata, metadata)
     merged_limits = Map.merge(snapshot["limits"] || %{}, limits)
     owner = owner || snapshot["owner"]

      browser_opts = Keyword.get(opts, :browser, [])
      browser_type = determine_browser_type(opts, snapshot, merged_metadata)
      merged_metadata = Map.put(merged_metadata, "browser_type", browser_type)
      browser_opts = Keyword.put(browser_opts, :type, browser_type)

      browser_config =
        SessionRuntime.browser_config()
        |> Keyword.merge(browser_opts)
        |> Keyword.put(:type, browser_type)

      context = build_process_context(session_id, profile_dir, browser_type, merged_metadata)

      case start_browser(session_id, profile_dir, browser_opts, browser_config, context, browser_type) do
        {:ok, browser} ->
          endpoint = browser_endpoint(browser)

          state = %State{
            id: session_id,
            profile_dir: profile_dir,
            browser: browser,
            browser_type: browser_type,
            metadata: merged_metadata,
            owner: owner,
            limits: merged_limits,
            profile_snapshot: snapshot["profile_snapshot"],
            ready?: true,
            last_heartbeat_at: snapshot["last_seen_at"],
            started_at: DateTime.utc_now(),
            endpoint: endpoint
          }

          :ok = StateStore.put(session_id, build_snapshot(state))
          {:ok, schedule_checkpoint(state)}

        {:error, reason} ->
          Logger.error("session init failed: #{inspect(reason)}")
          {:stop, reason}
      end
    else
      {:error, reason} ->
        Logger.error("session init failed to prepare profile dir: #{inspect(reason)}")
        {:stop, {:profile_dir_failed, reason}}
    end
  end

  @impl true
  def handle_call(:describe, _from, state) do
    description = %{
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

    {:reply, {:ok, description}, state}
  end

  def handle_call(:endpoint, _from, %{endpoint: nil} = state) do
    {:reply, {:error, :not_ready}, state}
  end

  def handle_call(:endpoint, _from, state) do
    {:reply, {:ok, state.endpoint}, state}
  end

  @impl true
  def handle_cast({:update_metadata, fun}, state) when is_function(fun, 1) do
    new_metadata = fun.(state.metadata)
    {:noreply, %{state | metadata: new_metadata}}
  end

  def handle_cast(:heartbeat, state) do
    now = DateTime.utc_now()
    snapshot = build_snapshot(%{state | last_heartbeat_at: now})
    :ok = StateStore.put(state.id, snapshot)
    {:noreply, %{state | last_heartbeat_at: now}}
  end

  @impl true
  def handle_info(:checkpoint, state) do
    :ok = StateStore.put(state.id, build_snapshot(state))
    {:noreply, schedule_checkpoint(state)}
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

    maybe_stop_browser(state.browser)

    final_snapshot = build_snapshot(state)
    StateStore.put(state.id, final_snapshot)

    :ok
  end

  defp start_browser(session_id, profile_dir, browser_opts, browser_config, context, browser_type) do
    case Browser.start(session_id, nil, profile_dir, browser_opts, context, browser_type) do
      {:ok, browser} ->
        case Browser.wait_until_ready(browser, browser_config) do
          {:ok, ready_browser} -> {:ok, ready_browser}
          {:error, reason} ->
            Browser.stop(browser)
            {:error, {:browser_not_ready, reason}}
        end

      {:error, reason} ->
        {:error, {:browser_start_failed, reason}}
    end
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

  defp determine_browser_type(opts, snapshot, metadata) do
    user_pref = opts[:browser] |> Keyword.get(:type)
    snapshot_pref = normalize_browser_type(snapshot["browser_type"])
    metadata_pref = normalize_browser_type(Map.get(metadata, "browser_type"))

    user_pref
    |> normalize_browser_type()
    |> fallback(snapshot_pref)
    |> fallback(metadata_pref)
    |> fallback(:chrome)
  end

  defp normalize_browser_type(value) do
    case value do
      type when type in [:chrome, :chromium, :firefox] -> type
      type when is_binary(type) ->
        case String.downcase(type) do
          "chrome" -> :chrome
          "chromium" -> :chromium
          "firefox" -> :firefox
          _ -> nil
        end

      _ -> nil
    end
  end

  defp fallback(nil, next), do: next
  defp fallback(value, _next), do: value

  defp build_process_context(session_id, profile_dir, browser_type, metadata) do
    metadata = metadata || %{}
    options = Map.get(metadata, "options", %{}) || %{}
    screen_options = Map.get(options, "screen", %{}) || %{}

    screen_width =
      fetch_numeric_option(options, "screen_width") || fetch_numeric_option(screen_options, "width")

    screen_height =
      fetch_numeric_option(options, "screen_height") || fetch_numeric_option(screen_options, "height")

    scale =
      fetch_numeric_option(options, "screen_scale") ||
        fetch_numeric_option(screen_options, "scale") ||
        fetch_numeric_option(options, "device_scale_factor")

    dpi =
      fetch_numeric_option(options, "screen_dpi") || fetch_numeric_option(screen_options, "dpi")

    %{
      session_id: session_id,
      profile_dir: profile_dir,
      browser_type: browser_type,
      screen_width: screen_width,
      screen_height: screen_height,
      device_scale_factor: scale,
      screen_dpi: dpi,
      headless: truthy?(Map.get(options, "headless"))
    }
  end

  defp fetch_numeric_option(map, key) do
    case Map.get(map, key) do
      nil -> nil
      value when is_number(value) -> value
      value when is_binary(value) ->
        case Integer.parse(value) do
          {int, ""} -> int
          _ ->
            case Float.parse(value) do
              {float, ""} -> float
              _ -> nil
            end
        end

      _other -> nil
    end
  end

  defp truthy?(value), do: value in [true, "true", 1, "1"]

  defp schedule_checkpoint(%State{} = state) do
    interval = SessionRuntime.checkpoint_interval_ms()

    if state.checkpoint_ref do
      Process.cancel_timer(state.checkpoint_ref)
    end

    ref = Process.send_after(self(), :checkpoint, interval)
    %{state | checkpoint_ref: ref, last_heartbeat_at: DateTime.utc_now()}
  end

  defp browser_endpoint(nil), do: nil

  defp browser_endpoint(%{pod_ip: host, http_port: port, vnc_port: vnc}) do
    %{host: host, port: port, vnc_port: vnc, scheme: "http"}
  end

  defp endpoint_snapshot(nil), do: nil

  defp endpoint_snapshot(%{host: host, port: port} = endpoint) do
    base = %{"host" => host, "port" => port, "scheme" => Map.get(endpoint, :scheme, "http")}

    case Map.get(endpoint, :vnc_port) do
      nil -> base
      vnc -> Map.put(base, "vnc_port", vnc)
    end
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
      "endpoint" => endpoint_snapshot(state.endpoint),
      "last_seen_at" => state.last_heartbeat_at || now,
      "updated_at" => now
    }
  end

  defp maybe_stop_browser(nil), do: :ok
  defp maybe_stop_browser(browser), do: Browser.stop(browser)
end
