defmodule Browsergrid.Deployments do
  @moduledoc """
  The Deployments context - manages code deployment lifecycle.
  """

  import Ecto.Query, warn: false

  alias Browsergrid.Accounts.User
  alias Browsergrid.Authorization
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
  Lists deployments owned by the given user.
  """
  @spec list_user_deployments(User.t(), Keyword.t()) :: [Deployment.t()]
  def list_user_deployments(%User{} = user, opts \\ []) do
    Deployment
    |> Authorization.scope_owned(user)
    |> maybe_preload(opts)
    |> order_by([d], desc: d.inserted_at)
    |> Repo.all()
  end

  @doc """
  Gets a single deployment.
  """
  def get_deployment!(id), do: Repo.get!(Deployment, id)
  def get_deployment(id), do: Repo.get(Deployment, id)

  @doc """
  Fetches a deployment for the given user, returning `{:error, :not_found}` when unauthorized.
  """
  @spec fetch_user_deployment(User.t(), Ecto.UUID.t(), Keyword.t()) ::
          {:ok, Deployment.t()} | {:error, :not_found}
  def fetch_user_deployment(user, id, opts \\ [])

  def fetch_user_deployment(%User{} = user, id, opts) when is_binary(id) do
    query =
      Deployment
      |> Authorization.scope_owned(user)
      |> where([d], d.id == ^id)
      |> maybe_preload(opts)

    case Repo.one(query) do
      %Deployment{} = deployment -> {:ok, deployment}
      nil -> {:error, :not_found}
    end
  end

  def fetch_user_deployment(_user, _id, _opts), do: {:error, :not_found}

  @doc """
  Fetches a deployment for a user, raising on failure.
  """
  @spec fetch_user_deployment!(User.t(), Ecto.UUID.t(), Keyword.t()) :: Deployment.t()
  def fetch_user_deployment!(%User{} = user, id, opts \\ []) do
    Deployment
    |> Authorization.scope_owned(user)
    |> where([d], d.id == ^id)
    |> maybe_preload(opts)
    |> Repo.one!()
  end

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
      user_id: deployment.user_id,
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
    case Keyword.get(opts, :user) do
      %User{} = user ->
        Authorization.scope_owned(query, user)

      _ ->
        case Keyword.get(opts, :user_id) do
          nil -> query
          user_id -> where(query, [d], d.user_id == ^user_id)
        end
    end
  end

  defp maybe_preload(query, opts) do
    case Keyword.get(opts, :preload, false) do
      false -> query
      nil -> query
      true -> preload(query, [:user])
      preloads when is_list(preloads) -> preload(query, ^preloads)
    end
  end

  @doc """
  Returns `true` when the user owns the deployment (admins always pass).
  """
  @spec user_owns_deployment?(User.t() | nil, Deployment.t()) :: boolean()
  def user_owns_deployment?(user, %Deployment{} = deployment) do
    Authorization.owns?(user, deployment)
  end
end
