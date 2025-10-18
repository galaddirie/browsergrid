defmodule BrowsergridWeb.Inertia.V1.ProfileController do
  use BrowsergridWeb, :controller

  alias Browsergrid.Profiles
  alias Browsergrid.Repo
  alias Browsergrid.Sessions

  def index(conn, _params) do
    profiles = Repo.preload(Profiles.list_profiles(), :user)
    stats = Profiles.get_statistics()

    render_inertia(conn, "Profiles/Index", %{
      profiles: profiles,
      total: length(profiles),
      stats: stats
    })
  end

  def show(conn, %{"id" => id}) do
    case Profiles.get_profile_with_media!(id) do
      nil ->
        conn
        |> put_flash(:error, "Profile not found")
        |> redirect(to: ~p"/profiles")

      profile ->
        sessions = Sessions.get_sessions_by_profile(id)
        snapshots = Profiles.list_profile_snapshots(profile, limit: 10)

        conn
        |> assign_prop(:profile, profile)
        |> assign_prop(:sessions, sessions)
        |> assign_prop(:snapshots, snapshots)
        |> render_inertia("Profiles/Show")
    end
  end

  def new(conn, _params) do
    render_inertia(conn, "Profiles/New")
  end

  def create(conn, %{"profile" => profile_params}) do
    case Profiles.create_profile(profile_params) do
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

  def edit(conn, %{"id" => id}) do
    case Profiles.get_profile(id) do
      nil ->
        conn
        |> put_flash(:error, "Profile not found")
        |> redirect(to: ~p"/profiles")

      profile ->
        conn
        |> assign_prop(:profile, profile)
        |> render_inertia("Profiles/Edit")
    end
  end

  def update(conn, %{"id" => id, "profile" => profile_params}) do
    case Profiles.get_profile(id) do
      nil ->
        conn
        |> put_flash(:error, "Profile not found")
        |> redirect(to: ~p"/profiles")

      profile ->
        case Profiles.update_profile(profile, profile_params) do
          {:ok, updated_profile} ->
            conn
            |> put_flash(:info, "Profile updated successfully")
            |> redirect(to: ~p"/profiles/#{updated_profile.id}")

          {:error, changeset} ->
            conn
            |> put_flash(:error, "Failed to update profile")
            |> assign_prop(:profile, profile)
            |> render_inertia("Profiles/Edit", %{
              errors: format_changeset_errors(changeset)
            })
        end
    end
  end

  def delete(conn, %{"id" => id}) do
    case Profiles.get_profile(id) do
      nil ->
        conn
        |> put_flash(:error, "Profile not found")
        |> redirect(to: ~p"/profiles")

      profile ->
        # Check if profile is in use
        if Sessions.profile_in_use?(id) do
          conn
          |> put_flash(:error, "Cannot delete profile while sessions are using it")
          |> redirect(to: ~p"/profiles/#{id}")
        else
          case Profiles.delete_profile(profile) do
            {:ok, _} ->
              conn
              |> put_flash(:info, "Profile deleted successfully")
              |> redirect(to: ~p"/profiles")

            {:error, _} ->
              conn
              |> put_flash(:error, "Failed to delete profile")
              |> redirect(to: ~p"/profiles/#{id}")
          end
        end
    end
  end

  def archive(conn, %{"id" => id}) do
    case Profiles.get_profile(id) do
      nil ->
        conn
        |> put_flash(:error, "Profile not found")
        |> redirect(to: ~p"/profiles")

      profile ->
        case Profiles.archive_profile(profile) do
          {:ok, _} ->
            conn
            |> put_flash(:info, "Profile archived successfully")
            |> redirect(to: ~p"/profiles")

          {:error, _} ->
            conn
            |> put_flash(:error, "Failed to archive profile")
            |> redirect(to: ~p"/profiles/#{id}")
        end
    end
  end

  def download(conn, %{"id" => id}) do
    case Profiles.get_profile_with_media!(id) do
      nil ->
        conn
        |> put_flash(:error, "Profile not found")
        |> redirect(to: ~p"/profiles")

      profile ->
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
            |> redirect(to: ~p"/profiles/#{id}")
        end
    end
  end

  def upload(conn, %{"id" => id, "profile_data" => upload}) do
    case Profiles.get_profile(id) do
      nil ->
        conn
        |> put_flash(:error, "Profile not found")
        |> redirect(to: ~p"/profiles")

      profile ->
        case handle_profile_upload(profile, upload) do
          {:ok, _updated_profile} ->
            conn
            |> put_flash(:info, "Profile data uploaded successfully")
            |> redirect(to: ~p"/profiles/#{id}")

          {:error, reason} ->
            conn
            |> put_flash(:error, "Failed to upload profile data: #{reason}")
            |> redirect(to: ~p"/profiles/#{id}")
        end
    end
  end

  def restore_snapshot(conn, %{"id" => id, "snapshot_id" => snapshot_id}) do
    with profile when not is_nil(profile) <- Profiles.get_profile(id),
         snapshots = Profiles.list_profile_snapshots(profile),
         snapshot when not is_nil(snapshot) <- Enum.find(snapshots, &(&1.id == snapshot_id)) do
      case Profiles.restore_from_snapshot(profile, snapshot) do
        {:ok, _} ->
          conn
          |> put_flash(:info, "Profile restored from snapshot successfully")
          |> redirect(to: ~p"/profiles/#{id}")

        {:error, _} ->
          conn
          |> put_flash(:error, "Failed to restore profile from snapshot")
          |> redirect(to: ~p"/profiles/#{id}")
      end
    else
      _ ->
        conn
        |> put_flash(:error, "Profile or snapshot not found")
        |> redirect(to: ~p"/profiles")
    end
  end

  def cleanup_snapshots(conn, %{"id" => id}) do
    case Profiles.get_profile(id) do
      nil ->
        conn
        |> put_flash(:error, "Profile not found")
        |> redirect(to: ~p"/profiles")

      profile ->
        case Profiles.cleanup_old_snapshots(profile, 5) do
          {:ok, count} ->
            conn
            |> put_flash(:info, "Cleaned up #{count} old snapshots")
            |> redirect(to: ~p"/profiles/#{id}")

          _ ->
            conn
            |> put_flash(:error, "Failed to cleanup snapshots")
            |> redirect(to: ~p"/profiles/#{id}")
        end
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

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
