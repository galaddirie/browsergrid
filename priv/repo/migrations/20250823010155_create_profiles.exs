defmodule Browsergrid.Repo.Migrations.CreateProfiles do
  use Ecto.Migration

  def change do
    # Create profiles table
    create table(:profiles, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :description, :text
      add :browser_type, :string, null: false
      add :status, :string, null: false, default: "active"
      add :metadata, :map, default: %{}
      add :storage_size_bytes, :bigint
      add :last_used_at, :utc_datetime_usec
      add :version, :integer, null: false, default: 1
      add :user_id, :binary_id
      add :media_file_id, references(:media_files, type: :binary_id, on_delete: :nilify_all)

      timestamps(type: :utc_datetime_usec)
    end

    create index(:profiles, [:user_id])
    create index(:profiles, [:browser_type])
    create index(:profiles, [:status])
    create index(:profiles, [:last_used_at])
    create unique_index(:profiles, [:name, :user_id])

    # Create profile snapshots table
    create table(:profile_snapshots, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :version, :integer, null: false
      add :created_by_session_id, :binary_id
      add :metadata, :map, default: %{}
      add :storage_size_bytes, :bigint, null: false
      add :profile_id, references(:profiles, type: :binary_id, on_delete: :delete_all), null: false
      add :media_file_id, references(:media_files, type: :binary_id, on_delete: :restrict), null: false

      timestamps(updated_at: false, type: :utc_datetime_usec)
    end

    create index(:profile_snapshots, [:profile_id])
    create index(:profile_snapshots, [:version])
    create index(:profile_snapshots, [:created_by_session_id])

    # Add profile reference to sessions table
    alter table(:sessions) do
      add :profile_id, references(:profiles, type: :binary_id, on_delete: :nilify_all)
      add :profile_snapshot_created, :boolean, default: false
    end

    create index(:sessions, [:profile_id])
  end
end
