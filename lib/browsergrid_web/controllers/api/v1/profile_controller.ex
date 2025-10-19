defmodule BrowsergridWeb.API.V1.ProfileController do
  use BrowsergridWeb, :controller

  alias Browsergrid.Profiles

  action_fallback BrowsergridWeb.API.V1.FallbackController

  def index(conn, _params) do
    user = conn.assigns.current_user
    profiles = Profiles.list_user_profiles(user)
    json(conn, %{data: profiles})
  end

  def show(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    case Profiles.fetch_user_profile(user, id) do
      {:ok, profile} -> json(conn, %{data: profile})
      {:error, _} -> {:error, :not_found}
    end
  end

  def create(conn, %{"profile" => profile_params}) do
    params = put_owner(profile_params, conn)

    case Profiles.create_profile(params) do
      {:ok, profile} ->
        conn
        |> put_status(:created)
        |> json(%{data: profile})

      {:error, %Ecto.Changeset{} = changeset} ->
        {:error, changeset}
    end
  end

  def update(conn, %{"id" => id, "profile" => profile_params}) do
    user = conn.assigns.current_user
    sanitized = ensure_owner(profile_params, conn)

    with {:ok, profile} <- Profiles.fetch_user_profile(user, id),
         {:ok, updated} <- Profiles.update_profile(profile, sanitized) do
      json(conn, %{data: updated})
    else
      {:error, _} -> {:error, :not_found}
    end
  end

  def delete(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    with {:ok, profile} <- Profiles.fetch_user_profile(user, id),
         {:ok, _} <- Profiles.delete_profile(profile) do
      send_resp(conn, :no_content, "")
    else
      {:error, _} -> {:error, :not_found}
    end
  end

  defp put_owner(params, conn) do
    user_id = conn.assigns.current_user.id
    Map.put(params, "user_id", user_id)
  end

  defp ensure_owner(params, conn) do
    params
    |> Map.delete("user_id")
    |> Map.delete(:user_id)
    |> put_owner(conn)
  end
end
