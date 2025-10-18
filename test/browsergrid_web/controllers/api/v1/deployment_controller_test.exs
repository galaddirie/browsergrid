defmodule BrowsergridWeb.API.V1.DeploymentControllerTest do
  use BrowsergridWeb.ConnCase, async: true

  alias Browsergrid.AccountsFixtures
  alias Browsergrid.ApiTokens
  alias Browsergrid.Deployments.Deployment
  alias Browsergrid.Repo

  setup %{conn: conn} do
    user = AccountsFixtures.user_fixture()
    {:ok, _token, plaintext} = ApiTokens.create_token(user, %{"name" => "Deploy Token"})

    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> put_req_header("authorization", "Bearer #{plaintext}")

    {:ok, conn: conn, user: user}
  end

  describe "index" do
    test "returns deployments for the authenticated user", %{conn: conn, user: user} do
      other_user = AccountsFixtures.user_fixture()

      insert_deployment!(user, %{name: "Mine"})
      insert_deployment!(other_user, %{name: "Yours"})

      res = get(conn, ~p"/api/v1/deployments") |> json_response(200)

      assert [%{"name" => "Mine"}] = res["data"]
    end
  end

  describe "create" do
    test "creates a deployment belonging to the user", %{conn: conn, user: user} do
      payload = %{
        "deployment" => %{
          "name" => "CLI Deploy",
          "archive_path" => "/tmp/archive.tar.gz",
          "start_command" => "bin/start"
        }
      }

      res = post(conn, ~p"/api/v1/deployments", payload) |> json_response(201)

      assert res["data"]["user_id"] == user.id
    end
  end

  describe "deploy" do
    test "enqueues a deployment session for the user", %{conn: conn, user: user} do
      deployment = insert_deployment!(user, %{name: "Runnable"})
      deployment_id = deployment.id

      res = post(conn, ~p"/api/v1/deployments/#{deployment.id}/deploy") |> json_response(200)

      assert %{"deployment" => %{"id" => ^deployment_id}, "session" => session} = res["data"]
      assert session["user_id"] == user.id
    end
  end

  describe "show" do
    test "returns 403 when accessing another user's deployment", %{conn: conn} do
      other_user = AccountsFixtures.user_fixture()
      deployment = insert_deployment!(other_user, %{name: "Hidden"})

      conn = get(conn, ~p"/api/v1/deployments/#{deployment.id}")

      assert conn.status == 403
    end
  end

  defp insert_deployment!(user, attrs) do
    params =
      %{
        name: "Deployment #{System.unique_integer()}",
        archive_path: "/tmp/archive.zip",
        start_command: "./start.sh",
        user_id: user.id,
        status: :pending,
        description: "Example deployment",
        environment_variables: [],
        parameters: [],
        tags: []
      }
      |> Map.merge(attrs)

    %Deployment{}
    |> Deployment.changeset(params)
    |> Repo.insert!()
  end
end
