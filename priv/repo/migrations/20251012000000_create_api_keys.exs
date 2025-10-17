defmodule Browsergrid.Repo.Migrations.CreateApiKeys do
  use Ecto.Migration

  def change do
    create table(:api_keys, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :key_hash, :string, null: false
      add :prefix, :string, null: false, size: 12
      add :last_four, :string, null: false, size: 4
      add :created_by, :string
      add :revoked_at, :utc_datetime_usec
      add :expires_at, :utc_datetime_usec
      add :last_used_at, :utc_datetime_usec
      add :usage_count, :integer, null: false, default: 0
      add :metadata, :map, null: false, default: %{}

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:api_keys, [:prefix])
    create index(:api_keys, [:revoked_at])
    create index(:api_keys, [:expires_at])
  end
end
