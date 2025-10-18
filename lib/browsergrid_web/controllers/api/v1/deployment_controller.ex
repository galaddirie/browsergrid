defmodule BrowsergridWeb.API.V1.DeploymentController do
  use BrowsergridWeb, :controller

  alias Browsergrid.Deployments
  alias Browsergrid.Deployments.Deployment
  alias BrowsergridWeb.Controllers.API.Concerns.Authorization

  action_fallback BrowsergridWeb.API.V1.FallbackController

  def index(conn, _params) do
    user = conn.assigns.current_user
    deployments = Deployments.list_deployments(user_id: user.id)
    json(conn, %{data: deployments})
  end

  def show(conn, %{"id" => id}) do
    with {:ok, deployment} <- fetch_deployment(id),
         {:ok, deployment} <- Authorization.authorize_resource(conn, deployment) do
      json(conn, %{data: deployment})
    else
      {:error, %Plug.Conn{} = conn} ->
        conn

      {:error, reason} ->
        {:error, reason}
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
    with {:ok, deployment} <- fetch_deployment(id),
         {:ok, deployment} <- Authorization.authorize_resource(conn, deployment),
         {:ok, _} <- Deployments.delete_deployment(deployment) do
      send_resp(conn, :no_content, "")
    else
      {:error, %Plug.Conn{} = conn} ->
        conn

      {:error, reason} ->
        {:error, reason}
    end
  end

  def deploy(conn, %{"id" => id}) do
    with {:ok, deployment} <- fetch_deployment(id),
         {:ok, deployment} <- Authorization.authorize_resource(conn, deployment),
         {:ok, {deployment, session}} <- Deployments.deploy(deployment) do
      json(conn, %{data: %{deployment: deployment, session: session}})
    else
      {:error, %Plug.Conn{} = conn} ->
        conn

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp fetch_deployment(id) do
    case Deployments.get_deployment(id) do
      %Deployment{} = deployment -> {:ok, deployment}
      nil -> {:error, :not_found}
    end
  end

  defp put_owner(params, conn) do
    user_id = conn.assigns.current_user.id
    Map.put(params, "user_id", user_id)
  end
end
