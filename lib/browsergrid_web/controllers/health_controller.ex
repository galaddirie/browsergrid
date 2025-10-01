defmodule BrowsergridWeb.HealthController do
  use BrowsergridWeb, :controller

  def health(conn, _params) do
    cluster_status = %{
      status: "healthy",
      node: node(),
      connected_nodes: Node.list(),
      cluster_size: length([node() | Node.list()]),
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      version: Application.spec(:browsergrid, :vsn) || "1.0.0"
    }

    json(conn, cluster_status)
  end

  def healthz(conn, _params) do
    text(conn, "OK")
  end
end
