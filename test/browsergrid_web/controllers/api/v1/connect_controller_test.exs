defmodule BrowsergridWeb.API.V1.ConnectControllerTest do
  use BrowsergridWeb.ConnCase, async: false

  import Mock

  alias Browsergrid.AccountsFixtures
  alias Browsergrid.ApiTokens
  alias Browsergrid.Sessions.Session

  setup %{conn: conn} do
    user = AccountsFixtures.user_fixture()
    {:ok, _token, plaintext} = ApiTokens.create_token(user, %{"name" => "Connect Test"})

    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> put_req_header("authorization", "Bearer #{plaintext}")

    {:ok, conn: conn, user: user}
  end

  describe "show/2" do
    test "claims from the default pool and rewrites CDP payload", %{conn: conn, user: user} do
      session = %Session{id: "session-123", status: :ready, session_pool_id: "pool-1"}

      with_mocks([
        {Browsergrid.SessionPools, [:passthrough], fetch_pool_for_claim: fn nil, ^user -> {:ok, :pool} end,
         claim_or_provision_session: fn :pool, ^user -> {:ok, session} end},
        {Browsergrid.SessionRuntime, [:passthrough],
         upstream_endpoint: fn "session-123" -> {:ok, %{host: "127.0.0.1", port: 9222, scheme: "http"}} end},
        {Finch, [:passthrough],
         request: fn %Finch.Request{path: "/json"} = request, Browsergrid.Finch, opts ->
           assert request.method == "GET"
           assert opts[:receive_timeout] == 5_000

           payload = %{
             "Browser" => "Chrome/141.0",
             "Protocol-Version" => "1.3",
             "webSocketDebuggerUrl" => "ws://127.0.0.1:9222/devtools/browser/session-123"
           }

           {:ok, %Finch.Response{status: 200, body: Jason.encode!(payload)}}
         end}
      ]) do
        response_conn = get(conn, ~p"/api/v1/connect/json")
        result = json_response(response_conn, 200)

        assert result["Browser"] == "Chrome/141.0"
        assert result["Protocol-Version"] == "1.3"

        assert result["webSocketDebuggerUrl"] ==
                 "ws://www.example.com/sessions/session-123/connect/devtools/browser/session-123"

        assert result["devtoolsFrontendUrl"] == result["webSocketDebuggerUrl"]

        assert_called(Browsergrid.SessionPools.fetch_pool_for_claim(nil, user))
        assert_called(Browsergrid.SessionPools.claim_or_provision_session(:pool, user))
      end
    end

    test "respects the pool query parameter", %{conn: conn, user: user} do
      session = %Session{id: "page-456", status: :ready, session_pool_id: "pool-2"}

      with_mocks([
        {Browsergrid.SessionPools, [:passthrough], fetch_pool_for_claim: fn "custom", ^user -> {:ok, :custom_pool} end,
         claim_or_provision_session: fn :custom_pool, ^user -> {:ok, session} end},
        {Browsergrid.SessionRuntime, [:passthrough],
         upstream_endpoint: fn "page-456" -> {:ok, %{host: "127.0.0.1", port: 9333, scheme: "http"}} end},
        {Finch, [:passthrough],
         request: fn %Finch.Request{path: "/json/list"} = request, Browsergrid.Finch, _opts ->
           assert request.method == "GET"

           payload = [
             %{
               "id" => "page-456",
               "type" => "page",
               "webSocketDebuggerUrl" => "ws://127.0.0.1:9333/devtools/page/page-456"
             }
           ]

           {:ok, %Finch.Response{status: 200, body: Jason.encode!(payload)}}
         end}
      ]) do
        response_conn = get(conn, ~p"/api/v1/connect/json/list?pool=custom")
        result = json_response(response_conn, 200)

        [%{"id" => "page-456", "webSocketDebuggerUrl" => url}] = result

        assert url ==
                 "ws://www.example.com/sessions/page-456/connect/devtools/page/page-456"

        assert_called(Browsergrid.SessionPools.fetch_pool_for_claim("custom", user))
        assert_called(Browsergrid.SessionPools.claim_or_provision_session(:custom_pool, user))
      end
    end

    test "returns conflict when no sessions are available", %{conn: conn, user: user} do
      with_mock Browsergrid.SessionPools,
        fetch_pool_for_claim: fn nil, ^user -> {:ok, :pool} end,
        claim_or_provision_session: fn :pool, ^user -> {:error, :no_available_sessions} end do
        response_conn = get(conn, ~p"/api/v1/connect/json")
        assert response_conn.status == 409
        assert %{"error" => "no_available_sessions"} = Jason.decode!(response_conn.resp_body)
      end
    end

    test "returns conflict when pool is at capacity", %{conn: conn, user: user} do
      with_mock Browsergrid.SessionPools,
        fetch_pool_for_claim: fn nil, ^user -> {:ok, :pool} end,
        claim_or_provision_session: fn :pool, ^user -> {:error, :pool_at_capacity} end do
        response_conn = get(conn, ~p"/api/v1/connect/json")
        assert response_conn.status == 409

        assert %{
                 "error" => "pool_at_capacity",
                 "message" => "Pool has reached maximum capacity. Try again later."
               } = Jason.decode!(response_conn.resp_body)
      end
    end

    test "propagates authorization errors from pool fetch", %{conn: conn, user: user} do
      with_mock Browsergrid.SessionPools,
        fetch_pool_for_claim: fn nil, ^user -> {:error, :forbidden} end do
        response_conn = get(conn, ~p"/api/v1/connect/json")
        assert response_conn.status == 403
        assert %{"error" => "forbidden"} = Jason.decode!(response_conn.resp_body)
      end
    end
  end
end
