defmodule BrowsergridWeb.API.V1.DeploymentController do
  use BrowsergridWeb, :controller

  alias Browsergrid.Deployments

  action_fallback BrowsergridWeb.API.V1.FallbackController

  def index(conn, _params) do
    user = conn.assigns.current_user
    deployments = Deployments.list_user_deployments(user)
    json(conn, %{data: deployments})
  end

  def show(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    case Deployments.fetch_user_deployment(user, id) do
      {:ok, deployment} -> json(conn, %{data: deployment})
      {:error, _} -> {:error, :not_found}
    end
  end

  def create(conn, %{"deployment" => deployment_params}) do
    params = put_owner(deployment_params, conn)

    case Deployments.create_deployment(params) do
      {:ok, deployment} ->
        conn
        |> put_status(:created)
        |> json(%{data: deployment})

      {:error, %Ecto.Changeset{} = changeset} ->
        {:error, changeset}
    end
  end

  def delete(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    with {:ok, deployment} <- Deployments.fetch_user_deployment(user, id),
         {:ok, _} <- Deployments.delete_deployment(deployment) do
      send_resp(conn, :no_content, "")
    else
      {:error, _} -> {:error, :not_found}
    end
  end

  def deploy(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    with {:ok, deployment} <- Deployments.fetch_user_deployment(user, id),
         {:ok, {deployment, session}} <- Deployments.deploy(deployment) do
      json(conn, %{data: %{deployment: deployment, session: session}})
    else
      {:error, _} -> {:error, :not_found}
    end
  end

  defp put_owner(params, conn) do
    user_id = conn.assigns.current_user.id
    Map.put(params, "user_id", user_id)
  end
end
