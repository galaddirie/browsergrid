defmodule BrowsergridWeb.Layouts do
  @moduledoc """
  This module holds different layouts used by your application.

  See the `layouts` directory for all templates available.
  The "root" layout is a skeleton rendered as part of the
  application router. The "app" layout is set as the default
  layout on both `use BrowsergridWeb, :controller` and
  `use BrowsergridWeb, :live_view`.
  """
  use BrowsergridWeb, :html

  embed_templates "layouts/*"

  def current_page(socket) do
    case socket.view do
      BrowsergridWeb.DashboardLive.Index -> "/dashboard"
      BrowsergridWeb.SessionLive.Index -> "/sessions"
      BrowsergridWeb.SessionLive.Show -> "/sessions"
      BrowsergridWeb.ProfileLive -> "/profiles"
      BrowsergridWeb.DeploymentLive -> "/deployments"
      BrowsergridWeb.WebhookLive -> "/webhooks"
      _ -> nil
    end
  end
end
