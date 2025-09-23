defmodule Browsergrid.Application do
  @moduledoc false

  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    base_children = [
      # Database and core infrastructure first
      Browsergrid.Repo,
      BrowsergridWeb.Telemetry,
      {Phoenix.PubSub, name: Browsergrid.PubSub},
      # Registry for internal process discovery (mux, etc.)
      {Registry, keys: :unique, name: Browsergrid.Registry},

      # Metrics and monitoring
      Browsergrid.Telemetry.Metrics,

      # Job processing and Redis pub/sub
      {Oban, Application.fetch_env!(:browsergrid, Oban)},
      Browsergrid.Redis,
      Browsergrid.Edge.Directory,
      # Web endpoint (should start last)
      BrowsergridWeb.Endpoint
    ]
    children = base_children

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Browsergrid.Supervisor]

    case Supervisor.start_link(children, opts) do
      {:ok, _pid} = success ->
        Logger.info("""

        ============================================
        Browsergrid Started Successfully
        ============================================
        Environment: #{Application.get_env(:browsergrid, :environment, :dev)}

        """)

        success

      {:error, reason} = error ->
        Logger.error("Browsergrid.Application failed to start: #{inspect(reason)}")
        error
    end
  end

  @impl true
  def config_change(changed, _new, removed) do
    BrowsergridWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
