defmodule Browsergrid.Repo.Migrations.AddNovncPortToSessions do
  use Ecto.Migration

  def change do
    alter table(:sessions) do
      add :novnc_port, :string
    end
  end
end
