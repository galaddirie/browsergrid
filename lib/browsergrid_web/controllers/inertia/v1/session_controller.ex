defmodule BrowsergridWeb.Inertia.V1.SessionController do
  use BrowsergridWeb, :controller
  alias Browsergrid.Sessions
  alias Browsergrid.Profiles
  alias Browsergrid.Repo

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
        render_inertia(conn, "Sessions/Show", %{
          session: session
        })
      {:error, :not_found} ->
        redirect(conn, to: ~p"/sessions")
    end
  end


  def create(conn, %{"session" => session_params}) do
    # Transform browser parameter to browser_type for the schema
    transformed_params = transform_session_params(session_params)

    case Sessions.create_session(transformed_params) do
      {:ok, session} ->
        conn
        |> put_flash(:info, "Session created successfully")
        |> redirect(to: ~p"/sessions/#{session.id}")

      {:error, changeset} ->
        conn
        |> put_flash(:error, "Failed to create session")
        |> render_inertia("Sessions/Index", %{
          errors: format_changeset_errors(changeset)
        })
    end
  end

  def edit(conn, %{"id" => id}) do
    case Sessions.get_session(id) do
      {:ok, session} ->
        session = Repo.preload(session, :profile)
        render_inertia(conn, "Sessions/Edit", %{
          session: session
        })
      {:error, :not_found} ->
        redirect(conn, to: ~p"/sessions")
    end
  end

  def update(conn, %{"id" => id, "session" => session_params}) do
    # Transform browser parameter to browser_type for the schema
    transformed_params = transform_session_params(session_params)

    case Sessions.get_session(id) do
      {:ok, existing_session} ->
        case Sessions.update_session(existing_session, transformed_params) do
          {:ok, session} ->
            conn
            |> put_flash(:info, "Session updated successfully")
            |> redirect(to: ~p"/sessions/#{session.id}")

          {:error, changeset} ->
            conn
            |> put_flash(:error, "Failed to update session")
            |> render_inertia("Sessions/Edit", %{
              session: existing_session,
              errors: format_changeset_errors(changeset)
            })
        end

      {:error, :not_found} ->
        redirect(conn, to: ~p"/sessions")
    end
  end

  def delete(conn, %{"id" => id}) do
    case Sessions.get_session(id) do
      {:ok, session} ->
        case Sessions.delete_session(session) do
          {:ok, _deleted_session} ->
            conn
            |> put_flash(:info, "Session deleted successfully")
            |> redirect(to: ~p"/sessions")

          {:error, _changeset} ->
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

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end

  defp transform_session_params(params) do
    params
    |> Map.new(fn {key, value} ->
      case key do
        "browser" -> {"browser_type", String.to_atom(value)}
        _ -> {key, value}
      end
    end)
  end

end
