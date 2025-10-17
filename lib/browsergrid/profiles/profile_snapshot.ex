defmodule Browsergrid.Profiles.ProfileSnapshot do
  @moduledoc """
  Snapshot of a profile at a specific point in time.
  Used for versioning and rollback capabilities.
  """

  use Browsergrid.Schema

  alias Browsergrid.Media.MediaFile
  alias Browsergrid.Profiles.Profile

  @type t :: %__MODULE__{
          id: Ecto.UUID.t() | nil,
          version: integer(),
          created_by_session_id: Ecto.UUID.t() | nil,
          metadata: map(),
          storage_size_bytes: integer(),
          profile_id: Ecto.UUID.t(),
          media_file_id: Ecto.UUID.t(),
          inserted_at: DateTime.t()
        }

  schema "profile_snapshots" do
    field :version, :integer
    field :created_by_session_id, :binary_id
    field :metadata, :map, default: %{}
    field :storage_size_bytes, :integer

    belongs_to :profile, Profile, type: :binary_id
    belongs_to :media_file, MediaFile, type: :binary_id

    timestamps(updated_at: false)
  end

  def changeset(snapshot, attrs) do
    snapshot
    |> cast(attrs, [
      :version,
      :created_by_session_id,
      :metadata,
      :storage_size_bytes,
      :profile_id,
      :media_file_id
    ])
    |> validate_required([
      :version,
      :storage_size_bytes,
      :profile_id,
      :media_file_id
    ])
    |> validate_number(:version, greater_than: 0)
    |> validate_number(:storage_size_bytes, greater_than_or_equal_to: 0)
  end
end
