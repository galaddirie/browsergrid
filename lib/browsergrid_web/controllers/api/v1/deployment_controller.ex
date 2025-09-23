defmodule BrowsergridWeb.API.V1.DeploymentController do
  use BrowsergridWeb, :controller

  alias Browsergrid.Deployments
  alias Browsergrid.Media

  action_fallback BrowsergridWeb.API.V1.FallbackController

  def index(conn, _params) do
    deployments = Deployments.list_deployments()
    total = length(deployments)

    meta = %{
      total_count: total,
      page_size: 20,
      current_page: 1,
      total_pages: div(total, 20) + if(rem(total, 20) > 0, do: 1, else: 0)
    }

    render(conn, :index, deployments: deployments, meta: meta)
  end

  def show(conn, %{"id" => id}) do
    case Deployments.get_deployment(id) do
      nil ->
        send_resp(conn, 404, "Deployment not found")
      deployment ->
        render(conn, :show, deployment: deployment)
    end
  end

  def create(conn, %{"deployment" => deployment_params, "archive" => archive_upload}) do
    # Handle file upload first
    case upload_archive(archive_upload) do
      {:ok, media_file} ->
        attrs = Map.put(deployment_params, "archive_path", media_file.storage_path)

        case Deployments.create_deployment(attrs) do
          {:ok, deployment} ->
            conn
            |> put_status(:created)
            |> render(:create, deployment: deployment)

          {:error, changeset} ->
            {:error, changeset}
        end

      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{success: false, error: "File upload failed: #{inspect(reason)}"})
    end
  end

  def deploy(conn, %{"id" => id}) do
    case Deployments.get_deployment(id) do
      nil ->
        send_resp(conn, 404, "Deployment not found")

      deployment ->
        case Deployments.deploy(deployment) do
          {:ok, {deployment, session}} ->
            conn
            |> put_status(:accepted)
            |> render(:deploy, deployment: deployment, session: session)

          {:error, reason} ->
            conn
            |> put_status(:internal_server_error)
            |> json(%{success: false, error: "Deployment failed: #{inspect(reason)}"})
        end
    end
  end

  def delete(conn, %{"id" => id}) do
    case Deployments.get_deployment(id) do
      nil ->
        send_resp(conn, 404, "Deployment not found")

      deployment ->
        case Deployments.delete_deployment(deployment) do
          {:ok, _} ->
            send_resp(conn, :no_content, "")
          {:error, _} ->
            send_resp(conn, 500, "Failed to delete deployment")
        end
    end
  end

  def statistics(conn, _params) do
    stats = Deployments.get_statistics()
    render(conn, :statistics, stats: stats)
  end

  # Private functions

  defp upload_archive(%Plug.Upload{} = upload) do
    opts = [
      category: "deployments",
      metadata: %{
        "original_filename" => upload.filename,
        "upload_type" => "code_archive"
      }
    ]

    Media.upload_from_plug(upload, opts)
  end
end
