defmodule BrowsergridWeb.API.V1.ProfileController do
  use BrowsergridWeb, :controller

  alias Browsergrid.Profiles
  alias Browsergrid.Sessions

  action_fallback BrowsergridWeb.API.V1.FallbackController

  def index(conn, params) do
    filters = build_filters(params)
    profiles = Profiles.list_profiles(filters)
    total = length(profiles)

    meta = %{
      total_count: total,
      page_size: 20,
      current_page: 1,
      total_pages: div(total, 20) + if(rem(total, 20) > 0, do: 1, else: 0)
    }

    render(conn, :index, profiles: profiles, meta: meta)
  end

  def show(conn, %{"id" => id}) do
    case Profiles.get_profile_with_media!(id) do
      nil -> {:error, :not_found}
      profile -> render(conn, :show, profile: profile)
    end
  end

  def create(conn, %{"profile" => profile_params}) do
    case Profiles.create_profile(profile_params) do
      {:ok, profile} ->
        if Map.get(profile_params, "initialize", false) do
          {:ok, _} = Profiles.initialize_profile(profile)
        end

        conn
        |> put_status(:created)
        |> render(:create, profile: profile)

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def update(conn, %{"id" => id, "profile" => profile_params}) do
    with profile when not is_nil(profile) <- Profiles.get_profile(id),
         {:ok, updated_profile} <- Profiles.update_profile(profile, profile_params) do
      render(conn, :update, profile: updated_profile)
    else
      nil -> {:error, :not_found}
      error -> error
    end
  end

  def delete(conn, %{"id" => id}) do
    with profile when not is_nil(profile) <- Profiles.get_profile(id),
         false <- Sessions.profile_in_use?(id),
         {:ok, _} <- Profiles.delete_profile(profile) do
      send_resp(conn, :no_content, "")
    else
      nil -> {:error, :not_found}
      true ->
        conn
        |> put_status(:conflict)
        |> json(%{success: false, error: "Profile is currently in use by active sessions"})
    end
  end

  def archive(conn, %{"id" => id}) do
    with profile when not is_nil(profile) <- Profiles.get_profile(id),
         {:ok, archived_profile} <- Profiles.archive_profile(profile) do
      render(conn, :archive, profile: archived_profile)
    else
      nil -> {:error, :not_found}
      error -> error
    end
  end

  def download(conn, %{"id" => id}) do
    with profile when not is_nil(profile) <- Profiles.get_profile_with_media!(id),
         {:ok, zip_content} <- Profiles.download_profile_data(profile) do
      conn
      |> put_resp_content_type("application/zip")
      |> put_resp_header("content-disposition",
           "attachment; filename=\"profile_#{profile.name}_v#{profile.version}.zip\"")
      |> send_resp(200, zip_content)
    else
      nil -> {:error, :not_found}
      {:error, :no_profile_data} ->
        conn
        |> put_status(:not_found)
        |> json(%{success: false, error: "No profile data available"})
    end
  end

  def upload(conn, %{"id" => id, "profile_data" => %Plug.Upload{} = upload}) do
    with profile when not is_nil(profile) <- Profiles.get_profile(id),
         {:ok, content} <- File.read(upload.path),
         {:ok, updated_profile} <- Profiles.upload_profile_data(profile, content) do
      render(conn, :update, profile: updated_profile)
    else
      nil -> {:error, :not_found}
      error -> error
    end
  end

  def snapshots(conn, %{"id" => id}) do
    case Profiles.get_profile(id) do
      nil ->
        {:error, :not_found}

      profile ->
        snapshots = Profiles.list_profile_snapshots(profile)
        render(conn, :snapshots, snapshots: snapshots, total: length(snapshots))
    end
  end

  def restore_snapshot(conn, %{"id" => id, "snapshot_id" => snapshot_id}) do
    with profile when not is_nil(profile) <- Profiles.get_profile(id),
         snapshots <- Profiles.list_profile_snapshots(profile),
         snapshot when not is_nil(snapshot) <- Enum.find(snapshots, &(&1.id == snapshot_id)),
         {:ok, restored_profile} <- Profiles.restore_from_snapshot(profile, snapshot) do
      render(conn, :update, profile: restored_profile)
    else
      nil -> {:error, :not_found}
      error -> error
    end
  end

  def sessions(conn, %{"id" => id}) do
    case Profiles.get_profile(id) do
      nil ->
        {:error, :not_found}

      _profile ->
        sessions = Sessions.get_sessions_by_profile(id)
        render(conn, :sessions, sessions: sessions, total: length(sessions))
    end
  end

  def statistics(conn, params) do
    user_id = Map.get(params, "user_id")
    stats = Profiles.get_statistics(user_id)
    render(conn, :statistics, stats: stats)
  end


  # Private functions

  defp build_filters(params) do
    Enum.reduce(params, [], fn
      {"browser_type", value}, acc -> [{:browser_type, String.to_atom(value)} | acc]
      {"status", value}, acc -> [{:status, String.to_atom(value)} | acc]
      {"user_id", value}, acc -> [{:user_id, value} | acc]
      {"limit", value}, acc -> [{:limit, String.to_integer(value)} | acc]
      _, acc -> acc
    end)
  end
end
