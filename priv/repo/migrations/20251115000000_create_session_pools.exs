defmodule Browsergrid.Repo.Migrations.CreateSessionPools do
  use Ecto.Migration

  def change do
    create table(:session_pools, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :description, :text
      add :session_template, :map, null: false, default: %{}
      add :target_ready, :integer, null: false, default: 0
      add :ttl_seconds, :integer
      add :system, :boolean, null: false, default: false
      add :owner_id, references(:users, type: :binary_id, on_delete: :delete_all)

      timestamps(type: :utc_datetime_usec)
    end

    create index(:session_pools, [:owner_id])
    create unique_index(:session_pools, [:owner_id, :name])

    alter table(:sessions) do
      add :session_pool_id, references(:session_pools, type: :binary_id, on_delete: :nilify_all)
      add :claimed_at, :utc_datetime_usec
      add :attachment_deadline_at, :utc_datetime_usec
    end

    create index(:sessions, [:session_pool_id])
    create index(:sessions, [:attachment_deadline_at])
  end
end
