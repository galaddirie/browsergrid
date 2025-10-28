defmodule BrowsergridWeb.Inertia.V1.SessionController do
  use BrowsergridWeb, :controller

  alias Browsergrid.Profiles
  alias Browsergrid.Sessions

  require Logger

  plug :load_session when action in [:show, :edit, :update, :delete, :stop]

  def index(conn, _params) do
    user = conn.assigns.current_user
    sessions = Sessions.list_user_sessions(user, preload: [:profile, session_pool: :owner])
    profiles = Profiles.list_user_profiles(user, status: :active)

    render_inertia(conn, "Sessions/Index", %{
      sessions: sessions,
      total: length(sessions),
      profiles: profiles
    })
  end

  def show(%{assigns: %{session: session}} = conn, _params) do
    connection_info = case Sessions.get_connection_info(session.id) do
      {:ok, info} -> info
      {:error, _} -> nil
    end

    render_inertia(conn, "Sessions/Show", %{
      session: session,
      connection_info: connection_info
    })
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
        handle_create_error(conn, user, changeset, "Validation failed")

      {:error, reason} ->
        handle_create_error(conn, user, nil, format_error(reason))
    end
  end

  def edit(%{assigns: %{session: session}} = conn, _params) do
    render_inertia(conn, "Sessions/Edit", %{session: session})
  end

  def update(%{assigns: %{session: session}} = conn, %{"session" => params}) do
    user = conn.assigns.current_user

    if Sessions.user_owns_session?(user, session) do
      case Sessions.update_session(session, params) do
        {:ok, updated} ->
          refreshed = Sessions.fetch_user_session!(user, updated.id, preload: [:profile, session_pool: :owner])

          conn
          |> put_flash(:info, "Session updated successfully")
          |> redirect(to: ~p"/sessions/#{refreshed.id}")

        {:error, changeset} ->
          current = Sessions.fetch_user_session!(user, session.id, preload: [:profile, session_pool: :owner])
          handle_update_error(conn, current, changeset)
      end
    else
      render_not_found(conn)
    end
  end

  def stop(%{assigns: %{session: session}} = conn, _params) do
    user = conn.assigns.current_user

    if Sessions.user_owns_session?(user, session) do
      case Sessions.stop_session(session) do
        {:ok, _stopped} ->
          refreshed =
            Sessions.fetch_user_session!(
              user,
              session.id,
              preload: [:profile, :user, session_pool: :owner]
            )

          respond_stop_success(conn, refreshed)

        {:error, reason} ->
          respond_stop_error(conn, session, reason)
      end
    else
      render_not_found(conn)
    end
  end

  def delete(%{assigns: %{session: session}} = conn, _params) do
    user = conn.assigns.current_user

    if Sessions.user_owns_session?(user, session) do
      case Sessions.delete_session(session) do
        {:ok, _} ->
          conn
          |> put_flash(:info, "Session deleted successfully")
          |> redirect(to: ~p"/sessions")

        {:error, _} ->
          conn
          |> put_flash(:error, "Failed to delete session")
          |> redirect(to: ~p"/sessions")
      end
    else
      render_not_found(conn)
    end
  end

  # ===== Private Helpers =====

  defp handle_create_error(conn, user, changeset, message) do
    Logger.error("Session creation failed: #{message}")

    sessions = Sessions.list_user_sessions(user, preload: [:profile, session_pool: :owner])
    profiles = Profiles.list_user_profiles(user, status: :active)

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

  defp respond_stop_success(conn, session) do
    case get_format(conn) do
      "json" ->
        json(conn, %{data: session, message: "Session stopping"})

      _ ->
        conn
        |> put_flash(:info, "Session stopping")
        |> redirect(to: stop_redirect_path(conn, session))
    end
  end

  defp respond_stop_error(conn, session, reason) do
    message = "Failed to stop session: #{format_stop_error(reason)}"

    case get_format(conn) do
      "json" ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: message})

      _ ->
        conn
        |> put_flash(:error, message)
        |> redirect(to: stop_redirect_path(conn, session))
    end
  end

  defp stop_redirect_path(conn, session) do
    conn
    |> get_req_header("referer")
    |> case do
      [referer | _] ->
        referer
        |> URI.parse()
        |> case do
          %URI{path: path} when is_binary(path) and path != "" -> path
          _ -> ~p"/sessions/#{session.id}"
        end

      _ ->
        ~p"/sessions/#{session.id}"
    end
  end

  defp load_session(%{params: %{"id" => id}} = conn, _opts) do
    user = conn.assigns.current_user

    case Sessions.fetch_user_session(user, id, preload: [:profile, :user, session_pool: :owner]) do
      {:ok, session} -> assign(conn, :session, session)
      {:error, _} -> render_not_found(conn)
    end
  end

  defp load_session(conn, _opts), do: render_not_found(conn)

  defp render_not_found(conn) do
    conn
    |> put_status(:not_found)
    |> put_view(BrowsergridWeb.ErrorHTML)
    |> render("404", layout: false)
    |> halt()
  end

  defp format_changeset_errors(nil), do: %{}

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end

  defp format_stop_error({:error, reason}), do: format_stop_error(reason)

  defp format_stop_error(%Ecto.Changeset{} = changeset) do
    changeset
    |> format_changeset_errors()
    |> Enum.flat_map(fn {field, messages} ->
      messages
      |> List.wrap()
      |> Enum.map(&"#{field} #{&1}")
    end)
    |> Enum.join(", ")
  end

  defp format_stop_error(reason) when is_binary(reason), do: reason
  defp format_stop_error(reason) when is_atom(reason), do: Atom.to_string(reason)
  defp format_stop_error(reason), do: inspect(reason)

  defp format_error({:browser_not_ready, reason}), do: "Browser not ready: #{inspect(reason)}"
  defp format_error({:browser_start_failed, reason}), do: "Browser start failed: #{inspect(reason)}"
  defp format_error({:profile_dir_failed, reason}), do: "Profile setup failed: #{inspect(reason)}"
  defp format_error(reason), do: "Unexpected error: #{inspect(reason)}"
end
