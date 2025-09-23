defmodule Browsergrid.Repo.Migrations.AddAgentFieldsToDeployments do
  use Ecto.Migration

  def change do
    alter table(:deployments) do
      add :image, :string
      add :blurb, :text
      add :tags, {:array, :string}, default: []
      add :is_public, :boolean, default: false, null: false
    end

    create index(:deployments, [:is_public])
    create index(:deployments, [:tags], using: :gin)
  end
end
