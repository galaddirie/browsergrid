defmodule BrowsergridWeb.API.V1.ProfileController do
  use BrowsergridWeb, :controller

  alias Browsergrid.Profiles
  alias Browsergrid.Profiles.Profile
  alias BrowsergridWeb.Controllers.API.Concerns.Authorization

  action_fallback BrowsergridWeb.API.V1.FallbackController

  def index(conn, _params) do
    user = conn.assigns.current_user
    profiles = Profiles.list_profiles(user_id: user.id)
    json(conn, %{data: profiles})
  end

  def show(conn, %{"id" => id}) do
    with {:ok, profile} <- fetch_profile(id),
         {:ok, profile} <- Authorization.authorize_resource(conn, profile) do
      json(conn, %{data: profile})
    else
      {:error, %Plug.Conn{} = conn} ->
        conn

      {:error, reason} ->
        {:error, reason}
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
    with {:ok, profile} <- fetch_profile(id),
         {:ok, profile} <- Authorization.authorize_resource(conn, profile),
         sanitized = ensure_owner(profile_params, conn),
         {:ok, updated} <- Profiles.update_profile(profile, sanitized) do
      json(conn, %{data: updated})
    else
      {:error, %Plug.Conn{} = conn} ->
        conn

      {:error, reason} ->
        {:error, reason}
    end
  end

  def delete(conn, %{"id" => id}) do
    with {:ok, profile} <- fetch_profile(id),
         {:ok, profile} <- Authorization.authorize_resource(conn, profile),
         {:ok, _} <- Profiles.delete_profile(profile) do
      send_resp(conn, :no_content, "")
    else
      {:error, %Plug.Conn{} = conn} ->
        conn

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp fetch_profile(id) do
    case Profiles.get_profile(id) do
      %Profile{} = profile -> {:ok, profile}
      nil -> {:error, :not_found}
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
