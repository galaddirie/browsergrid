defmodule Browsergrid.Repo.Migrations.RemoveVncFieldsFromSessions do
  use Ecto.Migration

  def change do
    alter table(:sessions) do
      remove :vnc_port, :string
      remove :novnc_port, :string
    end
  end
end
