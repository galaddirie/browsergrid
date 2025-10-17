# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

# Authentication provider configuration
config :browsergrid,
  auth_provider: Browsergrid.Auth.PhoenixProvider

config :browsergrid, Browsergrid.ApiKeys.RateLimiter,
  limit: 120,
  interval_ms: 60_000

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :browsergrid, Browsergrid.Mailer, adapter: Swoosh.Adapters.Local

# Configure repo for UUID primary keys, foreign keys, and microsecond timestamps
config :browsergrid, Browsergrid.Repo,
  migration_primary_key: [type: :binary_id],
  migration_foreign_key: [type: :binary_id],
  migration_timestamps: [type: :utc_datetime_usec]

config :browsergrid, Browsergrid.SessionRuntime,
  checkpoint_interval_ms: 2_000,
  state_store: [
    adapter: Browsergrid.SessionRuntime.StateStore.DeltaCrdt,
    sync_interval_ms: 3_000,
    ttl_ms: to_timeout(minute: 30)
  ],
  browser: [
    mode: :kubernetes,
    http_port:
      "BROWSERGRID_BROWSER_HTTP_PORT"
      |> System.get_env()
      |> case do
        nil ->
          80

        value ->
          case Integer.parse(value) do
            {int, _} -> int
            :error -> 80
          end
      end,
    ready_path: System.get_env("BROWSERGRID_BROWSER_HEALTH_PATH") || "/health",
    ready_timeout_ms:
      "BROWSERGRID_BROWSER_READY_TIMEOUT_MS"
      |> System.get_env()
      |> case do
        nil ->
          120_000

        value ->
          case Integer.parse(value) do
            {int, _} -> int
            :error -> 120_000
          end
      end,
    ready_poll_interval_ms:
      "BROWSERGRID_BROWSER_READY_POLL_MS"
      |> System.get_env()
      |> case do
        nil ->
          1_000

        value ->
          case Integer.parse(value) do
            {int, _} -> int
            :error -> 1_000
          end
      end
  ],
  kubernetes: [
    enabled:
      "BROWSERGRID_ENABLE_KUBERNETES"
      |> System.get_env()
      |> case do
        nil -> true
        value -> String.downcase(value) in ["1", "true", "yes"]
      end,
    namespace: System.get_env("BROWSERGRID_K8S_NAMESPACE") || "browsergrid",
    cluster_name: System.get_env("BROWSERGRID_K8S_CLUSTER", "default"),
    service_account: System.get_env("BROWSERGRID_K8S_SERVICE_ACCOUNT"),
    image_repository: System.get_env("BROWSERGRID_BROWSER_IMAGE_REPO") || "browsergrid",
    image_tag: System.get_env("BROWSERGRID_BROWSER_IMAGE_TAG") || "latest",
    image_overrides: %{},
    request_cpu: System.get_env("BROWSERGRID_BROWSER_CPU_REQUEST", "200m"),
    request_memory: System.get_env("BROWSERGRID_BROWSER_MEMORY_REQUEST", "512Mi"),
    limit_cpu: System.get_env("BROWSERGRID_BROWSER_CPU_LIMIT", "1"),
    limit_memory: System.get_env("BROWSERGRID_BROWSER_MEMORY_LIMIT", "2Gi"),
    profile_volume_claim: System.get_env("BROWSERGRID_PROFILE_PVC"),
    profile_volume_sub_path_prefix: System.get_env("BROWSERGRID_PROFILE_SUBPATH_PREFIX", "sessions"),
    profile_volume_mount_path: System.get_env("BROWSERGRID_PROFILE_MOUNT_PATH") || "/home/user/data-dir",
    extra_env: [
      {"REMOTE_DEBUGGING_PORT", System.get_env("BROWSERGRID_REMOTE_DEBUG_PORT", "61000")},
      {"PORT", System.get_env("BROWSERGRID_BROWSERMUX_PORT", "8080")},
    ]
  ]

# Configures the endpoint
config :browsergrid, BrowsergridWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: BrowsergridWeb.ErrorHTML, json: BrowsergridWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Browsergrid.PubSub,
  live_view: [signing_salt: "he8We+Ar"]

# Job processing (Oban)
config :browsergrid, Oban,
  repo: Browsergrid.Repo,
  plugins: [
    Oban.Plugins.Pruner,
    {Oban.Plugins.Cron, []}
  ],
  queues: [
    default: 10,
    provision: 5,
    cleanup: 5,
    # New queue for profile extraction
    profile_extraction: 3
  ]

# Profile management settings
config :browsergrid, :profiles,
  max_snapshots_per_profile: 10,
  auto_cleanup_old_snapshots: true,
  max_profile_size_mb: 500,
  allowed_browser_types: [:chrome, :chromium, :firefox]

# Redis (pub/sub for route fanout)
config :browsergrid, :redis,
  url: "redis://localhost:6379",
  route_channel: "route-updates"

config :browsergrid,
       :session_profiles_path,
       System.get_env("BROWSERGRID_SESSION_PROFILES_PATH", "/var/lib/browsergrid/profiles")

config :browsergrid, :storage,
  backend: Browsergrid.Storage.Local,
  local_path: "/var/lib/browsergrid/media",
  base_url: "http://localhost:4000"

config :browsergrid,
  ecto_repos: [Browsergrid.Repo],
  generators: [timestamp_type: :utc_datetime_usec, binary_id: true]

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.21.5",
  browsergrid: [
    args: ~w(js/app.tsx --bundle --target=es2020 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

config :inertia,
  # The Phoenix Endpoint module for your application. This is used for building
  # asset URLs to compute a unique version hash to track when something has
  # changed (and a reload is required on the frontend).
  endpoint: BrowsergridWeb.Endpoint,

  # An optional list of static file paths to track for changes. You'll generally
  # want to include any JavaScript assets that may require a page refresh when
  # modified.
  static_paths: ["/assets/app.js"],

  # The default version string to use (if you decide not to track any static
  # assets using the `static_paths` config). Defaults to "1".
  default_version: "1",

  # Enable automatic conversion of prop keys from snake case (e.g. `inserted_at`),
  # which is conventional in Elixir, to camel case (e.g. `insertedAt`), which is
  # conventional in JavaScript. Defaults to `false`.
  # config/config.exs

  camelize_props: false,

  # Instruct the client side whether to encrypt the page object in the window history
  # state. This can also be set/overridden on a per-request basis, using the `encrypt_history`
  # controller helper. Defaults to `false`.
  history: [encrypt: false],

  # Enable server-side rendering for page responses (requires some additional setup,
  # see instructions below). Defaults to `false`.
  ssr: false,

  # Whether to raise an exception when server-side rendering fails (only applies
  # when SSR is enabled). Defaults to `true`.
  #
  # Recommended: enable in non-production environments and disable in production,
  # so that SSR failures will not cause 500 errors (but instead will fallback to
  # CSR).
  raise_on_ssr_failure: config_env() != :prod

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.4.3",
  browsergrid: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    # Import environment specific config. This must remain at the bottom
    # of this file so it overrides the configuration defined above.
    cd: Path.expand("../assets", __DIR__)
  ]

import_config "#{config_env()}.exs"
