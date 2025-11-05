defmodule Browsergrid.Application do
  @moduledoc false

  use Application

  alias Browsergrid.Accounts.AdminBootstrap

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

      # Job processing
      {Oban, Application.fetch_env!(:browsergrid, Oban)},
      {Finch, name: Browsergrid.Finch}
    ]

    # Conditionally add session runtime components
    session_runtime_enabled = Application.get_env(:browsergrid, Browsergrid.SessionRuntime)[:enabled] != false
    session_pools_enabled = Application.get_env(:browsergrid, Browsergrid.SessionPools.Manager)[:enabled] != false

    children = base_children

    children =
      if session_runtime_enabled do
        Logger.info("Starting session runtime components")
        [Browsergrid.SessionRuntime.Supervisor | children]
      else
        Logger.info("Session runtime disabled - skipping SessionRuntime.Supervisor")
        children
      end

    children =
      if session_pools_enabled do
        Logger.info("Starting session pools manager")
        [Browsergrid.SessionPools.Manager | children]
      else
        Logger.info("Session pools disabled - skipping SessionPools.Manager")
        children
      end

    # Web endpoint (should start last)
    children = [BrowsergridWeb.Endpoint | children]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Browsergrid.Supervisor]

    case Supervisor.start_link(children, opts) do
      {:ok, _pid} = success ->
        AdminBootstrap.ensure_admin_user!()

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
