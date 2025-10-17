defmodule BrowsergridWeb.Plugs.APIKeyAuthTest do
  use BrowsergridWeb.ConnCase, async: true

  alias Browsergrid.ApiKeys
  alias Browsergrid.ApiKeys.RateLimiter
  alias BrowsergridWeb.Plugs.APIKeyAuth

  setup do
    {:ok, %{api_key: api_key, token: token}} = ApiKeys.create_api_key(%{name: "Plug Test"})

    on_exit(fn -> RateLimiter.reset(api_key.id) end)

    %{api_key: api_key, token: token}
  end

  test "assigns api key with bearer header", %{conn: conn, token: token, api_key: api_key} do
    opts = APIKeyAuth.init([])

    conn =
      conn
      |> Plug.Conn.put_req_header("authorization", "Bearer #{token}")
      |> APIKeyAuth.call(opts)

    refute conn.halted
    assert conn.assigns.api_key.id == api_key.id
    assert conn.assigns.token.id == api_key.id
  end

  test "assigns api key with query parameter", %{token: token, api_key: api_key} do
    opts = APIKeyAuth.init([])

    conn =
      :get
      |> build_conn("/?token=#{token}")
      |> APIKeyAuth.call(opts)

    refute conn.halted
    assert conn.assigns.api_key.id == api_key.id
  end

  test "returns 401 when token missing", %{conn: conn} do
    conn = APIKeyAuth.call(conn, APIKeyAuth.init([]))

    assert conn.halted
    assert conn.status == 401
    assert %{"error" => "invalid_token"} = Jason.decode!(conn.resp_body)
  end

  test "enforces rate limit", %{conn: conn, token: token, api_key: api_key} do
    opts = APIKeyAuth.init(rate_options: [limit: 1, interval_ms: 60_000])

    success_conn =
      conn
      |> Plug.Conn.put_req_header("authorization", "Bearer #{token}")
      |> APIKeyAuth.call(opts)

    refute success_conn.halted

    limited_conn =
      build_conn()
      |> Plug.Conn.put_req_header("authorization", "Bearer #{token}")
      |> APIKeyAuth.call(opts)

    assert limited_conn.halted
    assert limited_conn.status == 429
    assert %{"error" => "rate_limited"} = Jason.decode!(limited_conn.resp_body)
    assert Plug.Conn.get_resp_header(limited_conn, "retry-after") != []
  end
end
