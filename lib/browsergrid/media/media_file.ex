defmodule Browsergrid.Media.MediaFile do
  @moduledoc """
  Database record for uploaded media files.
  Tracks file metadata and ownership.
  """

  use Browsergrid.Schema

  import Ecto.Changeset

  @derive {Jason.Encoder, except: [:__meta__]}

  @type t :: %__MODULE__{
          id: Ecto.UUID.t() | nil,
          filename: String.t(),
          original_filename: String.t(),
          storage_path: String.t(),
          content_type: String.t(),
          size: integer(),
          backend: atom(),
          metadata: map(),
          user_id: Ecto.UUID.t() | nil,
          session_id: Ecto.UUID.t() | nil,
          category: String.t(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  schema "media_files" do
    field :filename, :string
    field :original_filename, :string
    field :storage_path, :string
    field :content_type, :string
    field :size, :integer
    field :backend, Ecto.Enum, values: [:local, :s3, :gcs], default: :local
    field :metadata, :map, default: %{}
    field :category, :string

    belongs_to :user, Browsergrid.Accounts.User, type: :binary_id
    belongs_to :session, Browsergrid.Sessions.Session, type: :binary_id

    timestamps()
  end

  def changeset(media_file, attrs) do
    media_file
    |> cast(attrs, [
      :filename,
      :original_filename,
      :storage_path,
      :content_type,
      :size,
      :backend,
      :metadata,
      :user_id,
      :session_id,
      :category
    ])
    |> validate_required([
      :filename,
      :storage_path,
      :content_type,
      :size,
      :backend
    ])
    |> validate_number(:size, greater_than: 0)
    |> unique_constraint(:storage_path)
  end
end
