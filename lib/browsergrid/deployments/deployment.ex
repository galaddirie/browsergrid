defmodule Browsergrid.Deployments.Deployment do
  @moduledoc """
  Ecto schema for a code deployment
  """

  use Browsergrid.Schema

  @derive {Jason.Encoder, except: [:__meta__]}

  @statuses [:pending, :deploying, :running, :stopped, :failed, :error]

  @type t :: %__MODULE__{
          id: Ecto.UUID.t() | nil,
          name: String.t(),
          description: String.t() | nil,
          image: String.t() | nil,
          blurb: String.t() | nil,
          tags: list(String.t()),
          is_public: boolean(),
          archive_path: String.t(),
          root_directory: String.t(),
          install_command: String.t() | nil,
          start_command: String.t(),
          environment_variables: list(map()),
          parameters: list(map()),
          status: atom(),
          session_id: Ecto.UUID.t() | nil,
          last_deployed_at: DateTime.t() | nil,
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  schema "deployments" do
    field :name, :string
    field :description, :string
    field :image, :string
    field :blurb, :string
    field :tags, {:array, :string}, default: []
    field :is_public, :boolean, default: false
    # Path to the uploaded archive file
    field :archive_path, :string
    field :root_directory, :string, default: "./"
    field :install_command, :string
    field :start_command, :string
    field :environment_variables, {:array, :map}, default: []
    field :parameters, {:array, :map}, default: []
    field :status, Ecto.Enum, values: @statuses, default: :pending
    field :last_deployed_at, :utc_datetime_usec

    # References
    belongs_to :session, Browsergrid.Sessions.Session, type: :binary_id

    timestamps()
  end

  def changeset(deployment, attrs) do
    deployment
    |> cast(attrs, [
      :name,
      :description,
      :image,
      :blurb,
      :tags,
      :is_public,
      :archive_path,
      :root_directory,
      :install_command,
      :start_command,
      :environment_variables,
      :parameters,
      :status,
      :session_id,
      :last_deployed_at
    ])
    |> validate_required([:name, :archive_path, :start_command])
    |> validate_inclusion(:status, @statuses)
    |> validate_length(:name, min: 1, max: 100)
    |> validate_length(:blurb, max: 500)
    |> unique_constraint(:name)
    |> validate_environment_variables()
    |> validate_parameters()
    |> validate_tags()
  end

  def create_changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [
      :name,
      :description,
      :image,
      :blurb,
      :tags,
      :is_public,
      :archive_path,
      :root_directory,
      :install_command,
      :start_command,
      :environment_variables,
      :parameters
    ])
    |> validate_required([:name, :archive_path, :start_command])
    |> put_change(:status, :pending)
    |> validate_length(:name, min: 1, max: 100)
    |> validate_length(:blurb, max: 500)
    |> unique_constraint(:name)
    |> validate_environment_variables()
    |> validate_parameters()
    |> validate_tags()
  end

  defp validate_environment_variables(changeset) do
    env_vars = get_field(changeset, :environment_variables) || []

    case validate_env_vars(env_vars) do
      :ok -> changeset
      {:error, message} -> add_error(changeset, :environment_variables, message)
    end
  end

  defp validate_parameters(changeset) do
    params = get_field(changeset, :parameters) || []

    case validate_params(params) do
      :ok -> changeset
      {:error, message} -> add_error(changeset, :parameters, message)
    end
  end

  defp validate_env_vars(env_vars) when is_list(env_vars) do
    valid? =
      Enum.all?(env_vars, fn
        %{"key" => key, "value" => value} when is_binary(key) and is_binary(value) ->
          String.trim(key) != "" and String.trim(value) != ""

        _ ->
          false
      end)

    if valid?, do: :ok, else: {:error, "Environment variables must have non-empty key and value"}
  end

  defp validate_params(params) when is_list(params) do
    valid? =
      Enum.all?(params, fn
        %{"key" => key, "label" => label} when is_binary(key) and is_binary(label) ->
          String.trim(key) != "" and String.trim(label) != ""

        _ ->
          false
      end)

    if valid?, do: :ok, else: {:error, "Parameters must have non-empty key and label"}
  end

  defp validate_tags(changeset) do
    tags = get_field(changeset, :tags) || []

    case validate_tag_format(tags) do
      :ok -> changeset
      {:error, message} -> add_error(changeset, :tags, message)
    end
  end

  defp validate_tag_format(tags) when is_list(tags) do
    if length(tags) <= 10 do
      valid? =
        Enum.all?(tags, fn tag ->
          is_binary(tag) and String.length(String.trim(tag)) > 0 and String.length(tag) <= 50
        end)

      if valid?, do: :ok, else: {:error, "Tags must be non-empty strings with max 50 characters each"}
    else
      {:error, "Maximum 10 tags allowed"}
    end
  end
end
