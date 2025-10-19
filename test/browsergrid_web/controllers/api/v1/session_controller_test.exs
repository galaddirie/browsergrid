defmodule BrowsergridWeb.API.V1.SessionControllerTest do
  use BrowsergridWeb.ConnCase, async: true

  alias Browsergrid.AccountsFixtures
  alias Browsergrid.ApiTokens
  alias Browsergrid.Repo
  alias Browsergrid.Sessions.Session

  setup %{conn: conn} do
    user = AccountsFixtures.user_fixture()
    {:ok, _token, plaintext} = ApiTokens.create_token(user, %{"name" => "Test"})

    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> put_req_header("authorization", "Bearer #{plaintext}")

    {:ok, conn: conn, user: user}
  end

  describe "index" do
    test "lists only the current user's sessions", %{conn: conn, user: user} do
      other_user = AccountsFixtures.user_fixture()

      insert_session!(user, %{name: "Mine"})
      insert_session!(other_user, %{name: "Theirs"})

      res = conn |> get(~p"/api/v1/sessions") |> json_response(200)

      assert [%{"name" => "Mine"}] = res["data"]
    end
  end

  describe "create" do
    test "creates a session bound to the current user", %{conn: conn, user: user} do
      payload = %{
        "session" => %{
          "name" => "API Session",
          "browser_type" => "chrome"
        }
      }

      res = conn |> post(~p"/api/v1/sessions", payload) |> json_response(201)

      assert res["data"]["name"] == "API Session"
      assert res["data"]["user_id"] == user.id
    end
  end

  describe "show" do
    test "returns the session when owned by the user", %{conn: conn, user: user} do
      session = insert_session!(user, %{name: "Owned"})

      res = conn |> get(~p"/api/v1/sessions/#{session.id}") |> json_response(200)

      assert res["data"]["id"] == session.id
    end

    test "returns 404 when accessing another user's session", %{conn: conn} do
      other_user = AccountsFixtures.user_fixture()
      session = insert_session!(other_user, %{name: "Foreign"})

      conn = get(conn, ~p"/api/v1/sessions/#{session.id}")

      assert conn.status == 404
      assert %{"error" => "not_found"} = Jason.decode!(conn.resp_body)
    end
  end

  describe "update" do
    test "updates session attributes", %{conn: conn, user: user} do
      session = insert_session!(user, %{name: "Old Name"})
      payload = %{"session" => %{"name" => "New Name", "user_id" => "ignored"}}

      res = conn |> put(~p"/api/v1/sessions/#{session.id}", payload) |> json_response(200)

      assert res["data"]["name"] == "New Name"
      assert res["data"]["user_id"] == user.id
    end
  end

  defp insert_session!(user, attrs) do
    params =
      Map.merge(
        %{
          name: "Session #{System.unique_integer()}",
          browser_type: :chrome,
          status: :pending,
          user_id: user.id,
          headless: false,
          timeout: 30,
          screen: %{"width" => 1920, "height" => 1080, "dpi" => 96, "scale" => 1.0},
          limits: %{}
        },
        attrs
      )

    %Session{}
    |> Session.changeset(params)
    |> Repo.insert!()
  end
end
