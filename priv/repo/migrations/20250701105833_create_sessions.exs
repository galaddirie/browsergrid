defmodule Browsergrid.Repo.Migrations.CreateSessions do
  use Ecto.Migration

  def change do
    create table(:sessions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :browser_type, :string, null: false, default: "chrome"
      add :status, :string, null: false, default: "pending"
      add :options, :map, default: %{}
      add :cdp_port, :string
      add :vnc_port, :string
      add :node_id, references(:nodes, on_delete: :delete_all, type: :binary_id)

      timestamps()
    end

    create index(:sessions, [:node_id])
    create index(:sessions, [:status])
    create index(:sessions, [:browser_type])
    create index(:sessions, [:name])
  end
end
