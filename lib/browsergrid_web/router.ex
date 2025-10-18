defmodule BrowsergridWeb.Router do
  use BrowsergridWeb, :router

  import BrowsergridWeb.UserAuth

  alias Inertia.V1.DeploymentController
  alias Inertia.V1.ProfileController
  alias Inertia.V1.SessionController

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

  scope "/", BrowsergridWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  scope "/", BrowsergridWeb do
    pipe_through [:browser, :require_authenticated_user]

    # Dashboard
    get "/dashboard", Inertia.V1.DashboardController, :overview

    # Sessions routes
    get "/sessions", SessionController, :index
    post "/sessions", SessionController, :create
    get "/sessions/:id", SessionController, :show
    get "/sessions/:id/edit", SessionController, :edit
    put "/sessions/:id", SessionController, :update
    patch "/sessions/:id", SessionController, :update
    delete "/sessions/:id", SessionController, :delete

    # Profile routes
    get "/profiles", ProfileController, :index
    get "/profiles/new", ProfileController, :new
    post "/profiles", ProfileController, :create
    get "/profiles/:id", ProfileController, :show
    get "/profiles/:id/edit", ProfileController, :edit
    put "/profiles/:id", ProfileController, :update
    patch "/profiles/:id", ProfileController, :update
    delete "/profiles/:id", ProfileController, :delete
    post "/profiles/:id/archive", ProfileController, :archive
    get "/profiles/:id/download", ProfileController, :download
    post "/profiles/:id/upload", ProfileController, :upload
    post "/profiles/:id/restore/:snapshot_id", ProfileController, :restore_snapshot
    post "/profiles/:id/cleanup", ProfileController, :cleanup_snapshots

    # Deployment routes
    get "/deployments", DeploymentController, :index
    get "/deployments/new", DeploymentController, :new
    post "/deployments", DeploymentController, :create
    get "/deployments/:id", DeploymentController, :show
    post "/deployments/:id/deploy", DeploymentController, :deploy
    delete "/deployments/:id", DeploymentController, :delete
  end

  # API V1 Routes - Public
  scope "/api", BrowsergridWeb do
    pipe_through :api

    get "/health", HealthController, :health
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
    pipe_through [:browser, :require_authenticated_user]

    get "/users/settings", UserSettingsController, :edit
    put "/users/settings", UserSettingsController, :update
    get "/users/settings/confirm_email/:token", UserSettingsController, :confirm_email
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
