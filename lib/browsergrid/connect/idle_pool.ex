defmodule Browsergrid.Connect.IdlePool do
  @moduledoc """
  Maintains a pool of pre-warmed browser sessions that can be claimed and bound
  to Connect clients for low-latency session acquisition.

  The pool eagerly provisions sessions up to the configured `:pool_size`. When a
  client claims a session, the pool removes it from the idle queue, tracks the
  claim, and starts a countdown for the client to establish the WebSocket
  connection. If the client fails to connect within the configured timeout or
  disconnects, the session is cleaned up and a new idle session is provisioned.
  """
  use GenServer

  alias Browsergrid.Connect.Config
  alias Browsergrid.Connect.SessionInfo
  alias Browsergrid.SessionRuntime

  require Logger

  @typedoc "Opaque identifier used by callers to claim a session."
  @type token :: String.t()

  @typedoc "Return value describing a claimed session."
  @type claim_response :: {:ok, SessionInfo.t()} | {:error, term()}

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @spec claim(token(), keyword()) :: claim_response()
  def claim(token, opts \\ []) do
    GenServer.call(server_name(opts), {:claim, token, opts})
  end

  @spec get_claim(token(), keyword()) :: {:ok, SessionInfo.t()} | {:error, term()}
  def get_claim(token, opts \\ []) do
    GenServer.call(server_name(opts), {:get_claim, token})
  end

  @spec attach_websocket(token(), pid(), keyword()) ::
          {:ok, SessionInfo.t()} | {:error, term()}
  def attach_websocket(token, ws_pid, opts \\ []) do
    GenServer.call(server_name(opts), {:attach_ws, token, ws_pid})
  end

  @spec release(token(), term(), keyword()) :: :ok
  def release(token, reason, opts \\ []) do
    GenServer.cast(server_name(opts), {:release, token, reason})
  end

  @spec snapshot(keyword()) :: {:ok, map()} | {:error, term()}
  def snapshot(opts \\ []) do
    server = server_name(opts)

    case Process.whereis(server) do
      nil -> {:error, :not_running}
      _pid -> GenServer.call(server, :snapshot)
    end
  end

  @impl true
  def init(opts) do
    pool_size = Keyword.get(opts, :pool_size, Config.pool_size())
    claim_timeout_ms = Keyword.get(opts, :claim_timeout_ms, Config.claim_timeout_ms())

    state = %{
      pool_size: pool_size,
      claim_timeout_ms: claim_timeout_ms,
      session_prefix: Keyword.get(opts, :session_prefix, Config.session_prefix()),
      session_metadata: Keyword.get(opts, :session_metadata, Config.session_metadata()),
      browser_type: Keyword.get(opts, :browser_type, Config.browser_type()),
      sessions: %{},
      idle_queue: :queue.new(),
      claims: %{},
      monitors: %{},
      starting: MapSet.new()
    }

    {:ok, state, {:continue, :warm_pool}}
  end

  @impl true
  def handle_continue(:warm_pool, state) do
    {:noreply, ensure_capacity(state)}
  end

  @impl true
  def handle_call({:claim, token, _opts}, _from, state) when not is_binary(token) or token == "" do
    {:reply, {:error, :invalid_token}, state}
  end

  def handle_call({:claim, token, _opts}, _from, state) do
    case Map.get(state.claims, token) do
      nil ->
        case pop_idle_session(state) do
          {:empty, next_state} ->
            Logger.warning("connect claim requested but pool is empty", token: redact(token))
            {:reply, {:error, :empty}, ensure_capacity(next_state)}

          {:ok, session, next_state} ->
            now = DateTime.utc_now()
            timer_ref = Process.send_after(self(), {:claim_expired, token, session.id}, next_state.claim_timeout_ms)

            claimed_session = %{
              session
              | status: :claimed,
                claimed_by: token,
                claimed_at: now,
                timer_ref: timer_ref
            }

            sessions = Map.put(next_state.sessions, session.id, claimed_session)
            claims = Map.put(next_state.claims, token, session.id)

            Logger.info("connect session claimed", session_id: session.id, token: redact(token))

            updated_state =
              next_state
              |> Map.put(:sessions, sessions)
              |> Map.put(:claims, claims)
              |> ensure_capacity()

            {:reply, {:ok, claimed_session}, updated_state}
        end

      session_id ->
        case Map.get(state.sessions, session_id) do
          %SessionInfo{} = session ->
            {:reply, {:ok, session}, state}

          nil ->
            # Stale claim entry, clean it up and retry.
            cleaned_state = %{state | claims: Map.delete(state.claims, token)}
            {:reply, {:error, :stale_claim}, ensure_capacity(cleaned_state)}
        end
    end
  end

  def handle_call({:get_claim, token}, _from, state) when not is_binary(token) or token == "" do
    {:reply, {:error, :invalid_token}, state}
  end

  def handle_call({:get_claim, token}, _from, state) do
    case state.claims |> Map.get(token) |> maybe_fetch_session(state.sessions) do
      {:ok, session} -> {:reply, {:ok, session}, state}
      :error -> {:reply, {:error, :not_found}, state}
    end
  end

  def handle_call({:attach_ws, token, ws_pid}, _from, state)
      when not is_binary(token) or token == "" or not is_pid(ws_pid) do
    {:reply, {:error, :invalid_request}, state}
  end

  def handle_call({:attach_ws, token, ws_pid}, _from, state) do
    case state.claims |> Map.get(token) |> maybe_fetch_session(state.sessions) do
      {:ok, %SessionInfo{status: :connected}} ->
        {:reply, {:error, :already_connected}, state}

      {:ok, %SessionInfo{} = session} ->
        if session.timer_ref, do: Process.cancel_timer(session.timer_ref)
        monitor = Process.monitor(ws_pid)

        connected_session = %{
          session
          | status: :connected,
            ws_pid: ws_pid,
            ws_monitor: monitor,
            timer_ref: nil
        }

        sessions = Map.put(state.sessions, session.id, connected_session)
        monitors = Map.put(state.monitors, monitor, token)

        Logger.info("connect websocket attached", session_id: session.id, token: redact(token))

        {:reply, {:ok, connected_session}, %{state | sessions: sessions, monitors: monitors}}

      :error ->
        {:reply, {:error, :not_found}, state}
    end
  end

  def handle_call(:snapshot, _from, state) do
    {:reply, {:ok, build_snapshot(state)}, state}
  end

  @impl true
  def handle_cast({:release, token, reason}, state) do
    {:noreply, release_claim(state, token, reason)}
  end

  @impl true
  def handle_info({:session_ready, session_id, endpoint}, state) do
    starting = MapSet.delete(state.starting, session_id)

    session = %SessionInfo{
      id: session_id,
      status: :idle,
      endpoint: normalize_endpoint(endpoint),
      metadata: state.session_metadata,
      inserted_at: DateTime.utc_now()
    }

    sessions = Map.put(state.sessions, session_id, session)
    idle_queue = :queue.in(session_id, state.idle_queue)

    Logger.info("connect session ready", session_id: session_id, endpoint: endpoint)

    state =
      state
      |> Map.put(:starting, starting)
      |> Map.put(:sessions, sessions)
      |> Map.put(:idle_queue, idle_queue)

    {:noreply, ensure_capacity(state)}
  end

  def handle_info({:session_failed, session_id, reason}, state) do
    Logger.error("connect session failed to start", session_id: session_id, reason: inspect(reason))

    state = Map.update!(state, :starting, &MapSet.delete(&1, session_id))

    {:noreply, ensure_capacity(state)}
  end

  def handle_info({:claim_expired, token, session_id}, state) do
    case Map.get(state.claims, token) do
      ^session_id ->
        Logger.info("connect claim timed out waiting for websocket", session_id: session_id, token: redact(token))
        {:noreply, release_claim(state, token, :claim_timeout)}

      _ ->
        {:noreply, state}
    end
  end

  def handle_info({:DOWN, monitor, :process, _pid, reason}, state) do
    case Map.get(state.monitors, monitor) do
      nil ->
        {:noreply, state}

      token ->
        Logger.info("connect websocket disconnected", token: redact(token), reason: inspect(reason))
        {:noreply, release_claim(state, token, {:ws_down, reason})}
    end
  end

  def handle_info(_message, state), do: {:noreply, state}

  defp release_claim(state, token, reason) do
    case Map.pop(state.claims, token) do
      {nil, _claims} ->
        state

      {session_id, claims} ->
        {session, sessions} = Map.pop(state.sessions, session_id)

        state =
          state
          |> maybe_cancel_timer(session)
          |> maybe_demonitor(session)

        if session do
          stop_session(session)
        end

        state =
          state
          |> Map.put(:claims, claims)
          |> Map.put(:sessions, sessions)
          |> Map.put(:idle_queue, state.idle_queue)
          |> ensure_capacity()

        Logger.info("connect claim released", session_id: session_id, token: redact(token), reason: inspect(reason))

        state
    end
  end

  defp maybe_cancel_timer(state, %SessionInfo{timer_ref: nil}), do: state

  defp maybe_cancel_timer(state, %SessionInfo{timer_ref: ref}) when is_reference(ref) do
    Process.cancel_timer(ref)
    state
  end

  defp maybe_cancel_timer(state, _), do: state

  defp maybe_demonitor(state, %SessionInfo{ws_monitor: nil}), do: state

  defp maybe_demonitor(state, %SessionInfo{ws_monitor: monitor}) when is_reference(monitor) do
    Process.demonitor(monitor, [:flush])
    monitors = Map.delete(state.monitors, monitor)
    %{state | monitors: monitors}
  end

  defp maybe_demonitor(state, _), do: state

  defp stop_session(nil), do: :ok

  defp stop_session(%SessionInfo{id: session_id}) do
    Logger.debug("stopping connect session", session_id: session_id)
    :ok = SessionRuntime.stop_session(session_id)
    :ok = SessionRuntime.delete_snapshot(session_id)
    :ok
  end

  defp ensure_capacity(%{pool_size: pool_size} = state) when pool_size <= 0 do
    state
  end

  defp ensure_capacity(state) do
    current_available = idle_count(state) + MapSet.size(state.starting)
    deficit = max(state.pool_size - current_available, 0)

    if deficit > 0 do
      Enum.reduce(1..deficit, state, fn _, acc -> launch_idle_session(acc) end)
    else
      state
    end
  end

  defp idle_count(state) do
    :queue.len(state.idle_queue)
  end

  defp launch_idle_session(state) do
    session_id = generate_session_id(state.session_prefix)
    parent = self()
    metadata = Map.merge(%{"pool" => "connect"}, state.session_metadata)
    browser_type = state.browser_type
    opts = [metadata: metadata, owner: %{"source" => "connect"}, limits: %{}, browser: [type: browser_type]]

    Logger.info("provisioning connect session", session_id: session_id, browser_type: browser_type)

    _task =
      Task.start(fn ->
        case SessionRuntime.ensure_session_started(session_id, opts) do
          {:ok, _pid} ->
            case SessionRuntime.upstream_endpoint(session_id) do
              {:ok, endpoint} ->
                send(parent, {:session_ready, session_id, endpoint})

              {:error, reason} ->
                SessionRuntime.stop_session(session_id)
                SessionRuntime.delete_snapshot(session_id)
                send(parent, {:session_failed, session_id, reason})
            end

          {:error, reason} ->
            send(parent, {:session_failed, session_id, reason})
        end
      end)

    starting = MapSet.put(state.starting, session_id)
    Map.put(state, :starting, starting)
  end

  defp pop_idle_session(state) do
    case :queue.out(state.idle_queue) do
      {:empty, queue} ->
        {:empty, %{state | idle_queue: queue}}

      {{:value, session_id}, queue} ->
        case Map.get(state.sessions, session_id) do
          %SessionInfo{status: :idle} = session ->
            {:ok, session, %{state | idle_queue: queue}}

          _other ->
            pop_idle_session(%{state | idle_queue: queue})
        end
    end
  end

  defp maybe_fetch_session(nil, _sessions), do: :error

  defp maybe_fetch_session(session_id, sessions) do
    case Map.get(sessions, session_id) do
      %SessionInfo{} = session -> {:ok, session}
      _ -> :error
    end
  end

  defp normalize_endpoint(endpoint) when is_map(endpoint) do
    Map.put_new(endpoint, :scheme, Map.get(endpoint, :scheme, "http"))
  end

  defp normalize_endpoint(endpoint), do: endpoint

  defp generate_session_id(prefix) do
    uuid = Ecto.UUID.generate()
    "#{prefix}-#{uuid}"
  end

  defp redact(token) when is_binary(token) do
    case byte_size(token) do
      0 ->
        token

      size when size <= 4 ->
        String.duplicate("*", size)

      size ->
        tail = String.slice(token, size - 4, 4)
        "****#{tail}"
    end
  end

  defp redact(other), do: inspect(other)

  defp server_name(opts) do
    Keyword.get(opts, :server, __MODULE__)
  end

  defp build_snapshot(state) do
    idle_queue = :queue.to_list(state.idle_queue)

    session_maps =
      Enum.map(state.sessions, fn {id, session} ->
        session
        |> session_to_map(state.claim_timeout_ms)
        |> Map.put(:in_idle_queue, Enum.member?(idle_queue, id))
      end)

    starting_sessions =
      state.starting
      |> Enum.reject(&Map.has_key?(state.sessions, &1))
      |> Enum.map(fn id ->
        %{
          id: id,
          status: "starting",
          inserted_at: nil,
          claimed_by: nil,
          claimed_by_label: nil,
          claimed_at: nil,
          claim_expires_at: nil,
          endpoint: nil,
          metadata: %{},
          ws_attached: false,
          connected: false,
          in_idle_queue: false
        }
      end)

    sessions = Enum.sort_by(session_maps ++ starting_sessions, &session_sort_key/1)

    counts =
      sessions
      |> Enum.map(& &1.status)
      |> Enum.frequencies()

    claims =
      Enum.map(state.claims, fn {token, session_id} ->
        %{
          token: token,
          token_tail: token_tail(token),
          session_id: session_id
        }
      end)

    %{
      online: true,
      pool_size: state.pool_size,
      claim_timeout_ms: state.claim_timeout_ms,
      session_prefix: state.session_prefix,
      browser_type: Atom.to_string(state.browser_type),
      sessions: sessions,
      counts: counts,
      idle_queue: idle_queue,
      claims: claims,
      fetched_at: DateTime.to_iso8601(DateTime.utc_now())
    }
  end

  defp session_to_map(%SessionInfo{} = session, claim_timeout_ms) do
    claim_deadline =
      case {session.claimed_at, claim_timeout_ms} do
        {%DateTime{} = claimed_at, timeout} when is_integer(timeout) ->
          DateTime.add(claimed_at, timeout, :millisecond)

        _ ->
          nil
      end

    %{
      id: session.id,
      status: Atom.to_string(session.status),
      inserted_at: maybe_iso(session.inserted_at),
      claimed_by: session.claimed_by,
      claimed_by_label: maybe_token_tail(session.claimed_by),
      claimed_at: maybe_iso(session.claimed_at),
      claim_expires_at: maybe_iso(claim_deadline),
      endpoint: maybe_endpoint(session.endpoint),
      metadata: session.metadata,
      ws_attached: is_pid(session.ws_pid),
      connected: session.status == :connected
    }
  end

  defp session_sort_key(%{inserted_at: nil}), do: {1, nil}
  defp session_sort_key(%{inserted_at: inserted_at}), do: {0, inserted_at}

  defp maybe_iso(nil), do: nil
  defp maybe_iso(%DateTime{} = dt), do: DateTime.to_iso8601(dt)

  defp maybe_endpoint(nil), do: nil

  defp maybe_endpoint(endpoint) when is_map(endpoint) do
    Map.new(endpoint, fn {k, v} -> {to_string(k), v} end)
  end

  defp maybe_token_tail(nil), do: nil
  defp maybe_token_tail(token), do: token_tail(token)

  defp token_tail(token) when is_binary(token) do
    size = byte_size(token)

    if size <= 4 do
      token
    else
      "…" <> String.slice(token, -4, 4)
    end
  end

  defp token_tail(_token), do: nil
end
