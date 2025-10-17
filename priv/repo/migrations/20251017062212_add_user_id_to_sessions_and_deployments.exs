defmodule Browsergrid.Repo.Migrations.AddUserIdToSessionsAndDeployments do
  use Ecto.Migration

  def change do
    alter table(:sessions) do
      add :user_id, references(:users, type: :binary_id, on_delete: :nilify_all)
    end

    alter table(:deployments) do
      add :user_id, references(:users, type: :binary_id, on_delete: :nilify_all)
    end

    create index(:sessions, [:user_id])
    create index(:deployments, [:user_id])

    # Note: Using nilify_all instead of delete_all to preserve session/deployment
    # records for audit purposes even if a user is deleted
  end
end
