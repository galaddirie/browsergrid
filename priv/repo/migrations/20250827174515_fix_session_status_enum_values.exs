defmodule Browsergrid.Repo.Migrations.FixSessionStatusEnumValues do
  use Ecto.Migration

  def change do
    # Fix invalid status values that don't match the Ecto enum
    # Change "failed" status to "error" which is a valid enum value
    execute(
      "UPDATE sessions SET status = 'error' WHERE status = 'failed'",
      "UPDATE sessions SET status = 'failed' WHERE status = 'error'"
    )
  end
end
