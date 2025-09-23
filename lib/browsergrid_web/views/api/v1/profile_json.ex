defmodule BrowsergridWeb.API.V1.ProfileJSON do
  alias Browsergrid.Profiles.Profile

  def index(%{profiles: profiles, meta: meta}) do
    %{
      success: true,
      data: for(profile <- profiles, do: data(profile)),
      meta: serialize_meta(meta)
    }
  end

  def show(%{profile: profile}) do
    %{
      success: true,
      data: data_detailed(profile)
    }
  end

  def create(%{profile: profile}) do
    %{
      success: true,
      data: data_detailed(profile),
      message: "Profile created successfully"
    }
  end

  def update(%{profile: profile}) do
    %{
      success: true,
      data: data_detailed(profile),
      message: "Profile updated successfully"
    }
  end

  def delete(_assigns) do
    %{
      success: true,
      message: "Profile deleted successfully"
    }
  end

  def archive(%{profile: profile}) do
    %{
      success: true,
      data: data(profile),
      message: "Profile archived successfully"
    }
  end

  def snapshots(%{snapshots: snapshots, total: total}) do
    %{
      success: true,
      data: for(snapshot <- snapshots, do: serialize_snapshot(snapshot)),
      meta: %{total: total}
    }
  end

  def statistics(%{stats: stats}) do
    %{
      success: true,
      data: stats
    }
  end

  def sessions(%{sessions: sessions, total: total}) do
    %{
      success: true,
      data: sessions,
      meta: %{total: total}
    }
  end

  defp data(%Profile{} = profile) do
    %{
      id: profile.id,
      name: profile.name,
      description: profile.description,
      browser_type: profile.browser_type,
      status: profile.status,
      storage_size_bytes: profile.storage_size_bytes,
      last_used_at: profile.last_used_at,
      version: profile.version,
      has_data: profile.media_file_id != nil
    }
  end

  defp data_detailed(%Profile{} = profile) do
    data(profile)
    |> Map.merge(%{
      metadata: profile.metadata,
      media_file_id: profile.media_file_id,
      inserted_at: profile.inserted_at,
      updated_at: profile.updated_at
    })
  end

  defp serialize_snapshot(snapshot) do
    %{
      id: snapshot.id,
      version: snapshot.version,
      storage_size_bytes: snapshot.storage_size_bytes,
      created_by_session_id: snapshot.created_by_session_id,
      metadata: snapshot.metadata,
      inserted_at: snapshot.inserted_at
    }
  end

  defp serialize_meta(nil), do: %{}

  defp serialize_meta(meta) do
    %{
      current_page: Map.get(meta, :current_page, 1),
      page_size: Map.get(meta, :page_size, 20),
      total_count: Map.get(meta, :total_count, 0),
      total_pages: Map.get(meta, :total_pages, 1)
    }
  end
end
