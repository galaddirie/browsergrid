defmodule Browsergrid.Repo.Migrations.RemoveNodes do
  use Ecto.Migration

  def change do
    alter table(:sessions) do
      remove :node_id
    end

    drop table(:nodes)
  end
end
