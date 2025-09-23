import Config

# In test we don't send emails
config :browsergrid, Browsergrid.Mailer, adapter: Swoosh.Adapters.Test

# Oban testing: disable plugins/queues; assert enqueues manually
config :oban, testing: :manual

config :browsergrid, Oban,
  repo: Browsergrid.Repo,
  plugins: false,
  queues: false

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :browsergrid, Browsergrid.Repo,
  username: System.get_env("BROWSERGRID_POSTGRES_USER", "postgres"),
  password: System.get_env("BROWSERGRID_POSTGRES_PASSWORD", "postgres"),
  hostname: System.get_env("BROWSERGRID_POSTGRES_HOST", "postgres"),
  database: System.get_env("BROWSERGRID_POSTGRES_DB", "browsergrid_test#{System.get_env("MIX_TEST_PARTITION")}"),
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :browsergrid, BrowsergridWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "OZkIY6rZLw1Xto05fuelGhaBOeLS8ZSb6zJYunwkHyOatyMfzdPK4WHjIrpgV0fQ",
  server: false

config :logger, level: :critical

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false



# Point Redis to a local URL; tests mock publish calls and don't require a server
config :browsergrid, :redis,
  url: "redis://localhost:6379",
  route_channel: "route-updates-test"

# Test storage configuration
config :browsergrid, :storage,
  backend: Browsergrid.Storage.Local,
  local_path: "/tmp/browsergrid-test-media",
  base_url: "http://localhost:4002"
