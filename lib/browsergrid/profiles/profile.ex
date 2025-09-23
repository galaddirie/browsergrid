defmodule Browsergrid.Profiles.Profile do
  @moduledoc """
  Browser profile management for persistent browser state.
  Profiles store browser data (cookies, localStorage, extensions, etc.) between sessions.
  """

  use Browsergrid.Schema
  alias Browsergrid.Media.MediaFile

  @derive {Jason.Encoder, except: [:__meta__, :sessions, :snapshots, :media_file]}

  @browser_types [:chrome, :chromium, :firefox]
  @statuses [:active, :archived, :updating, :error]

  @type t :: %__MODULE__{
    id: Ecto.UUID.t() | nil,
    name: String.t(),
    description: String.t() | nil,
    browser_type: atom(),
    status: atom(),
    metadata: map(),
    storage_size_bytes: integer() | nil,
    last_used_at: DateTime.t() | nil,
    version: integer(),
    media_file_id: Ecto.UUID.t() | nil,
    user_id: Ecto.UUID.t() | nil,
    inserted_at: DateTime.t(),
    updated_at: DateTime.t()
  }

  schema "profiles" do
    field :name, :string
    field :description, :string
    field :browser_type, Ecto.Enum, values: @browser_types, default: :chrome
    field :status, Ecto.Enum, values: @statuses, default: :active
    field :metadata, :map, default: %{}
    field :storage_size_bytes, :integer
    field :last_used_at, :utc_datetime_usec
    field :version, :integer, default: 1
    field :user_id, :binary_id

    # Reference to the current profile data in media storage
    belongs_to :media_file, MediaFile, type: :binary_id

    # Sessions using this profile
    has_many :sessions, Browsergrid.Sessions.Session

    # Profile snapshots/versions
    has_many :snapshots, Browsergrid.Profiles.ProfileSnapshot

    timestamps()
  end

  def changeset(profile, attrs) do
    profile
    |> cast(attrs, [
      :name,
      :description,
      :browser_type,
      :status,
      :metadata,
      :storage_size_bytes,
      :last_used_at,
      :version,
      :media_file_id,
      :user_id
    ])
    |> validate_required([:name, :browser_type])
    |> validate_inclusion(:browser_type, @browser_types)
    |> validate_inclusion(:status, @statuses)
    |> validate_length(:name, min: 1, max: 100)
    |> validate_length(:description, max: 500)
    |> unique_constraint([:name, :user_id])
  end

  def create_changeset(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
    |> put_change(:status, :active)
    |> put_change(:version, 1)
  end

  def update_version(profile) do
    change(profile, version: profile.version + 1)
  end
end
