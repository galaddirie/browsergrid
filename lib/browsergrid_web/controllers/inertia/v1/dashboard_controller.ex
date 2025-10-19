defmodule BrowsergridWeb.Inertia.V1.DashboardController do
  use BrowsergridWeb, :controller

  alias Browsergrid.Sessions

  def overview(conn, _params) do
    user = conn.assigns.current_user
    sessions = Sessions.list_user_sessions(user, preload: [:profile, session_pool: :owner])

    stats = %{
      total_sessions: length(sessions),
      active_sessions: Enum.count(sessions, &(&1.status in [:running, :claimed, :ready, :starting])),
      available_sessions: Enum.count(sessions, &(&1.status in [:pending, :ready])),
      failed_sessions: Enum.count(sessions, &(&1.status in [:error, :stopped]))
    }

    render_inertia(conn, "Overview", %{
      stats: stats,
      sessions: Enum.take(sessions, 5)
    })
  end
end
