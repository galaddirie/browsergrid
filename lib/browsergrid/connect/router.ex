defmodule Browsergrid.Connect.Router do
  @moduledoc false
  use Phoenix.Router

  pipeline :connect do
    plug :accepts, ["json"]
  end

  scope "/", BrowsergridWeb do
    pipe_through :connect

    get "/json", ConnectController, :index
    get "/json/version", ConnectController, :version
  end
end
