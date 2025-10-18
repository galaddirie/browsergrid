import Config
import Dotenvy

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/browsergrid start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.

alias Browsergrid.Connect.Endpoint

if File.exists?(".env") do
  Dotenvy.source(".env")
end

if System.get_env("PHX_SERVER") do
  config :browsergrid, BrowsergridWeb.Endpoint, server: true
end

# Set node name and cookie for releases
node_name =
  System.get_env("NODE_NAME") ||
    "browsergrid@#{System.get_env("POD_IP", "127.0.0.1")}"

config :browsergrid, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

config :browsergrid,
  cluster_strategy: System.get_env("CLUSTER_STRATEGY", "gossip"),
  cluster_cookie: String.to_atom(System.get_env("CLUSTER_COOKIE", "browsergrid-secret-cookie"))

System.put_env("RELEASE_NODE", node_name)
System.put_env("RELEASE_COOKIE", System.get_env("CLUSTER_COOKIE", "browsergrid-secret-cookie"))

if config_env() == :prod do
  database_url =
    System.get_env("BROWSERGRID_DATABASE_URL") ||
      raise """
      environment variable BROWSERGRID_DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"
  port = String.to_integer(System.get_env("PORT") || "4000")

  config :browsergrid, Browsergrid.Repo,
    # ssl: true,
    url: database_url,
    socket_options: maybe_ipv6

  config :browsergrid, BrowsergridWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/bandit/Bandit.html#t:options/0
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :browsergrid, BrowsergridWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://hexdocs.pm/plug/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your config/prod.exs,
  # ensuring no data is ever sent via http, always redirecting to https:
  #
  #     config :browsergrid, BrowsergridWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.

  # ## Configuring the mailer
  #
  # In production you need to configure the mailer to use a different adapter.
  # Also, you may need to configure the Swoosh API client of your choice if you
  # are not using SMTP. Here is an example of the configuration:
  #
  #     config :browsergrid, Browsergrid.Mailer,
  #       adapter: Swoosh.Adapters.Mailgun,
  #       api_key: System.get_env("MAILGUN_API_KEY"),
  #       domain: System.get_env("MAILGUN_DOMAIN")
  #
  # For this example you need include a HTTP client required by Swoosh API client.
  # Swoosh supports Hackney and Finch out of the box:
  #
  #     config :swoosh, :api_client, Swoosh.ApiClient.Hackney
  #
  # See https://hexdocs.pm/swoosh/Swoosh.html#module-installation for details.
end

# Runtime overrides for Redis / Edge
redis_url =
  System.get_env("REDIS_URL") ||
    System.get_env("BROWSERGRID_REDIS_URL") ||
    case System.get_env("REDIS_ADDR") || System.get_env("BROWSERGRID_REDIS_ADDR") do
      nil -> nil
      addr -> "redis://" <> addr
    end

if redis_url do
  config :browsergrid, :redis,
    url: redis_url,
    route_channel: System.get_env("BROWSERGRID_ROUTE_CHANNEL") || System.get_env("ROUTE_CHANNEL", "route-updates")
end

edge_host = System.get_env("EDGE_HOST")

if edge_host do
  config :browsergrid, :edge,
    host: edge_host,
    scheme: System.get_env("EDGE_SCHEME", "wss")
end

connect_enabled =
  "CONNECT_ENABLED"
  |> System.get_env()
  |> case do
    nil -> nil
    value -> String.downcase(value) in ["1", "true", "yes"]
  end

connect_pool_size =
  "CONNECT_POOL_SIZE"
  |> System.get_env()
  |> case do
    nil ->
      nil

    value ->
      case Integer.parse(value) do
        {int, _} when int > 0 -> int
        _ -> nil
      end
  end

connect_claim_timeout =
  "CONNECT_CLAIM_TIMEOUT_MS"
  |> System.get_env()
  |> case do
    nil ->
      nil

    value ->
      case Integer.parse(value) do
        {int, _} when int > 0 -> int
        _ -> nil
      end
  end

connect_token = System.get_env("CONNECT_TOKEN")

connect_session_prefix = System.get_env("CONNECT_SESSION_PREFIX")

connect_browser_type =
  "CONNECT_BROWSER_TYPE"
  |> System.get_env()
  |> case do
    nil ->
      nil

    value ->
      value
      |> String.downcase()
      |> case do
        "chrome" -> :chrome
        "chromium" -> :chromium
        "firefox" -> :firefox
        _ -> nil
      end
  end

connect_routing_mode =
  "CONNECT_ROUTING_MODE"
  |> System.get_env()
  |> case do
    nil ->
      nil

    value ->
      value
      |> String.downcase()
      |> case do
        "subdomain" -> :subdomain
        "path" -> :path
        "both" -> :both
        _ -> nil
      end
  end

connect_path_prefix =
  "CONNECT_PATH_PREFIX"
  |> System.get_env()
  |> case do
    nil -> nil
    value -> if String.trim(value) == "", do: nil, else: value
  end

connect_host =
  "CONNECT_HOST"
  |> System.get_env()
  |> case do
    nil -> nil
    value -> if String.trim(value) == "", do: nil, else: value
  end

connect_config_updates = []

connect_config_updates =
  case connect_enabled do
    nil -> connect_config_updates
    value -> Keyword.put(connect_config_updates, :enabled, value)
  end

connect_config_updates =
  case connect_pool_size do
    nil -> connect_config_updates
    value -> Keyword.put(connect_config_updates, :pool_size, value)
  end

connect_config_updates =
  case connect_claim_timeout do
    nil -> connect_config_updates
    value -> Keyword.put(connect_config_updates, :claim_timeout_ms, value)
  end

connect_config_updates =
  case connect_token do
    nil -> connect_config_updates
    value -> Keyword.put(connect_config_updates, :token, value)
  end

connect_config_updates =
  case connect_session_prefix do
    nil -> connect_config_updates
    value -> Keyword.put(connect_config_updates, :session_prefix, value)
  end

connect_config_updates =
  case connect_browser_type do
    nil -> connect_config_updates
    value -> Keyword.put(connect_config_updates, :browser_type, value)
  end

connect_routing_updates = []

connect_routing_updates =
  case connect_routing_mode do
    nil -> connect_routing_updates
    value -> Keyword.put(connect_routing_updates, :mode, value)
  end

connect_routing_updates =
  case connect_host do
    nil -> connect_routing_updates
    value -> Keyword.put(connect_routing_updates, :host, value)
  end

connect_routing_updates =
  case connect_path_prefix do
    nil -> connect_routing_updates
    value -> Keyword.put(connect_routing_updates, :path_prefix, value)
  end

connect_config_updates =
  if connect_routing_updates == [] do
    connect_config_updates
  else
    Keyword.put(connect_config_updates, :routing, connect_routing_updates)
  end

if connect_config_updates != [] do
  current_connect_config = Application.get_env(:browsergrid, Browsergrid.Connect, [])
  config :browsergrid, Browsergrid.Connect, Keyword.merge(current_connect_config, connect_config_updates)
end

connect_endpoint_server =
  "CONNECT_ENDPOINT_SERVER"
  |> System.get_env()
  |> case do
    nil -> nil
    value -> String.downcase(value) in ["1", "true", "yes"]
  end

connect_endpoint_port =
  "CONNECT_ENDPOINT_PORT"
  |> System.get_env()
  |> case do
    nil ->
      nil

    value ->
      case Integer.parse(value) do
        {int, _} when int > 0 -> int
        _ -> nil
      end
  end

connect_endpoint_host =
  "CONNECT_ENDPOINT_HOST"
  |> System.get_env()
  |> case do
    nil -> nil
    value -> if String.trim(value) == "", do: nil, else: value
  end

connect_endpoint_http =
  case connect_endpoint_port do
    nil -> nil
    port -> [ip: {0, 0, 0, 0}, port: port]
  end

connect_endpoint_updates = []

connect_endpoint_updates =
  case connect_endpoint_server do
    nil -> connect_endpoint_updates
    value -> Keyword.put(connect_endpoint_updates, :server, value)
  end

connect_endpoint_updates =
  case connect_endpoint_host do
    nil -> connect_endpoint_updates
    value -> Keyword.put(connect_endpoint_updates, :url, host: value)
  end

connect_endpoint_updates =
  case connect_endpoint_http do
    nil -> connect_endpoint_updates
    value -> Keyword.put(connect_endpoint_updates, :http, value)
  end

if connect_endpoint_updates != [] do
  current = Application.get_env(:browsergrid, Endpoint, [])
  config :browsergrid, Endpoint, Keyword.merge(current, connect_endpoint_updates)
end

# storage config

storage_backend =
  case System.get_env("STORAGE_BACKEND") do
    "s3" -> Browsergrid.Storage.S3
    "gcs" -> Browsergrid.Storage.GCS
    _ -> Browsergrid.Storage.Local
  end

config :browsergrid, :storage,
  backend: storage_backend,
  local_path: System.get_env("STORAGE_PATH", "/var/lib/browsergrid/media"),
  s3_bucket: System.get_env("S3_BUCKET"),
  region: System.get_env("AWS_REGION", "us-east-1"),
  cdn_url: System.get_env("CDN_URL"),
  base_url: System.get_env("MEDIA_BASE_URL", "http://localhost:4000")
