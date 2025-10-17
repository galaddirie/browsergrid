defmodule Browsergrid.Repo.Migrations.AddMissingSessionFields do
  use Ecto.Migration

  def change do
    alter table(:sessions) do
      add :headless, :boolean, default: false
      add :timeout, :integer, default: 30

      add :screen, :map,
        default: %{"width" => 1920, "height" => 1080, "dpi" => 96, "scale" => 1.0}

      add :limits, :map, default: %{"cpu" => nil, "memory" => nil, "timeout_minutes" => 30}
    end
  end
end
