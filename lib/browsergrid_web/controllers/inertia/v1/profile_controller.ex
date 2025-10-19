defmodule BrowsergridWeb.Inertia.V1.ProfileController do
  use BrowsergridWeb, :controller

  alias Browsergrid.Profiles
  alias Browsergrid.Sessions

  plug :load_profile
       when action in [
              :show,
              :edit,
              :update,
              :delete,
              :archive,
              :download,
              :upload,
              :restore_snapshot,
              :cleanup_snapshots
            ]

  def index(conn, _params) do
    user = conn.assigns.current_user
    profiles = Profiles.list_user_profiles(user, preload: [:user])
    stats = Profiles.get_statistics(user.id)

    render_inertia(conn, "Profiles/Index", %{
      profiles: profiles,
      total: length(profiles),
      stats: stats
    })
  end

  def show(%{assigns: %{profile: profile}} = conn, _params) do
    user = conn.assigns.current_user
    sessions = Sessions.list_user_sessions(user, profile_id: profile.id, preload: [:profile, session_pool: :owner])
    snapshots = Profiles.list_profile_snapshots(profile, limit: 10)

    conn
    |> assign_prop(:profile, profile)
    |> assign_prop(:sessions, sessions)
    |> assign_prop(:snapshots, snapshots)
    |> render_inertia("Profiles/Show")
  end

  def new(conn, _params) do
    render_inertia(conn, "Profiles/New")
  end

  def create(conn, %{"profile" => profile_params}) do
    user = conn.assigns.current_user
    params = Map.put(profile_params, "user_id", user.id)

    case Profiles.create_profile(params) do
      {:ok, profile} ->
        if Map.get(profile_params, "initialize", false) do
          {:ok, _} = Profiles.initialize_profile(profile)
        end

        conn
        |> put_flash(:info, "Profile created successfully")
        |> redirect(to: ~p"/profiles/#{profile.id}")

      {:error, changeset} ->
        conn
        |> put_flash(:error, "Failed to create profile")
        |> render_inertia("Profiles/New", %{
          errors: format_changeset_errors(changeset)
        })
    end
  end

  def edit(%{assigns: %{profile: profile}} = conn, _params) do
    if Profiles.user_owns_profile?(conn.assigns.current_user, profile) do
      conn
      |> assign_prop(:profile, profile)
      |> render_inertia("Profiles/Edit")
    else
      render_not_found(conn)
    end
  end

  def update(%{assigns: %{profile: profile}} = conn, %{"profile" => profile_params}) do
    user = conn.assigns.current_user

    if Profiles.user_owns_profile?(user, profile) do
      case Profiles.update_profile(profile, profile_params) do
        {:ok, updated_profile} ->
          conn
          |> put_flash(:info, "Profile updated successfully")
          |> redirect(to: ~p"/profiles/#{updated_profile.id}")

        {:error, changeset} ->
          refreshed = Profiles.fetch_user_profile!(user, profile.id, preload: [:user])

          conn
          |> put_flash(:error, "Failed to update profile")
          |> assign_prop(:profile, refreshed)
          |> render_inertia("Profiles/Edit", %{
            errors: format_changeset_errors(changeset)
          })
      end
    else
      render_not_found(conn)
    end
  end

  def delete(%{assigns: %{profile: profile}} = conn, _params) do
    user = conn.assigns.current_user

    if Profiles.user_owns_profile?(user, profile) do
      if Sessions.profile_in_use?(profile.id) do
        conn
        |> put_flash(:error, "Cannot delete profile while sessions are using it")
        |> redirect(to: ~p"/profiles/#{profile.id}")
      else
        case Profiles.delete_profile(profile) do
          {:ok, _} ->
            conn
            |> put_flash(:info, "Profile deleted successfully")
            |> redirect(to: ~p"/profiles")

          {:error, _} ->
            conn
            |> put_flash(:error, "Failed to delete profile")
            |> redirect(to: ~p"/profiles/#{profile.id}")
        end
      end
    else
      render_not_found(conn)
    end
  end

  def archive(%{assigns: %{profile: profile}} = conn, _params) do
    if Profiles.user_owns_profile?(conn.assigns.current_user, profile) do
      case Profiles.archive_profile(profile) do
        {:ok, _} ->
          conn
          |> put_flash(:info, "Profile archived successfully")
          |> redirect(to: ~p"/profiles")

        {:error, _} ->
          conn
          |> put_flash(:error, "Failed to archive profile")
          |> redirect(to: ~p"/profiles/#{profile.id}")
      end
    else
      render_not_found(conn)
    end
  end

  def download(%{assigns: %{profile: profile}} = conn, _params) do
    if Profiles.user_owns_profile?(conn.assigns.current_user, profile) do
      case Profiles.download_profile_data(profile) do
        {:ok, zip_content} ->
          conn
          |> put_resp_content_type("application/zip")
          |> put_resp_header(
            "content-disposition",
            "attachment; filename=\"profile_#{profile.name}_v#{profile.version}.zip\""
          )
          |> send_resp(200, zip_content)

        {:error, :no_profile_data} ->
          conn
          |> put_flash(:error, "No profile data available for download")
          |> redirect(to: ~p"/profiles/#{profile.id}")
      end
    else
      render_not_found(conn)
    end
  end

  def upload(%{assigns: %{profile: profile}} = conn, %{"profile_data" => upload}) do
    if Profiles.user_owns_profile?(conn.assigns.current_user, profile) do
      case handle_profile_upload(profile, upload) do
        {:ok, _updated_profile} ->
          conn
          |> put_flash(:info, "Profile data uploaded successfully")
          |> redirect(to: ~p"/profiles/#{profile.id}")

        {:error, reason} ->
          conn
          |> put_flash(:error, "Failed to upload profile data: #{reason}")
          |> redirect(to: ~p"/profiles/#{profile.id}")
      end
    else
      render_not_found(conn)
    end
  end

  def upload(conn, _params), do: render_not_found(conn)

  def restore_snapshot(%{assigns: %{profile: profile}} = conn, %{"snapshot_id" => snapshot_id}) do
    if Profiles.user_owns_profile?(conn.assigns.current_user, profile) do
      snapshots = Profiles.list_profile_snapshots(profile)

      case Enum.find(snapshots, &(&1.id == snapshot_id)) do
        nil ->
          render_not_found(conn)

        snapshot ->
          case Profiles.restore_from_snapshot(profile, snapshot) do
            {:ok, _} ->
              conn
              |> put_flash(:info, "Profile restored from snapshot successfully")
              |> redirect(to: ~p"/profiles/#{profile.id}")

            {:error, _} ->
              conn
              |> put_flash(:error, "Failed to restore profile from snapshot")
              |> redirect(to: ~p"/profiles/#{profile.id}")
          end
      end
    else
      render_not_found(conn)
    end
  end

  def cleanup_snapshots(%{assigns: %{profile: profile}} = conn, _params) do
    if Profiles.user_owns_profile?(conn.assigns.current_user, profile) do
      case Profiles.cleanup_old_snapshots(profile, 5) do
        {:ok, count} ->
          conn
          |> put_flash(:info, "Cleaned up #{count} old snapshots")
          |> redirect(to: ~p"/profiles/#{profile.id}")

        _ ->
          conn
          |> put_flash(:error, "Failed to cleanup snapshots")
          |> redirect(to: ~p"/profiles/#{profile.id}")
      end
    else
      render_not_found(conn)
    end
  end

  # Private functions

  defp handle_profile_upload(profile, %Plug.Upload{} = upload) do
    case File.read(upload.path) do
      {:ok, content} ->
        Profiles.upload_profile_data(profile, content)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp handle_profile_upload(_profile, _), do: {:error, :invalid_upload}

  defp load_profile(%{params: %{"id" => id}} = conn, _opts) do
    user = conn.assigns.current_user

    case Profiles.fetch_user_profile(user, id, preload: [:user, :media_file]) do
      {:ok, profile} -> assign(conn, :profile, profile)
      {:error, _} -> render_not_found(conn)
    end
  end

  defp load_profile(conn, _opts), do: conn

  defp render_not_found(conn) do
    conn
    |> put_status(:not_found)
    |> put_view(BrowsergridWeb.ErrorHTML)
    |> render("404", layout: false)
    |> halt()
  end

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
