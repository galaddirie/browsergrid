defmodule BrowsergridWeb.API.V1.SessionController do
  use BrowsergridWeb, :controller

  alias Browsergrid.Sessions

  action_fallback BrowsergridWeb.API.V1.FallbackController

  def index(conn, _params) do
    user = conn.assigns.current_user
    sessions = Sessions.list_user_sessions(user)
    json(conn, %{data: sessions})
  end

  def show(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    case Sessions.fetch_user_session(user, id) do
      {:ok, session} -> json(conn, %{data: session})
      {:error, _reason} -> {:error, :not_found}
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
    user = conn.assigns.current_user

    sanitized = ensure_owner(session_params, conn)

    with {:ok, session} <- Sessions.fetch_user_session(user, id),
         {:ok, updated} <- Sessions.update_session(session, sanitized) do
      json(conn, %{data: updated})
    else
      {:error, _reason} ->
        {:error, :not_found}
    end
  end

  def delete(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    with {:ok, session} <- Sessions.fetch_user_session(user, id),
         {:ok, _deleted} <- Sessions.delete_session(session) do
      send_resp(conn, :no_content, "")
    else
      {:error, _reason} ->
        {:error, :not_found}
    end
  end

  def stop(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    case Sessions.fetch_user_session(user, id) do
      {:ok, session} ->
        case Sessions.stop_session(session) do
          {:ok, _stopped} ->
            refreshed = Sessions.fetch_user_session!(user, session.id)
            json(conn, %{data: refreshed, message: "Session stopping"})

          {:error, reason} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{error: "Failed to stop session", reason: inspect(reason)})
        end

      {:error, _reason} ->
        {:error, :not_found}
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
