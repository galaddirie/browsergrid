defmodule Browsergrid.Repo.Migrations.RemoveCdpPortFromSessions do
  use Ecto.Migration

  def change do
    alter table(:sessions) do
      remove :cdp_port, :string
    end
  end
end
