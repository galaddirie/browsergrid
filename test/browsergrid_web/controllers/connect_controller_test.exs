defmodule BrowsergridWeb.ConnectControllerTest do
  use BrowsergridWeb.ConnCase, async: false

  alias Browsergrid.Connect

  @token "test-token"

  setup_all do
    # Allow the idle pool to provision the initial stub session
    Process.sleep(50)
    :ok
  end

  setup do
    on_exit(fn -> Connect.release(@token, :test_cleanup) end)
    :ok
  end

  test "claims a pooled session via path routing", %{conn: _conn} do
    payload = fetch_session_payload()

    assert is_binary(payload["sessionId"])
    assert String.starts_with?(payload["webSocketDebuggerUrl"], "ws://")
    assert payload["status"] == "claimed"
    assert payload["claimExpiresAt"]
  end

  test "subsequent claim reuses the same session for the token", %{conn: _conn} do
    session_id = fetch_session_payload()["sessionId"]

    session_id_again = fetch_session_payload()["sessionId"]

    assert session_id_again == session_id
  end

  test "json version endpoint returns metadata", %{conn: _conn} do
    _payload = fetch_session_payload()

    payload =
      build_conn()
      |> get("/connect/json/version", %{"token" => @token})
      |> json_response(200)

    assert String.starts_with?(payload["browserWSEndpoint"], "ws://")
    assert payload["sessionId"]
    assert payload["status"] in ["claimed", "connected"]
  end

  test "rejects requests without a token", %{conn: conn} do
    conn = get(conn, "/connect/json")
    assert %{"error" => "missing token parameter"} = json_response(conn, 400)
  end

  test "rejects requests with an invalid token", %{conn: conn} do
    conn = get(conn, "/connect/json", %{"token" => "invalid"})
    assert %{"error" => "unauthorized"} = json_response(conn, 401)
  end

  test "host-based route is disabled when routing mode is path", %{conn: conn} do
    conn = get(conn, "/json", %{"token" => @token})
    assert response(conn, 404)
  end

  test "websocket upgrade without claim returns not found", %{conn: conn} do
    conn =
      conn
      |> put_req_header("connection", "upgrade")
      |> put_req_header("upgrade", "websocket")
      |> get("/connect/json", %{"token" => @token})

    assert conn.status == 404
  end

  test "releases and reprovisions sessions", %{conn: _conn} do
    session_id = fetch_session_payload()["sessionId"]

    :ok = Connect.release(@token, :test_release)

    new_session_id = fetch_session_payload()["sessionId"]

    refute new_session_id == session_id
  end

  defp fetch_session_payload(attempts \\ 20)
  defp fetch_session_payload(0), do: flunk("no idle sessions became available")

  defp fetch_session_payload(attempts) do
    conn = get(build_conn(), "/connect/json", %{"token" => @token})

    case conn.status do
      200 ->
        conn
        |> json_response(200)
        |> List.first()

      503 ->
        Process.sleep(50)
        fetch_session_payload(attempts - 1)

      other ->
        flunk("unexpected status #{inspect(other)} while claiming session")
    end
  end
end
