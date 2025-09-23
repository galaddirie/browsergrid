defmodule Browsergrid.Repo.Migrations.CreateNodes do
  use Ecto.Migration

  def change do
    create table(:nodes, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :status, :string, null: false, default: "starting"
      add :provider, :string, null: false, default: "fly"
      add :provider_id, :string, null: false

      timestamps()
    end

    create index(:nodes, [:status])
    create index(:nodes, [:provider])
    create unique_index(:nodes, [:provider, :provider_id])
  end
end
