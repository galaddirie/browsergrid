defmodule BrowsergridWeb.API.V1.EdgeDebugController do
  use BrowsergridWeb, :controller

  alias Browsergrid.Edge.Directory

  def index(conn, _params) do
    # Get all routes from Edge Directory ETS table
    routes =
      try do
        :edge_routes
        |> :ets.tab2list()
        |> Enum.map(fn {session_id, ip, port} ->
          %{
            session_id: session_id,
            ip: ip,
            port: port,
            url: "http://#{ip}:#{port}"
          }
        end)
      rescue
        _ -> []
      end

    # Get process info
    edge_pid = Process.whereis(Directory)

    # Get Redis connection status
    redis_status =
      try do
        case Browsergrid.Redis.publish("test-channel", "ping") do
          {:ok, _} -> "connected"
          _ -> "error"
        end
      rescue
        _ -> "failed"
      end

    data = %{
      edge_directory_running: edge_pid != nil,
      edge_directory_pid: if(edge_pid, do: inspect(edge_pid)),
      redis_status: redis_status,
      total_routes: length(routes),
      routes: routes,
      timestamp: DateTime.utc_now()
    }

    render(conn, :index, data: data)
  end

  def lookup(conn, %{"session_id" => session_id}) do
    case Directory.lookup(session_id) do
      {ip, port} ->
        data = %{
          session_id: session_id,
          found: true,
          ip: ip,
          port: port,
          url: "http://#{ip}:#{port}"
        }

        render(conn, :lookup, data: data)

      nil ->
        data = %{
          session_id: session_id,
          found: false
        }

        render(conn, :lookup, data: data)
    end
  end

  # Trigger a sync from database to ETS
  def sync_test(conn, _params) do
    Directory.sync_from_db()
    render(conn, :sync, data: %{status: "completed"})
  rescue
    e ->
      render(conn, :sync, data: %{status: "failed", error: inspect(e)})
  end
end
