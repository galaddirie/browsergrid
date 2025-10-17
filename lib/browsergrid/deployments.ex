defmodule Browsergrid.Deployments do
  @moduledoc """
  The Deployments context - manages code deployment lifecycle.
  """

  import Ecto.Query, warn: false

  alias Browsergrid.Deployments.Deployment
  alias Browsergrid.Repo
  alias Browsergrid.Sessions

  require Logger

  @doc """
  Returns the list of deployments.
  """
  def list_deployments(opts \\ []) do
    Deployment
    |> maybe_filter_by_user(opts)
    |> order_by([d], desc: d.inserted_at)
    |> Repo.all()
  end

  @doc """
  Gets a single deployment.
  """
  def get_deployment!(id), do: Repo.get!(Deployment, id)
  def get_deployment(id), do: Repo.get(Deployment, id)

  @doc """
  Creates a deployment from uploaded archive and configuration.
  """
  def create_deployment(attrs \\ %{}) do
    %Deployment{}
    |> Deployment.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a deployment.
  """
  def update_deployment(%Deployment{} = deployment, attrs) do
    deployment
    |> Deployment.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a deployment.
  """
  def delete_deployment(%Deployment{} = deployment) do
    Repo.delete(deployment)
  end

  @doc """
  Deploys a deployment by creating a browser session with the deployment config.
  """
  def deploy(%Deployment{} = deployment) do
    session_params = %{
      name: "Deploy: #{deployment.name}",
      browser_type: :chrome,
      options: %{
        "deployment_id" => deployment.id,
        "deployment_type" => "user_code",
        "install_command" => deployment.install_command,
        "start_command" => deployment.start_command,
        "environment_variables" => deployment.environment_variables,
        "parameters" => deployment.parameters,
        "root_directory" => deployment.root_directory,
        "archive_path" => deployment.archive_path
      }
    }

    with {:ok, session} <- Sessions.create_session(session_params),
         {:ok, deployment} <-
           update_deployment(deployment, %{
             status: :deploying,
             session_id: session.id,
             last_deployed_at: DateTime.utc_now()
           }) do
      {:ok, {deployment, session}}
    end
  end

  @doc """
  Gets deployment statistics.
  """
  def get_statistics do
    deployments = list_deployments()

    by_status =
      deployments
      |> Enum.group_by(& &1.status)
      |> Map.new(fn {status, deployments} -> {status, length(deployments)} end)

    %{
      total: length(deployments),
      by_status: by_status,
      active: Enum.count(deployments, &(&1.status in [:deploying, :running])),
      failed: Enum.count(deployments, &(&1.status in [:failed, :error]))
    }
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking deployment changes.
  """
  def change_deployment(%Deployment{} = deployment, attrs \\ %{}) do
    Deployment.changeset(deployment, attrs)
  end

  defp maybe_filter_by_user(query, opts) do
    case Keyword.get(opts, :user_id) do
      nil -> query
      user_id -> where(query, [d], d.user_id == ^user_id)
    end
  end
end
