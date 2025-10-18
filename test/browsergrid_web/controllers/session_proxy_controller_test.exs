defmodule BrowsergridWeb.SessionProxyControllerTest do
  use BrowsergridWeb.ConnCase, async: true

  alias BrowsergridWeb.SessionProxyController

  test "websocket upgrade requests are rejected with gone status" do
    session_id = "test-session"

    conn =
      :get
      |> build_conn("/sessions/#{session_id}/edge/json")
      |> put_req_header("connection", "upgrade")
      |> put_req_header("upgrade", "websocket")

    conn = SessionProxyController.proxy(conn, %{"id" => session_id, "path" => ["json"]})

    assert conn.status == 410
    assert response(conn, 410) =~ "websocket upgrade no longer supported"
  end
end
