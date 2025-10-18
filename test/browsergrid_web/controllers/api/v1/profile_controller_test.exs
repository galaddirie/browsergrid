defmodule BrowsergridWeb.API.V1.ProfileControllerTest do
  use BrowsergridWeb.ConnCase, async: true

  alias Browsergrid.AccountsFixtures
  alias Browsergrid.ApiTokens
  alias Browsergrid.Profiles.Profile
  alias Browsergrid.Repo

  setup %{conn: conn} do
    user = AccountsFixtures.user_fixture()
    {:ok, _token, plaintext} = ApiTokens.create_token(user, %{"name" => "Profile Token"})

    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> put_req_header("authorization", "Bearer #{plaintext}")

    {:ok, conn: conn, user: user}
  end

  describe "index" do
    test "lists profiles for the current user", %{conn: conn, user: user} do
      other_user = AccountsFixtures.user_fixture()

      insert_profile!(user, %{name: "My profile"})
      insert_profile!(other_user, %{name: "Other profile"})

      res = conn |> get(~p"/api/v1/profiles") |> json_response(200)

      assert [%{"name" => "My profile"}] = res["data"]
    end
  end

  describe "create" do
    test "creates a profile owned by the current user", %{conn: conn, user: user} do
      payload = %{
        "profile" => %{
          "name" => "API Profile",
          "browser_type" => "chrome"
        }
      }

      res = conn |> post(~p"/api/v1/profiles", payload) |> json_response(201)

      assert res["data"]["user_id"] == user.id
      assert res["data"]["name"] == "API Profile"
    end
  end

  describe "update" do
    test "updates profile attributes", %{conn: conn, user: user} do
      profile = insert_profile!(user, %{name: "Old"})

      payload = %{"profile" => %{"name" => "New"}}

      res = conn |> put(~p"/api/v1/profiles/#{profile.id}", payload) |> json_response(200)

      assert res["data"]["name"] == "New"
    end
  end

  describe "show" do
    test "returns 403 when attempting to access another user's profile", %{conn: conn} do
      other_user = AccountsFixtures.user_fixture()
      profile = insert_profile!(other_user, %{name: "Hidden"})

      conn = get(conn, ~p"/api/v1/profiles/#{profile.id}")

      assert conn.status == 403
    end
  end

  defp insert_profile!(user, attrs) do
    params =
      Map.merge(
        %{
          name: "Profile #{System.unique_integer()}",
          browser_type: :chrome,
          user_id: user.id,
          status: :active,
          metadata: %{},
          version: 1
        },
        attrs
      )

    %Profile{}
    |> Profile.changeset(params)
    |> Repo.insert!()
  end
end
