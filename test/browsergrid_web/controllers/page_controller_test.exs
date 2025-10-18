defmodule BrowsergridWeb.PageControllerTest do
  use BrowsergridWeb.ConnCase

  import Browsergrid.AccountsFixtures

  test "GET / redirects to login when not authenticated", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert redirected_to(conn) == ~p"/users/log_in"
  end

  test "GET / renders dashboard when authenticated", %{conn: conn} do
    user = user_fixture()
    conn = log_in_user(conn, user)
    conn = get(conn, ~p"/")
    assert html_response(conn, 200)
  end
end
