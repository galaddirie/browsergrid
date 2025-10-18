defmodule BrowsergridWeb.PageController do
  use BrowsergridWeb, :controller

  def home(conn, _params) do
    layout =
      if conn.assigns[:current_user] do
        {BrowsergridWeb.Layouts, :app}
      else
        false
      end

    # The home page is often custom made,
    # so skip the default app layout.
    conn
    |> assign(:page_title, "Welcome to Browsergrid")
    |> render(:home, layout: layout)
  end

  def dashboard(conn, _params) do
    # Redirect to the new dashboard route
    redirect(conn, to: ~p"/dashboard")
  end
end
