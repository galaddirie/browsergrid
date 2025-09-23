defmodule BrowsergridWeb.API.V1.SessionController do
  use BrowsergridWeb, :controller

  alias Browsergrid.Sessions
  alias Browsergrid.Repo

  action_fallback BrowsergridWeb.API.V1.FallbackController

  def index(conn, _params) do
    sessions = Sessions.list_sessions()
    total = length(sessions)

    # Add pagination if needed
    meta = %{
      total_count: total,
      page_size: 20,
      current_page: 1,
      total_pages: div(total, 20) + if(rem(total, 20) > 0, do: 1, else: 0)
    }

    render(conn, :index, sessions: sessions, meta: meta)
  end

  def show(conn, %{"id" => id}) do
    case Sessions.get_session(id) do
      {:ok, session} ->
        session = Repo.preload(session, :profile)
        render(conn, :show, session: session)

      {:error, :not_found} ->
        {:error, :not_found}
    end
  end

  def create(conn, params) do
    case Sessions.create_session(params) do
      {:ok, session} ->
        {:ok, %{url: url}} = Sessions.get_connection_info(session.id)

        conn
        |> put_status(:created)
        |> render(:create, session: session, connection_url: url)

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def delete(conn, %{"id" => id}) do
    with {:ok, session} <- Sessions.get_session(id),
         {:ok, _job} <- Sessions.stop_session(session) do
      render(conn, :delete, session: session)
    end
  end

  def connection(conn, %{"id" => id}) do
    with {:ok, session} <- Sessions.get_session(id),
         {:ok, %{url: url}} <- Sessions.get_connection_info(id) do
      render(conn, :connection, session: session, url: url)
    end
  end

  def route(conn, %{"id" => id}) do
    case Browsergrid.Routing.get_route(id) do
      nil ->
        {:error, :not_found}

      %{ip: ip, port: port} ->
        # Mock session for consistency
        session = %{id: id}
        render(conn, :route, session: session, ip: ip, port: port)
    end
  end
end
