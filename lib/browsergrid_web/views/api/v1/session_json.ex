defmodule BrowsergridWeb.API.V1.SessionJSON do
  alias Browsergrid.Sessions.Session
  alias Ecto.Association.NotLoaded

  def index(%{sessions: sessions, meta: meta}) do
    %{
      success: true,
      data: Enum.map(sessions, &serialize/1),
      meta: meta
    }
  end

  def show(%{session: session}) do
    %{success: true, data: serialize(session, detailed: true)}
  end

  def create(%{session: session, connection_url: url}) do
    %{
      success: true,
      data: Map.put(serialize(session), :connection_url, url),
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
    %{success: true, data: %{id: session.id, url: url}}
  end

  # Serialization

  defp serialize(%Session{} = s, opts \\ []) do
    base = %{
      id: s.id,
      name: s.name,
      browser_type: s.browser_type,
      status: s.status,
      cluster: s.cluster,
      headless: s.headless,
      timeout: s.timeout,
      screen: serialize_screen(s.screen),
      limits: serialize_limits(s.limits)
    }

    if Keyword.get(opts, :detailed) do
      Map.merge(base, %{
        profile_id: s.profile_id,
        profile: serialize_profile(s.profile),
        inserted_at: s.inserted_at,
        updated_at: s.updated_at
      })
    else
      base
    end
  end

  defp serialize_screen(nil), do: nil
  defp serialize_screen(%NotLoaded{}), do: nil

  defp serialize_screen(screen) do
    %{
      width: screen.width,
      height: screen.height,
      dpi: screen.dpi,
      scale: screen.scale
    }
  end

  defp serialize_limits(nil), do: nil
  defp serialize_limits(%NotLoaded{}), do: nil

  defp serialize_limits(limits) do
    %{
      cpu: limits.cpu,
      memory: limits.memory,
      timeout_minutes: limits.timeout_minutes
    }
  end

  defp serialize_profile(nil), do: nil
  defp serialize_profile(%NotLoaded{}), do: nil

  defp serialize_profile(profile) do
    %{
      id: profile.id,
      name: profile.name,
      browser_type: profile.browser_type,
      status: profile.status
    }
  end
end
