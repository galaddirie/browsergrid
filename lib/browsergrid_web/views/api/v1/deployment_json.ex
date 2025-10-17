defmodule BrowsergridWeb.API.V1.DeploymentJSON do
  alias Browsergrid.Deployments.Deployment

  def index(%{deployments: deployments, meta: meta}) do
    %{
      success: true,
      data: for(deployment <- deployments, do: data(deployment)),
      meta: serialize_meta(meta)
    }
  end

  def show(%{deployment: deployment}) do
    %{
      success: true,
      data: data_detailed(deployment)
    }
  end

  def create(%{deployment: deployment}) do
    %{
      success: true,
      data: data_detailed(deployment),
      message: "Deployment created successfully"
    }
  end

  def deploy(%{deployment: deployment, session: session}) do
    %{
      success: true,
      data: %{
        deployment: data(deployment),
        session_id: session.id,
        status: "deploying"
      },
      message: "Deployment started"
    }
  end

  def delete(_assigns) do
    %{
      success: true,
      message: "Deployment deleted successfully"
    }
  end

  def statistics(%{stats: stats}) do
    %{
      success: true,
      data: stats
    }
  end

  defp data(%Deployment{} = deployment) do
    %{
      id: deployment.id,
      name: deployment.name,
      description: deployment.description,
      image: deployment.image,
      blurb: deployment.blurb,
      tags: deployment.tags,
      is_public: deployment.is_public,
      status: deployment.status
    }
  end

  defp data_detailed(%Deployment{} = deployment) do
    deployment
    |> data()
    |> Map.merge(%{
      root_directory: deployment.root_directory,
      install_command: deployment.install_command,
      start_command: deployment.start_command,
      environment_variables: deployment.environment_variables,
      parameters: deployment.parameters,
      session_id: deployment.session_id,
      last_deployed_at: deployment.last_deployed_at,
      inserted_at: deployment.inserted_at,
      updated_at: deployment.updated_at
    })
  end

  defp serialize_meta(nil), do: %{}

  defp serialize_meta(meta) do
    %{
      current_page: Map.get(meta, :current_page, 1),
      page_size: Map.get(meta, :page_size, 20),
      total_count: Map.get(meta, :total_count, 0),
      total_pages: Map.get(meta, :total_pages, 1)
    }
  end
end
