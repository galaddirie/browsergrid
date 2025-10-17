defmodule BrowsergridWeb.SessionChannel do
  @moduledoc """
  Phoenix channel for real-time session updates.
  Handles broadcasting session status changes and new sessions.
  """

  use Phoenix.Channel

  alias Browsergrid.Sessions

  @impl true
  def join("sessions", _payload, socket) do
    # Join the sessions channel - allow all users for now
    # In production, you might want to add authorization
    {:ok, socket}
  end

  @impl true
  def handle_in("get_sessions", _payload, socket) do
    sessions = Sessions.list_sessions()
    {:reply, {:ok, %{sessions: sessions}}, socket}
  end

  @impl true
  def handle_in("ping", payload, socket) do
    {:reply, {:ok, payload}, socket}
  end

  # Handle session status updates
  def broadcast_session_update(session) do
    BrowsergridWeb.Endpoint.broadcast(
      "sessions",
      "session_updated",
      %{session: session}
    )
  end

  # Handle new session creation
  def broadcast_session_created(session) do
    BrowsergridWeb.Endpoint.broadcast(
      "sessions",
      "session_created",
      %{session: session}
    )
  end

  # Handle session deletion
  def broadcast_session_deleted(session_id) do
    BrowsergridWeb.Endpoint.broadcast(
      "sessions",
      "session_deleted",
      %{session_id: session_id}
    )
  end
end
