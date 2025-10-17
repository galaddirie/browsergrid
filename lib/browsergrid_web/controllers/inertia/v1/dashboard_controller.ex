defmodule BrowsergridWeb.Inertia.V1.DashboardController do
  use BrowsergridWeb, :controller

  alias Browsergrid.Sessions

  def overview(conn, _params) do
    sessions = Sessions.list_sessions()

    stats = %{
      total_sessions: length(sessions),
      active_sessions: Enum.count(sessions, &(&1.status in ["running", "active", "claimed"])),
      available_sessions: Enum.count(sessions, &(&1.status == "available")),
      failed_sessions: Enum.count(sessions, &(&1.status in ["failed", "crashed"]))
    }

    render_inertia(conn, "Overview", %{
      stats: stats,
      sessions: Enum.take(sessions, 5)
    })
  end
end
