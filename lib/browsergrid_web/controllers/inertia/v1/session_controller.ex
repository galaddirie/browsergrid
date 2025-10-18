defmodule BrowsergridWeb.Inertia.V1.SessionController do
  use BrowsergridWeb, :controller

  alias Browsergrid.Profiles
  alias Browsergrid.Repo
  alias Browsergrid.Sessions

  require Logger

  def index(conn, _params) do
    user = conn.assigns.current_user
    sessions = Sessions.list_sessions(user_id: user.id, preload: true)
    profiles = Profiles.list_profiles(status: :active)

    render_inertia(conn, "Sessions/Index", %{
      sessions: sessions,
      total: length(sessions),
      profiles: profiles
    })
  end

  def show(conn, %{"id" => id}) do
    case Sessions.get_session(id) do
      {:ok, session} ->
        session = Repo.preload(session, profile: :user)
        render_inertia(conn, "Sessions/Show", %{session: session})

      {:error, _} ->
        conn
        |> put_flash(:error, "Session not found")
        |> redirect(to: ~p"/sessions")
    end
  end

  def create(conn, %{"session" => session_params}) do
    user = conn.assigns.current_user
    params = Map.put(session_params, "user_id", user.id)

    Logger.debug("Creating session: #{inspect(params)}")

    case Sessions.create_session(params) do
      {:ok, session} ->
        conn
        |> put_flash(:info, "Session created successfully")
        |> redirect(to: ~p"/sessions/#{session.id}")

      {:error, %Ecto.Changeset{} = changeset} ->
        handle_create_error(conn, changeset, "Validation failed")

      {:error, reason} ->
        handle_create_error(conn, nil, format_error(reason))
    end
  end

  def edit(conn, %{"id" => id}) do
    case Sessions.get_session(id) do
      {:ok, session} ->
        session = Repo.preload(session, profile: :user)
        render_inertia(conn, "Sessions/Edit", %{session: session})

      {:error, _} ->
        conn
        |> put_flash(:error, "Session not found")
        |> redirect(to: ~p"/sessions")
    end
  end

  def update(conn, %{"id" => id, "session" => params}) do
    with {:ok, session} <- Sessions.get_session(id),
         {:ok, updated} <- Sessions.update_session(session, params) do
      conn
      |> put_flash(:info, "Session updated successfully")
      |> redirect(to: ~p"/sessions/#{updated.id}")
    else
      {:error, :not_found} ->
        conn
        |> put_flash(:error, "Session not found")
        |> redirect(to: ~p"/sessions")

      {:error, changeset} ->
        {:ok, session} = Sessions.get_session(id)
        handle_update_error(conn, session, changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    with {:ok, session} <- Sessions.get_session(id),
         {:ok, _} <- Sessions.delete_session(session) do
      conn
      |> put_flash(:info, "Session deleted successfully")
      |> redirect(to: ~p"/sessions")
    else
      {:error, _} ->
        conn
        |> put_flash(:error, "Failed to delete session")
        |> redirect(to: ~p"/sessions")
    end
  end

  # ===== Private Helpers =====

  defp handle_create_error(conn, changeset, message) do
    Logger.error("Session creation failed: #{message}")

    sessions = Sessions.list_sessions(preload: true)
    profiles = Profiles.list_profiles(status: :active)

    conn
    |> put_flash(:error, "Failed to create session: #{message}")
    |> render_inertia("Sessions/Index", %{
      sessions: sessions,
      total: length(sessions),
      profiles: profiles,
      errors: format_changeset_errors(changeset)
    })
  end

  defp handle_update_error(conn, session, changeset) do
    conn
    |> put_flash(:error, "Failed to update session")
    |> render_inertia("Sessions/Edit", %{
      session: session,
      errors: format_changeset_errors(changeset)
    })
  end

  defp format_changeset_errors(nil), do: %{}

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end

  defp format_error({:browser_not_ready, reason}), do: "Browser not ready: #{inspect(reason)}"
  defp format_error({:browser_start_failed, reason}), do: "Browser start failed: #{inspect(reason)}"
  defp format_error({:profile_dir_failed, reason}), do: "Profile setup failed: #{inspect(reason)}"
  defp format_error(reason), do: "Unexpected error: #{inspect(reason)}"
end
