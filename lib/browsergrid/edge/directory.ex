defmodule Browsergrid.Edge.Directory do
  @moduledoc """
  Edge Directory Agent: subscribes to Redis for route upserts/deletes and
  maintains an ETS map for O(1) lookups by `session_id`.

  Intended to run on gateway hosts. Provides a simple synchronous API
  (`lookup/1`) and can be combined with a local socket server for HAProxy/NGINX.
  """
  use GenServer
  require Logger

  @table :edge_routes

  def start_link(_opts), do: GenServer.start_link(__MODULE__, [], name: __MODULE__)

  @doc """
  Lookup a route from the in-memory table.
  Returns `{ip, port}` or `nil`.
  """
  @spec lookup(String.t()) :: {String.t(), non_neg_integer()} | nil
  def lookup(session_id) do
    case :ets.lookup(@table, session_id) do
      [{^session_id, ip, port}] -> {ip, port}
      _ -> nil
    end
  catch
    :error, :badarg -> nil
  end

  @doc """
  Cold-start sync from the authoritative Postgres routes table.
  """
  def sync_from_db(batch_size \\ 10_000) do
    _ = ensure_table()
    do_sync(0, batch_size)
  end

  defp do_sync(offset, limit) do
    routes = Browsergrid.Routing.list_routes(limit, offset)
    Enum.each(routes, fn r -> :ets.insert(@table, {r.id, r.ip, r.port}) end)
    if length(routes) == limit, do: do_sync(offset + limit, limit), else: :ok
  end

  @impl true
  def init(_opts) do
    ensure_table()
    # Subscribe to Redis
    redis_cfg = Application.get_env(:browsergrid, :redis, [])
    url = Keyword.get(redis_cfg, :url, "redis://localhost:6379")
    {:ok, pubsub} = Redix.PubSub.start_link(url)
    channel = Keyword.get(redis_cfg, :route_channel, "route-updates")
    {:ok, _ref} = Redix.PubSub.subscribe(pubsub, channel, self())
    {:ok, %{pubsub: pubsub, channel: channel}}
  end

  @impl true
  def handle_info({:redix_pubsub, _pubsub, _ref, :message, %{channel: _ch, payload: payload}}, state) do
    with {:ok, %{"type" => type} = msg} <- Jason.decode(payload) do
      handle_route_event(type, msg)
    end
    {:noreply, state}
  end

  def handle_info({:redix_pubsub, _pubsub, _ref, :subscribed, %{channel: _ch}}, state), do: {:noreply, state}

  def handle_info({:redix_pubsub, _pubsub, _ref, _type, _data}, state), do: {:noreply, state}

  defp handle_route_event("upsert", %{"session_id" => id, "ip" => ip, "port" => port}) do
    :ets.insert(@table, {id, ip, port})
  end

  defp handle_route_event("delete", %{"session_id" => id}) do
    :ets.delete(@table, id)
  end

  defp handle_route_event(_unknown, _msg), do: :ok

  defp ensure_table do
    case :ets.info(@table) do
      :undefined -> :ets.new(@table, [:named_table, :public, read_concurrency: true])
      _ -> @table
    end
  end
end
