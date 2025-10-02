defmodule Browsergrid.Repo.Migrations.DropProfileSnapshotCreatedFromSessions do
  use Ecto.Migration

  def change do
    alter table(:sessions) do
      remove :profile_snapshot_created
    end
  end
end
