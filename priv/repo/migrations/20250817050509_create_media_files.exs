defmodule Browsergrid.Repo.Migrations.CreateMediaFiles do
  use Ecto.Migration

  def change do
    create table(:media_files, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :filename, :string, null: false
      add :original_filename, :string
      add :storage_path, :string, null: false
      add :content_type, :string, null: false
      add :size, :bigint, null: false
      add :backend, :string, null: false
      add :metadata, :map, default: %{}
      add :category, :string
      add :user_id, :binary_id
      add :session_id, references(:sessions, type: :binary_id, on_delete: :nilify_all)

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:media_files, [:storage_path])
    create index(:media_files, [:user_id])
    create index(:media_files, [:session_id])
    create index(:media_files, [:category])
    create index(:media_files, [:inserted_at])
  end
end
