defmodule Browsergrid.Redis do
  @moduledoc """
  Minimal Redis wrapper used for publishing route updates.

  Starts a single shared `Redix` connection named `Browsergrid.Redis.Conn`.
  """

  use Supervisor

  require Logger

  @conn_name __MODULE__.Conn

  def start_link(_opts) do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    redis_cfg = Application.get_env(:browsergrid, :redis, [])
    url = Keyword.get(redis_cfg, :url, "redis://localhost:6379")

    children = [
      {Redix, {url, [name: @conn_name]}}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def publish(channel, payload) when is_binary(channel) and is_binary(payload) do
    Redix.command(@conn_name, ["PUBLISH", channel, payload])
  end

  def publish_route_upsert(session_id, ip, port) do
    %{
      type: "upsert",
      session_id: session_id,
      ip: ip,
      port: port,
      ts_ms: System.system_time(:millisecond)
    }
    |> Jason.encode!()
    |> publish_to_route_channel()
  end

  def publish_route_delete(session_id) do
    %{
      type: "delete",
      session_id: session_id,
      ts_ms: System.system_time(:millisecond)
    }
    |> Jason.encode!()
    |> publish_to_route_channel()
  end

  defp publish_to_route_channel(message) do
    redis_cfg = Application.get_env(:browsergrid, :redis, [])
    channel = Keyword.get(redis_cfg, :route_channel, "route-updates")
    publish(channel, message)
  end
end
