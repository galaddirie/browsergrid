defmodule BrowsergridWeb.Router do
  use BrowsergridWeb, :router

  import BrowsergridWeb.UserAuth

  alias Inertia.V1.AccountSettingsController
  alias Inertia.V1.ApiTokenController

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
    plug :accepts, ["json"]
    plug BrowsergridWeb.Plugs.ApiAuth
  end

  scope "/", BrowsergridWeb do
    pipe_through [:browser, :require_authenticated_user]

    get "/", Inertia.V1.DashboardController, :overview

    get "/sessions", Inertia.V1.SessionController, :index
    post "/sessions", Inertia.V1.SessionController, :create
    get "/sessions/:id", Inertia.V1.SessionController, :show
    get "/sessions/:id/edit", Inertia.V1.SessionController, :edit
    put "/sessions/:id", Inertia.V1.SessionController, :update
    patch "/sessions/:id", Inertia.V1.SessionController, :update
    delete "/sessions/:id", Inertia.V1.SessionController, :delete

    # Session proxy routes - handles CDP connections and WebSocket proxying
    match :*, "/sessions/:id/connect/*path", SessionProxyController, :proxy

    # Session pool routes
    get "/pools", Inertia.V1.SessionPoolController, :index
    get "/pools/new", Inertia.V1.SessionPoolController, :new
    post "/pools", Inertia.V1.SessionPoolController, :create
    get "/pools/:id", Inertia.V1.SessionPoolController, :show
    get "/pools/:id/edit", Inertia.V1.SessionPoolController, :show
    put "/pools/:id", Inertia.V1.SessionPoolController, :update
    patch "/pools/:id", Inertia.V1.SessionPoolController, :update
    delete "/pools/:id", Inertia.V1.SessionPoolController, :delete
    post "/pools/:id/claim", Inertia.V1.SessionPoolController, :claim

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

    scope "/settings" do
      get "/account", AccountSettingsController, :edit
      put "/account/email", AccountSettingsController, :update_email
      patch "/account/email", AccountSettingsController, :update_email
      put "/account/password", AccountSettingsController, :update_password
      patch "/account/password", AccountSettingsController, :update_password
      get "/account/confirm-email/:token", AccountSettingsController, :confirm_email

      get "/api", ApiTokenController, :index
      post "/api", ApiTokenController, :create
      delete "/api/:id", ApiTokenController, :delete
    end
  end

  # API V1 Routes - Public
  scope "/api", BrowsergridWeb do
    pipe_through :api

    get "/health", HealthController, :health
  end

  # API V1 Routes - Authenticated
  scope "/api/v1", BrowsergridWeb.API.V1, as: :api_v1 do
    pipe_through :api_authenticated

    # Session routes
    get "/sessions", SessionController, :index
    post "/sessions", SessionController, :create
    get "/sessions/:id", SessionController, :show
    put "/sessions/:id", SessionController, :update
    delete "/sessions/:id", SessionController, :delete

    # Session proxy routes - handles CDP connections and WebSocket proxying
    match :*, "/sessions/:id/connect/*path", BrowsergridWeb.SessionProxyController, :proxy

    # Profile routes
    get "/profiles", ProfileController, :index
    post "/profiles", ProfileController, :create
    get "/profiles/:id", ProfileController, :show
    put "/profiles/:id", ProfileController, :update
    delete "/profiles/:id", ProfileController, :delete

    # Deployment routes
    get "/deployments", DeploymentController, :index
    post "/deployments", DeploymentController, :create
    get "/deployments/:id", DeploymentController, :show
    post "/deployments/:id/deploy", DeploymentController, :deploy
    delete "/deployments/:id", DeploymentController, :delete

    # Session pools
    get "/pools", SessionPoolController, :index
    get "/pools/:id/stats", SessionPoolController, :stats
    post "/pools", SessionPoolController, :create
    put "/pools/:id", SessionPoolController, :update
    delete "/pools/:id", SessionPoolController, :delete
    post "/pools/:id/claim", SessionPoolController, :claim
  end

  # Health check endpoint
  get "/healthz", BrowsergridWeb.HealthController, :healthz

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

    get "/users/log_in", UserSessionController, :new
    post "/users/log_in", UserSessionController, :create
    get "/users/reset_password", UserResetPasswordController, :new
    post "/users/reset_password", UserResetPasswordController, :create
    get "/users/reset_password/:token", UserResetPasswordController, :edit
    put "/users/reset_password/:token", UserResetPasswordController, :update
  end

  scope "/", BrowsergridWeb do
    pipe_through [:browser]

    get "/users/log_out", UserSessionController, :delete
    delete "/users/log_out", UserSessionController, :delete
    get "/users/confirm", UserConfirmationController, :new
    post "/users/confirm", UserConfirmationController, :create
    get "/users/confirm/:token", UserConfirmationController, :edit
    post "/users/confirm/:token", UserConfirmationController, :update
  end
end
