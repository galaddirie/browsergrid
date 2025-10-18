defmodule BrowsergridWeb.Plugs.ApiAuthTest do
  use BrowsergridWeb.ConnCase, async: true

  alias Browsergrid.AccountsFixtures
  alias Browsergrid.ApiTokens
  alias Browsergrid.ApiTokens.ApiToken

  describe "call/2" do
    test "assigns the user and token when the bearer token is valid", %{conn: conn} do
      user = AccountsFixtures.user_fixture()
      {:ok, api_token, plaintext} = ApiTokens.create_token(user, %{"name" => "API"})

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{plaintext}")
        |> BrowsergridWeb.Plugs.ApiAuth.call(%{})

      assert conn.assigns.current_user.id == user.id
      assert %ApiToken{id: token_id} = conn.assigns.api_token
      assert token_id == api_token.id
      refute conn.halted
    end

    test "returns 401 when authorization header is missing", %{conn: conn} do
      conn = BrowsergridWeb.Plugs.ApiAuth.call(conn, %{})

      assert conn.halted
      assert conn.status == 401
      assert %{"error" => "unauthorized"} = Jason.decode!(conn.resp_body)
    end

    test "returns 401 when token is invalid", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer invalid")
        |> BrowsergridWeb.Plugs.ApiAuth.call(%{})

      assert conn.halted
      assert conn.status == 401
      assert %{"reason" => "invalid"} = Jason.decode!(conn.resp_body)
    end
  end
end
