defmodule BrowsergridWeb.Inertia.V1.DeploymentController do
  use BrowsergridWeb, :controller

  alias Browsergrid.Deployments
  alias Browsergrid.Media

  plug :load_deployment when action in [:show, :deploy, :delete]

  def index(conn, _params) do
    user = conn.assigns.current_user
    deployments = Deployments.list_user_deployments(user)

    conn
    |> assign_prop(:deployments, deployments)
    |> assign_prop(:total, length(deployments))
    |> render_inertia("Deployments/Index")
  end

  def show(%{assigns: %{deployment: deployment}} = conn, _params) do
    conn
    |> assign_prop(:deployment, deployment)
    |> render_inertia("Deployments/Show")
  end

  def new(conn, _params) do
    render_inertia(conn, "Deployments/New")
  end

  def create(conn, params) do
    user = conn.assigns.current_user

    with {:ok, validated_params} <- validate_upload_params(params),
         {:ok, deployment} <- handle_deployment_upload(validated_params, user) do
      conn
      |> put_flash(:info, "Deployment created successfully")
      |> redirect(to: ~p"/deployments/#{deployment.id}")
    else
      {:error, :validation_failed, errors} ->
        conn
        |> assign_errors(errors)
        |> render_inertia("Deployments/New")

      {:error, :no_archive} ->
        conn
        |> assign_errors(%{archive: ["Archive file is required"]})
        |> render_inertia("Deployments/New")

      {:error, :upload_failed, reason} ->
        conn
        |> assign_errors(%{archive: ["Upload failed: #{reason}"]})
        |> render_inertia("Deployments/New")

      {:error, changeset} ->
        conn
        |> assign_errors(changeset)
        |> render_inertia("Deployments/New")
    end
  end

  def deploy(%{assigns: %{deployment: deployment}} = conn, _params) do
    case Deployments.deploy(deployment) do
      {:ok, {_updated_deployment, session}} ->
        conn
        |> put_flash(:info, "Deployment started successfully")
        |> redirect(to: ~p"/sessions/#{session.id}")

      {:error, reason} ->
        conn
        |> put_flash(:error, "Failed to deploy: #{inspect(reason)}")
        |> redirect(to: ~p"/deployments/#{deployment.id}")
    end
  end

  def delete(%{assigns: %{deployment: deployment}} = conn, _params) do
    case Deployments.delete_deployment(deployment) do
      {:ok, _} ->
        conn
        |> put_flash(:info, "Deployment deleted successfully")
        |> redirect(to: ~p"/deployments")

      {:error, _} ->
        conn
        |> put_flash(:error, "Failed to delete deployment")
        |> redirect(to: ~p"/deployments/#{deployment.id}")
    end
  end

  # Private functions

  defp validate_upload_params(params) do
    errors = %{}

    # Validate required fields
    errors = validate_required_field(errors, params, "name", "Name is required")
    errors = validate_required_field(errors, params, "start_command", "Start command is required")
    errors = validate_archive(errors, params)

    # Validate environment variables
    errors = validate_environment_variables(errors, params)

    # Validate parameters
    errors = validate_parameters(errors, params)

    if map_size(errors) == 0 do
      {:ok, params}
    else
      {:error, :validation_failed, errors}
    end
  end

  defp validate_required_field(errors, params, field, message) do
    case Map.get(params, field) do
      nil -> Map.put(errors, String.to_atom(field), [message])
      "" -> Map.put(errors, String.to_atom(field), [message])
      _ -> errors
    end
  end

  defp validate_archive(errors, params) do
    case Map.get(params, "archive") do
      %Plug.Upload{content_type: "application/zip"} -> errors
      %Plug.Upload{} -> Map.put(errors, :archive, ["File must be a ZIP archive"])
      nil -> Map.put(errors, :archive, ["Archive file is required"])
      _ -> Map.put(errors, :archive, ["Invalid archive file"])
    end
  end

  defp validate_environment_variables(errors, params) do
    case get_json_field(params, "environment_variables") do
      {:ok, env_vars} when is_list(env_vars) ->
        case validate_env_var_format(env_vars) do
          :ok -> errors
          {:error, message} -> Map.put(errors, :environment_variables, [message])
        end

      _ ->
        errors
    end
  end

  defp validate_parameters(errors, params) do
    case get_json_field(params, "parameters") do
      {:ok, parameters} when is_list(parameters) ->
        case validate_parameter_format(parameters) do
          :ok -> errors
          {:error, message} -> Map.put(errors, :parameters, [message])
        end

      _ ->
        errors
    end
  end

  defp get_json_field(params, field) do
    case Map.get(params, field) do
      value when is_binary(value) ->
        case Jason.decode(value) do
          {:ok, decoded} -> {:ok, decoded}
          {:error, _} -> {:error, :invalid_json}
        end

      value when is_list(value) ->
        {:ok, value}

      _ ->
        {:ok, []}
    end
  end

  defp validate_env_var_format(env_vars) do
    valid? =
      Enum.all?(env_vars, fn
        %{"key" => key, "value" => value} when is_binary(key) and is_binary(value) ->
          String.trim(key) != "" and String.trim(value) != ""

        _ ->
          false
      end)

    if valid?, do: :ok, else: {:error, "Environment variables must have non-empty key and value"}
  end

  defp validate_parameter_format(parameters) do
    valid? =
      Enum.all?(parameters, fn
        %{"key" => key, "label" => label} when is_binary(key) and is_binary(label) ->
          String.trim(key) != "" and String.trim(label) != ""

        _ ->
          false
      end)

    if valid?, do: :ok, else: {:error, "Parameters must have non-empty key and label"}
  end

  defp handle_deployment_upload(%{"archive" => archive} = params, user) when not is_nil(archive) do
    case upload_archive(archive) do
      {:ok, media_file} ->
        deployment_attrs =
          params
          |> Map.delete("archive")
          |> Map.put("archive_path", media_file.storage_path)
          |> Map.put("user_id", user.id)
          |> parse_json_fields()

        Deployments.create_deployment(deployment_attrs)

      {:error, reason} ->
        {:error, :upload_failed, reason}
    end
  end

  defp handle_deployment_upload(_params, _user) do
    {:error, :no_archive}
  end

  defp upload_archive(%Plug.Upload{} = upload) do
    opts = [
      category: "deployments",
      metadata: %{
        "original_filename" => upload.filename,
        "upload_type" => "deployment_archive"
      }
    ]

    Media.upload_from_plug(upload, opts)
  end

  defp parse_json_fields(params) do
    params
    |> parse_json_field("environment_variables")
    |> parse_json_field("parameters")
  end

  defp parse_json_field(params, field) do
    case Map.get(params, field) do
      value when is_binary(value) ->
        case Jason.decode(value) do
          {:ok, decoded} -> Map.put(params, field, decoded)
          {:error, _} -> params
        end

      _ ->
        params
    end
  end

  defp load_deployment(%{params: %{"id" => id}} = conn, _opts) do
    user = conn.assigns.current_user

    case Deployments.fetch_user_deployment(user, id) do
      {:ok, deployment} -> assign(conn, :deployment, deployment)
      {:error, _} -> render_not_found(conn)
    end
  end

  defp load_deployment(conn, _opts), do: conn

  defp render_not_found(conn) do
    conn
    |> put_status(:not_found)
    |> put_view(BrowsergridWeb.ErrorHTML)
    |> render("404", layout: false)
    |> halt()
  end
end
