import Config

# Configure your database
db_url = System.get_env("BROWSERGRID_DATABASE_URL") || "postgres://postgres:postgres@localhost:5432/browsergrid_dev"

config :browsergrid, Browsergrid.Repo,
  url: db_url,
  stacktrace: true,
  show_sensitive_data_on_connection_error: true

config :browsergrid, Browsergrid.SessionRuntime,
  enabled: false,
  kubernetes: [
    enabled: false,
    conn: :auto,
    namespace: System.get_env("BROWSERGRID_K8S_NAMESPACE", "browsergrid-dev"),
    service_account: System.get_env("BROWSERGRID_K8S_SERVICE_ACCOUNT", "browsergrid-session")
  ]

config :browsergrid, Browsergrid.SessionPools.Manager,
  enabled: false

# For development, we disable any cache and enable
# debugging and code reloading.
#
# The watchers configuration can be used to run external
# watchers to your application. For example, we can use it
# to bundle .js and .css sources.
config :browsergrid, BrowsergridWeb.Endpoint,
  # Binding to loopback ipv4 address prevents access from other machines.
  # Change to `ip: {0, 0, 0, 0}` to allow access from other machines.
  http: [ip: {0, 0, 0, 0}, port: String.to_integer(System.get_env("PORT", "4000"))],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "r9X5M3idf8f6A+naqQrmRSIfHvpYUXzsNVsV8tukf/FcZqLayXZgI4BxG54UnB0q",
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:browsergrid, ~w(--sourcemap=inline --watch --log-level=warning)]},
    tailwind: {Tailwind, :install_and_run, [:browsergrid, ~w(--watch)]}
  ]

# Watch static and templates for browser reloading.
config :browsergrid, BrowsergridWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/(?!uploads/).*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"priv/gettext/.*(po)$",
      ~r"lib/browsergrid_web/(controllers|live|components)/.*(ex|heex)$",
      ~r"assets/js/.*(js|jsx|ts|tsx)$"
    ]
  ]

# Enable dev routes for dashboard and mailbox
config :browsergrid, dev_routes: true

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

config :phoenix_live_view,
  # Include HEEx debug annotations as HTML comments in rendered markup
  debug_heex_annotations: true,
  # Enable helpful, but potentially expensive runtime checks
  enable_expensive_runtime_checks: true

# Disable swoosh api client as it is only required for production adapters.
config :swoosh, :api_client, false
