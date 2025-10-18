import Config

# Only in tests, remove the complexity from the password hashing algorithm
config :bcrypt_elixir, :log_rounds, 1

config :browsergrid, Browsergrid.Connect,
  token: "test-token",
  pool_size: 1,
  claim_timeout_ms: 1_000,
  routing: [
    mode: :path,
    path_prefix: "/connect",
    host: nil
  ]

# In test we don't send emails
config :browsergrid, Browsergrid.Mailer, adapter: Swoosh.Adapters.Test

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :browsergrid, Browsergrid.Repo,
  url:
    System.get_env(
      "BROWSERGRID_DATABASE_URL",
      "postgres://postgres:postgres@localhost:5432/browsergrid_test#{System.get_env("MIX_TEST_PARTITION")}"
    ),
  pool: Ecto.Adapters.SQL.Sandbox

config :browsergrid, Browsergrid.SessionRuntime,
  checkpoint_interval_ms: 200,
  state_store: [
    adapter: Browsergrid.SessionRuntime.StateStore.DeltaCrdt,
    sync_interval_ms: 200,
    ttl_ms: to_timeout(minute: 5)
  ],
  browser: [mode: :stub],
  kubernetes: [enabled: false]

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :browsergrid, BrowsergridWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "OZkIY6rZLw1Xto05fuelGhaBOeLS8ZSb6zJYunwkHyOatyMfzdPK4WHjIrpgV0fQ",
  server: false

config :browsergrid, Oban,
  repo: Browsergrid.Repo,
  plugins: false,
  queues: false

# Point Redis to a local URL; tests mock publish calls and don't require a server
config :browsergrid, :redis,
  url: "redis://localhost:6379",
  route_channel: "route-updates-test"

# Use system temp directory for session profiles in tests
config :browsergrid, :session_profiles_path, System.tmp_dir!()

# Test storage configuration
config :browsergrid, :storage,
  backend: Browsergrid.Storage.Local,
  local_path: "/tmp/browsergrid-test-media",
  base_url: "http://localhost:4002"

config :logger, level: :critical

# Oban testing: disable plugins/queues; assert enqueues manually
config :oban, testing: :manual

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false
