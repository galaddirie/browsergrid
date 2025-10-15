defmodule Browsergrid.SessionRuntime.StateStore.DeltaCrdt do
  @moduledoc """
  Delta-CRDT backed session snapshot store.

  Stores snapshots as `{data: map(), updated_at: millisecond(), expires_at: millisecond()}`
  entries. Expired entries are periodically cleaned up.
  """
  @behaviour Browsergrid.SessionRuntime.StateStore

  use GenServer

  require Logger

  @crdt_name __MODULE__.CRDT
  @ttl_key {__MODULE__, :ttl}
  @crdt_key {__MODULE__, :crdt}

  @impl true
  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 10_000
    }
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    sync_interval = Keyword.get(opts, :sync_interval_ms, 3_000)
    ttl_ms = Keyword.get(opts, :ttl_ms, to_timeout(minute: 30))
    name = Keyword.get(opts, :name, @crdt_name)

    {:ok, crdt_pid} = DeltaCrdt.start_link(DeltaCrdt.AWLWWMap, sync_interval: sync_interval, name: name)

    :persistent_term.put(@crdt_key, crdt_pid)
    :persistent_term.put(@ttl_key, ttl_ms)

    schedule_cleanup(ttl_ms)

    {:ok,
     %{
       ttl_ms: ttl_ms,
       sync_interval: sync_interval,
       crdt_pid: crdt_pid
     }}
  end

  @impl true
  def terminate(_reason, state) do
    :persistent_term.erase(@crdt_key)
    :persistent_term.erase(@ttl_key)
    maybe_shutdown(state.crdt_pid)
    :ok
  end

  @impl true
  def handle_info(:cleanup, %{ttl_ms: ttl_ms, crdt_pid: crdt_pid} = state) do
    now = System.system_time(:millisecond)

    crdt_pid
    |> DeltaCrdt.to_map()
    |> Enum.filter(fn {_session_id, entry} ->
      case entry do
        %{expires_at: expires_at} -> expires_at <= now
        _ -> false
      end
    end)
    |> Enum.each(fn {session_id, _} ->
      DeltaCrdt.delete(crdt_pid, session_id, :infinity)
    end)

    schedule_cleanup(ttl_ms)
    {:noreply, state}
  end

  defp schedule_cleanup(ttl_ms) do
    Process.send_after(self(), :cleanup, ttl_ms)
  end

  @impl true
  def put(session_id, snapshot) when is_binary(session_id) and is_map(snapshot) do
    with {:ok, crdt} <- crdt_pid() do
      now = System.system_time(:millisecond)
      ttl = ttl_ms()
      entry = %{data: snapshot, updated_at: now, expires_at: now + ttl}
      DeltaCrdt.put(crdt, session_id, entry, :infinity)
      :ok
    end
  end

  @impl true
  def get(session_id) when is_binary(session_id) do
    with {:ok, crdt} <- crdt_pid() do
      case DeltaCrdt.get(crdt, session_id, :infinity) do
        %{data: data, expires_at: expires_at} ->
          now = System.system_time(:millisecond)

          if expires_at > now do
            {:ok, data}
          else
            DeltaCrdt.delete(crdt, session_id, :infinity)
            :error
          end

        _ ->
          :error
      end
    end
  end

  @impl true
  def delete(session_id) when is_binary(session_id) do
    with {:ok, crdt} <- crdt_pid() do
      DeltaCrdt.delete(crdt, session_id, :infinity)
    end

    :ok
  end

  @impl true
  def join_all do
    with {:ok, crdt} <- crdt_pid() do
      neighbours =
        Node.list()
        |> Enum.map(fn node ->
          case :rpc.call(node, __MODULE__, :remote_crdt_pid, []) do
            {:ok, pid} when is_pid(pid) -> pid
            _ -> nil
          end
        end)
        |> Enum.reject(&is_nil/1)

      DeltaCrdt.set_neighbours(crdt, neighbours)
    end

    :ok
  end

  def remote_crdt_pid do
    crdt_pid()
  end

  def crdt_pid do
    case :persistent_term.get(@crdt_key, nil) do
      nil -> {:error, :not_ready}
      pid when is_pid(pid) -> {:ok, pid}
    end
  end

  def ttl_ms do
    :persistent_term.get(@ttl_key, to_timeout(minute: 30))
  end

  defp maybe_shutdown(pid) when is_pid(pid) do
    ref = Process.monitor(pid)
    Process.exit(pid, :shutdown)

    receive do
      {:DOWN, ^ref, :process, ^pid, _reason} -> :ok
    after
      5_000 -> :ok
    end
  end

  defp maybe_shutdown(_), do: :ok
end
