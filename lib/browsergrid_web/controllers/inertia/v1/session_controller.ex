defmodule BrowsergridWeb.Inertia.V1.SessionController do
  use BrowsergridWeb, :controller

  alias Browsergrid.Sessions
  alias Browsergrid.Profiles
  alias Browsergrid.Repo

  require Logger

  # ===== List & Show =====

  def index(conn, _params) do
    sessions = Sessions.list_sessions() |> Repo.preload(:profile)
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
        session = Repo.preload(session, :profile)
        render_inertia(conn, "Sessions/Show", %{session: session})

      {:error, :not_found} ->
        conn
        |> put_flash(:error, "Session not found")
        |> redirect(to: ~p"/sessions")
    end
  end

  # ===== Create =====

  def create(conn, %{"session" => session_params}) do
    Logger.debug("Creating session with params: #{inspect(session_params)}")

    case Sessions.create_session(session_params) do
      {:ok, session} ->
        conn
        |> put_flash(:info, "Session created successfully")
        |> redirect(to: ~p"/sessions/#{session.id}")

      {:error, %Ecto.Changeset{} = changeset} ->
        Logger.error("Session creation failed with changeset errors: #{inspect(changeset.errors)}")

        sessions = Sessions.list_sessions() |> Repo.preload(:profile)
        profiles = Profiles.list_profiles(status: :active)

        conn
        |> put_flash(:error, "Failed to create session: #{format_errors(changeset)}")
        |> render_inertia("Sessions/Index", %{
          sessions: sessions,
          total: length(sessions),
          profiles: profiles,
          errors: format_changeset_errors(changeset)
        })

      {:error, reason} ->
        Logger.error("Session creation failed: #{inspect(reason)}")

        sessions = Sessions.list_sessions() |> Repo.preload(:profile)
        profiles = Profiles.list_profiles(status: :active)

        conn
        |> put_flash(:error, "Failed to create session: #{format_runtime_error(reason)}")
        |> render_inertia("Sessions/Index", %{
          sessions: sessions,
          total: length(sessions),
          profiles: profiles,
          errors: %{"base" => [format_runtime_error(reason)]}
        })
    end
  end

  # ===== Edit & Update =====

  def edit(conn, %{"id" => id}) do
    case Sessions.get_session(id) do
      {:ok, session} ->
        session = Repo.preload(session, :profile)
        render_inertia(conn, "Sessions/Edit", %{session: session})

      {:error, :not_found} ->
        conn
        |> put_flash(:error, "Session not found")
        |> redirect(to: ~p"/sessions")
    end
  end

  def update(conn, %{"id" => id, "session" => session_params}) do
    case Sessions.get_session(id) do
      {:ok, session} ->
        case Sessions.update_session(session, session_params) do
          {:ok, updated_session} ->
            conn
            |> put_flash(:info, "Session updated successfully")
            |> redirect(to: ~p"/sessions/#{updated_session.id}")

          {:error, changeset} ->
            conn
            |> put_flash(:error, "Failed to update session")
            |> render_inertia("Sessions/Edit", %{
              session: session,
              errors: format_changeset_errors(changeset)
            })
        end

      {:error, :not_found} ->
        conn
        |> put_flash(:error, "Session not found")
        |> redirect(to: ~p"/sessions")
    end
  end

  # ===== Delete =====

  def delete(conn, %{"id" => id}) do
    case Sessions.get_session(id) do
      {:ok, session} ->
        case Sessions.delete_session(session) do
          {:ok, _} ->
            conn
            |> put_flash(:info, "Session deleted successfully")
            |> redirect(to: ~p"/sessions")

          {:error, _reason} ->
            conn
            |> put_flash(:error, "Failed to delete session")
            |> redirect(to: ~p"/sessions")
        end

      {:error, :not_found} ->
        conn
        |> put_flash(:error, "Session not found")
        |> redirect(to: ~p"/sessions")
    end
  end

  # ===== Private Helpers =====

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end

  defp format_errors(changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(fn {msg, _opts} -> msg end)
    |> Enum.map(fn {field, errors} -> "#{field}: #{Enum.join(errors, ", ")}" end)
    |> Enum.join("; ")
  end

  defp format_runtime_error(reason) do
    case reason do
      {:browser_not_ready, inner} ->
        "Browser failed to become ready: #{inspect(inner)}"
      {:browser_start_failed, inner} ->
        "Browser failed to start: #{inspect(inner)}"
      {:profile_dir_failed, inner} ->
        "Profile directory setup failed: #{inspect(inner)}"
      other ->
        "Unexpected error: #{inspect(other)}"
    end
  end
end
