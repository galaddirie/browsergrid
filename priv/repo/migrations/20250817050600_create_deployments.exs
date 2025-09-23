defmodule Browsergrid.Repo.Migrations.CreateDeployments do
  use Ecto.Migration

  def change do
    create table(:deployments, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :description, :text
      add :archive_path, :string, null: false
      add :root_directory, :string, default: "./"
      add :install_command, :text
      add :start_command, :text, null: false
      add :environment_variables, {:array, :map}, default: []
      add :parameters, {:array, :map}, default: []
      add :status, :string, default: "pending", null: false
      add :last_deployed_at, :utc_datetime_usec
      add :session_id, references(:sessions, on_delete: :nilify_all, type: :binary_id)

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:deployments, [:name])
    create index(:deployments, [:status])
    create index(:deployments, [:session_id])
    create index(:deployments, [:inserted_at])
  end
end
