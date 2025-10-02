defmodule BrowsergridWeb.API.V1.SessionJSON do
  alias Browsergrid.Sessions.Session

  def index(%{sessions: sessions, meta: meta}) do
    %{
      success: true,
      data: for(session <- sessions, do: data(session)),
      meta: serialize_meta(meta)
    }
  end

  def show(%{session: session}) do
    %{
      success: true,
      data: data_detailed(session)
    }
  end

  def create(%{session: session, connection_url: url}) do
    %{
      success: true,
      data: Map.merge(data(session), %{connection_url: url}),
      message: "Session created successfully"
    }
  end

  def delete(%{session: session}) do
    %{
      success: true,
      data: %{id: session.id, status: "stopping"},
      message: "Session stopping"
    }
  end

  def connection(%{session: session, url: url}) do
    %{
      success: true,
      data: %{
        id: session.id,
        url: url
      }
    }
  end

  def route(%{session: session, ip: ip, port: port}) do
    %{
      success: true,
      data: %{
        id: session.id,
        ip: ip,
        port: port
      }
    }
  end

  defp data(%Session{} = session) do
    %{
      id: session.id,
      name: session.name,
      browser_type: session.browser_type,
      status: session.status,
      cluster: session.cluster,
      options: session.options
    }
  end

  defp data_detailed(%Session{} = session) do
    data(session)
    |> Map.merge(%{
      profile_id: session.profile_id,
      profile: serialize_profile(session.profile),
      inserted_at: session.inserted_at,
      updated_at: session.updated_at
    })
  end

  defp serialize_profile(nil), do: nil
  defp serialize_profile(%Ecto.Association.NotLoaded{}), do: nil

  defp serialize_profile(profile) do
    %{
      id: profile.id,
      name: profile.name,
      browser_type: profile.browser_type,
      status: profile.status
    }
  end

  defp serialize_meta(nil), do: nil

  defp serialize_meta(meta) do
    %{
      current_page: Map.get(meta, :current_page, 1),
      page_size: Map.get(meta, :page_size, 20),
      total_count: Map.get(meta, :total_count, 0),
      total_pages: Map.get(meta, :total_pages, 1)
    }
  end
end
