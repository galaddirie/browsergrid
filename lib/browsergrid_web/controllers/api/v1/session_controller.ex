defmodule BrowsergridWeb.API.V1.SessionController do
  use BrowsergridWeb, :controller

  alias Browsergrid.Repo
  alias Browsergrid.Sessions

  action_fallback BrowsergridWeb.API.V1.FallbackController

  def index(conn, params) do
    sessions = Sessions.list_sessions(preload: true)
    page_size = String.to_integer(Map.get(params, "page_size", "20"))
    page = String.to_integer(Map.get(params, "page", "1"))

    meta = %{
      total_count: length(sessions),
      page_size: page_size,
      current_page: page,
      total_pages: ceil(length(sessions) / page_size)
    }

    render(conn, :index, sessions: sessions, meta: meta)
  end

  def show(conn, %{"id" => id}) do
    with {:ok, session} <- Sessions.get_session(id) do
      session = Repo.preload(session, :profile)
      render(conn, :show, session: session)
    end
  end

  def create(conn, params) do
    with {:ok, session} <- Sessions.create_session(params),
         {:ok, %{url: url}} <- Sessions.get_connection_info(session.id) do
      conn
      |> put_status(:created)
      |> render(:create, session: session, connection_url: url)
    end
  end

  def delete(conn, %{"id" => id}) do
    with {:ok, session} <- Sessions.get_session(id),
         {:ok, _stopped} <- Sessions.stop_session(session) do
      render(conn, :delete, session: session)
    end
  end

  def connection(conn, %{"id" => id}) do
    with {:ok, session} <- Sessions.get_session(id),
         {:ok, %{url: url}} <- Sessions.get_connection_info(id) do
      render(conn, :connection, session: session, url: url)
    end
  end
end
