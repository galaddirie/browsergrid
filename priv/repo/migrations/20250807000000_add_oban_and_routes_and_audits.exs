defmodule Browsergrid.Repo.Migrations.AddObanAndRoutesAndAudits do
  use Ecto.Migration

  def up do
    # Oban tables
    Oban.Migrations.up()

    # Routes
    create table(:routes, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :ip, :string, null: false
      add :port, :integer, null: false
      add :version, :bigint, null: false
      timestamps(type: :utc_datetime_usec)
    end

    create index(:routes, [:version])

    # Session audits
    create table(:session_audits) do
      add :session_id, references(:sessions, type: :uuid, on_delete: :delete_all), null: false
      add :action, :string, null: false
      add :metadata, :map, null: false, default: %{}
      timestamps(type: :utc_datetime_usec)
    end

    create index(:session_audits, [:session_id])

    # Add cluster to sessions
    alter table(:sessions) do
      add :cluster, :string
    end

    create index(:sessions, [:cluster])
  end

  def down do
    alter table(:sessions) do
      remove :cluster
    end

    drop table(:session_audits)
    drop index(:routes, [:version])
    drop table(:routes)

    Oban.Migrations.down(version: 1)
  end
end
