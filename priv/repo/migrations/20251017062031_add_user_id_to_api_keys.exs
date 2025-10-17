defmodule Browsergrid.Repo.Migrations.AddUserIdToApiKeys do
  use Ecto.Migration

  def change do
    alter table(:api_keys) do
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all)
    end

    create index(:api_keys, [:user_id])

    # For existing API keys, we'll allow null user_id temporarily
    # In a production system, you'd want to assign these to a system user
    # or migrate them appropriately before enforcing the constraint
  end
end
