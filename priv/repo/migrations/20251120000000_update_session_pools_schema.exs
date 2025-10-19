defmodule Browsergrid.Repo.Migrations.UpdateSessionPoolsSchema do
  use Ecto.Migration

  def up do
    rename table(:session_pools), :target_ready, to: :min_ready

    alter table(:session_pools) do
      add :max_ready, :integer, null: false, default: 0
      add :idle_shutdown_after_ms, :bigint, null: false, default: 600_000
    end

    alter table(:sessions) do
      add :ttl_seconds, :integer
    end

    execute("""
    UPDATE sessions AS s
    SET ttl_seconds = p.ttl_seconds
    FROM session_pools AS p
    WHERE s.session_pool_id = p.id AND p.ttl_seconds IS NOT NULL
    """)

    execute("""
    UPDATE session_pools
    SET session_template =
      jsonb_set(
        COALESCE(session_template::jsonb, '{}'::jsonb),
        '{ttl_seconds}',
        to_jsonb(ttl_seconds)
      )
    WHERE ttl_seconds IS NOT NULL
    """)

    alter table(:session_pools) do
      remove :ttl_seconds
    end
  end

  def down do
    alter table(:session_pools) do
      add :ttl_seconds, :integer
    end

    execute("""
    UPDATE session_pools
    SET ttl_seconds = CAST(session_template->>'ttl_seconds' AS INTEGER)
    WHERE session_template ? 'ttl_seconds'
    """)

    alter table(:session_pools) do
      remove :idle_shutdown_after_ms
      remove :max_ready
    end

    rename table(:session_pools), :min_ready, to: :target_ready

    alter table(:sessions) do
      remove :ttl_seconds
    end

    execute("""
    UPDATE session_pools
    SET session_template = session_template::jsonb - 'ttl_seconds'
    WHERE session_template ? 'ttl_seconds'
    """)
  end
end
