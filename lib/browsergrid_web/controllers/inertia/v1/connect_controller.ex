defmodule BrowsergridWeb.Inertia.V1.ConnectController do
  use BrowsergridWeb, :controller

  alias Browsergrid.Connect

  def pool(conn, _params) do
    pool_snapshot = Connect.snapshot()

    render_inertia(conn, "Connect/Pool", %{
      pool: pool_snapshot
    })
  end
end
