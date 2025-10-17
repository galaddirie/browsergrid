defmodule BrowsergridWeb.Router do
  use BrowsergridWeb, :router

  import BrowsergridWeb.UserAuth

  alias BrowsergridWeb.Plugs.APIKeyAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {BrowsergridWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
    plug :assign_current_path
    plug Inertia.Plug
  end

  defp assign_current_path(conn, _opts) do
    assign(conn, :current_path, conn.request_path)
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug :fetch_session
    plug :put_secure_browser_headers
  end

  pipeline :api_authenticated do
    plug APIKeyAuth
  end

  pipeline :session_proxy do
    plug :accepts, ["json", "html"]
    plug :fetch_session
    plug :put_secure_browser_headers
    plug APIKeyAuth, rate_limit: false, track_usage: false
  end

  # Public routes (no authentication required)
  scope "/", BrowsergridWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  # Protected routes (authentication required)
  scope "/", BrowsergridWeb do
    pipe_through [:browser, :require_authenticated_user]

    # Dashboard
    get "/dashboard", Inertia.V1.DashboardController, :overview

    # Sessions routes
    get "/sessions", Inertia.V1.SessionController, :index
    post "/sessions", Inertia.V1.SessionController, :create
    get "/sessions/:id", Inertia.V1.SessionController, :show
    get "/sessions/:id/edit", Inertia.V1.SessionController, :edit
    put "/sessions/:id", Inertia.V1.SessionController, :update
    patch "/sessions/:id", Inertia.V1.SessionController, :update
    delete "/sessions/:id", Inertia.V1.SessionController, :delete

    # Profile routes
    get "/profiles", Inertia.V1.ProfileController, :index
    get "/profiles/new", Inertia.V1.ProfileController, :new
    post "/profiles", Inertia.V1.ProfileController, :create
    get "/profiles/:id", Inertia.V1.ProfileController, :show
    get "/profiles/:id/edit", Inertia.V1.ProfileController, :edit
    put "/profiles/:id", Inertia.V1.ProfileController, :update
    patch "/profiles/:id", Inertia.V1.ProfileController, :update
    delete "/profiles/:id", Inertia.V1.ProfileController, :delete
    post "/profiles/:id/archive", Inertia.V1.ProfileController, :archive
    get "/profiles/:id/download", Inertia.V1.ProfileController, :download
    post "/profiles/:id/upload", Inertia.V1.ProfileController, :upload
    post "/profiles/:id/restore/:snapshot_id", Inertia.V1.ProfileController, :restore_snapshot
    post "/profiles/:id/cleanup", Inertia.V1.ProfileController, :cleanup_snapshots

    # Deployment routes
    get "/deployments", Inertia.V1.DeploymentController, :index
    get "/deployments/new", Inertia.V1.DeploymentController, :new
    post "/deployments", Inertia.V1.DeploymentController, :create
    get "/deployments/:id", Inertia.V1.DeploymentController, :show
    post "/deployments/:id/deploy", Inertia.V1.DeploymentController, :deploy
    delete "/deployments/:id", Inertia.V1.DeploymentController, :delete

    # API Keys management UI
    get "/api-keys", Inertia.V1.ApiKeyController, :index
    post "/api-keys", Inertia.V1.ApiKeyController, :create
    post "/api-keys/:id/regenerate", Inertia.V1.ApiKeyController, :regenerate
    post "/api-keys/:id/revoke", Inertia.V1.ApiKeyController, :revoke
  end

  # API V1 Routes - Public
  scope "/api", BrowsergridWeb do
    pipe_through :api

    get "/health", HealthController, :health
  end

  # Health check endpoint
  get "/healthz", BrowsergridWeb.HealthController, :healthz

  scope "/sessions/:id", BrowsergridWeb do
    pipe_through :session_proxy

    match :*, "/edge/*path", SessionProxyController, :proxy
  end

  # API V1 Routes - Main API
  scope "/api/v1", BrowsergridWeb.API.V1 do
    pipe_through [:api, :api_authenticated]

    # Sessions
    resources "/sessions", SessionController, only: [:index, :show, :create, :delete]
    get "/sessions/:id/connection", SessionController, :connection
    get "/sessions/:id/route", SessionController, :route

    # Profiles
    resources "/profiles", ProfileController, except: [:new, :edit]
    post "/profiles/:id/archive", ProfileController, :archive
    get "/profiles/:id/download", ProfileController, :download
    post "/profiles/:id/upload", ProfileController, :upload
    get "/profiles/:id/snapshots", ProfileController, :snapshots
    post "/profiles/:id/restore/:snapshot_id", ProfileController, :restore_snapshot
    get "/profiles/:id/sessions", ProfileController, :sessions
    get "/profiles/statistics", ProfileController, :statistics

    # Deployments
    resources "/deployments", DeploymentController, except: [:new, :edit]
    post "/deployments/:id/deploy", DeploymentController, :deploy
    get "/deployments/statistics", DeploymentController, :statistics

    # API Keys
    resources "/api_keys", ApiKeyController, only: [:index, :show, :create]
    post "/api_keys/:id/regenerate", ApiKeyController, :regenerate
    post "/api_keys/:id/revoke", ApiKeyController, :revoke

    # Edge Debug
    get "/edge", EdgeDebugController, :index
    get "/edge/lookup/:session_id", EdgeDebugController, :lookup
    post "/edge/sync", EdgeDebugController, :sync_test

    # Flash Messages
    delete "/flash/:type", FlashController, :clear
    delete "/flash", FlashController, :clear_all
  end

  # Debug/Admin API Routes (if needed)
  scope "/api/debug", BrowsergridWeb do
    pipe_through [:api, :api_authenticated]
  end

  scope "/media", BrowsergridWeb do
    pipe_through :browser
    get "/*path", MediaController, :serve
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:browsergrid, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: BrowsergridWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", BrowsergridWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    get "/users/register", UserRegistrationController, :new
    post "/users/register", UserRegistrationController, :create
    get "/users/log_in", UserSessionController, :new
    post "/users/log_in", UserSessionController, :create
    get "/users/reset_password", UserResetPasswordController, :new
    post "/users/reset_password", UserResetPasswordController, :create
    get "/users/reset_password/:token", UserResetPasswordController, :edit
    put "/users/reset_password/:token", UserResetPasswordController, :update
  end

  scope "/", BrowsergridWeb do
    pipe_through [:browser, :require_authenticated_user]

    get "/users/settings", UserSettingsController, :edit
    put "/users/settings", UserSettingsController, :update
    get "/users/settings/confirm_email/:token", UserSettingsController, :confirm_email
  end

  scope "/", BrowsergridWeb do
    pipe_through [:browser]

    delete "/users/log_out", UserSessionController, :delete
    get "/users/confirm", UserConfirmationController, :new
    post "/users/confirm", UserConfirmationController, :create
    get "/users/confirm/:token", UserConfirmationController, :edit
    post "/users/confirm/:token", UserConfirmationController, :update
  end
end
