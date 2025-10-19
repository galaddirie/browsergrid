defmodule Browsergrid.Repo.Migrations.AddLockVersionToSessionPools do
  use Ecto.Migration

  def change do
    alter table(:session_pools) do
      add :lock_version, :integer, default: 0, null: false
    end
  end
end
