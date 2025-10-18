defmodule BrowsergridWeb.API.V1.SessionController do
  use BrowsergridWeb, :controller

  alias Browsergrid.Sessions
  alias BrowsergridWeb.Controllers.API.Concerns.Authorization

  action_fallback BrowsergridWeb.API.V1.FallbackController

  def index(conn, _params) do
    user = conn.assigns.current_user
    sessions = Sessions.list_sessions(user_id: user.id)
    json(conn, %{data: sessions})
  end

  def show(conn, %{"id" => id}) do
    with {:ok, session} <- Sessions.get_session(id),
         {:ok, session} <- Authorization.authorize_resource(conn, session) do
      json(conn, %{data: session})
    else
      {:error, %Plug.Conn{} = conn} ->
        conn

      {:error, reason} ->
        {:error, reason}
    end
  end

  def create(conn, %{"session" => session_params}) do
    params = put_owner(session_params, conn)

    case Sessions.create_session(params) do
      {:ok, session} ->
        conn
        |> put_status(:created)
        |> json(%{data: session})

      {:error, %Ecto.Changeset{} = changeset} ->
        {:error, changeset}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def update(conn, %{"id" => id, "session" => session_params}) do
    with {:ok, session} <- Sessions.get_session(id),
         {:ok, session} <- Authorization.authorize_resource(conn, session),
         sanitized = ensure_owner(session_params, conn),
         {:ok, updated} <- Sessions.update_session(session, sanitized) do
      json(conn, %{data: updated})
    else
      {:error, %Plug.Conn{} = conn} ->
        conn

      {:error, reason} ->
        {:error, reason}
    end
  end

  def delete(conn, %{"id" => id}) do
    with {:ok, session} <- Sessions.get_session(id),
         {:ok, session} <- Authorization.authorize_resource(conn, session),
         {:ok, _deleted} <- Sessions.delete_session(session) do
      send_resp(conn, :no_content, "")
    else
      {:error, %Plug.Conn{} = conn} ->
        conn

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp put_owner(params, conn) do
    user_id = conn.assigns.current_user.id
    Map.put(params, "user_id", user_id)
  end

  defp ensure_owner(params, conn) do
    params
    |> Map.delete("user_id")
    |> Map.delete(:user_id)
    |> put_owner(conn)
  end
end
