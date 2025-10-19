defmodule BrowsergridWeb.Plugs.ApiAuthTest do
  use BrowsergridWeb.ConnCase, async: true

  alias Browsergrid.AccountsFixtures
  alias Browsergrid.ApiTokens
  alias Browsergrid.ApiTokens.ApiToken
  alias BrowsergridWeb.Plugs.ApiAuth

  describe "call/2" do
    test "assigns the user and token when the bearer token is valid", %{conn: conn} do
      user = AccountsFixtures.user_fixture()
      {:ok, api_token, plaintext} = ApiTokens.create_token(user, %{"name" => "API"})

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{plaintext}")
        |> ApiAuth.call(%{})

      assert conn.assigns.current_user.id == user.id
      assert %ApiToken{id: token_id} = conn.assigns.api_token
      assert token_id == api_token.id
      refute conn.halted
    end

    test "assigns the user and token when the token query param is present", %{conn: conn} do
      user = AccountsFixtures.user_fixture()
      {:ok, api_token, plaintext} = ApiTokens.create_token(user, %{"name" => "API"})

      conn =
        conn
        |> Map.put(:query_string, "token=#{plaintext}")
        |> Plug.Conn.fetch_query_params()
        |> ApiAuth.call(%{})

      assert conn.assigns.current_user.id == user.id
      assert %ApiToken{id: token_id} = conn.assigns.api_token
      assert token_id == api_token.id
      refute conn.halted
    end

    test "returns 401 when authorization header is missing", %{conn: conn} do
      conn = ApiAuth.call(conn, %{})

      assert conn.halted
      assert conn.status == 401
      assert %{"error" => "unauthorized"} = Jason.decode!(conn.resp_body)
    end

    test "returns 401 when token is invalid", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer invalid")
        |> ApiAuth.call(%{})

      assert conn.halted
      assert conn.status == 401
      assert %{"reason" => "invalid"} = Jason.decode!(conn.resp_body)
    end
  end
end
