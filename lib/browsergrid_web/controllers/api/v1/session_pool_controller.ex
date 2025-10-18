defmodule BrowsergridWeb.API.V1.SessionPoolController do
  use BrowsergridWeb, :controller

  alias Browsergrid.SessionPools
  alias Browsergrid.Sessions

  action_fallback BrowsergridWeb.API.V1.FallbackController

  def index(conn, _params) do
    pools = SessionPools.list_visible_pools(conn.assigns.current_user)
    json(conn, %{data: pools})
  end

  def create(conn, %{"pool" => pool_params}) do
    user = conn.assigns.current_user

    with {:ok, pool} <- SessionPools.create_pool(pool_params, user) do
      conn
      |> put_status(:created)
      |> json(%{data: pool})
    end
  end

  def update(conn, %{"id" => id, "pool" => pool_params}) do
    user = conn.assigns.current_user

    with {:ok, pool} <- fetch_pool_for_user(id, user),
         {:ok, updated} <- SessionPools.update_pool(pool, pool_params) do
      json(conn, %{data: updated})
    end
  end

  def delete(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    with {:ok, pool} <- fetch_pool_for_user(id, user),
         {:ok, _deleted} <- SessionPools.delete_pool(pool) do
      send_resp(conn, :no_content, "")
    else
      {:error, :system_pool} ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "cannot_delete_system_pool"})

      {:error, :active_sessions} ->
        conn
        |> put_status(:conflict)
        |> json(%{error: "pool_has_active_sessions"})

      {:error, reason} ->
        {:error, reason}
    end
  end

  def claim(conn, %{"id" => identifier}) do
    user = conn.assigns.current_user

    with {:ok, pool} <- fetch_pool_for_claim(identifier, user),
         {:ok, session} <- SessionPools.claim_session(pool, user),
         {:ok, connection} <- Sessions.get_connection_info(session.id) do
      json(conn, %{data: %{session: session, connection: connection}})
    else
      {:error, :no_available_sessions} ->
        conn
        |> put_status(:conflict)
        |> json(%{error: "no_available_sessions"})

      {:error, reason} ->
        {:error, reason}
    end
  end

  def stats(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    with {:ok, pool} <- fetch_pool_for_user(id, user) do
      json(conn, %{data: SessionPools.pool_statistics(pool)})
    end
  end

  defp fetch_pool_for_user("default", user), do: fetch_pool_for_claim("default", user)
  defp fetch_pool_for_user(id, user), do: authorize_pool(id, user)

  defp fetch_pool_for_claim(identifier, user) do
    with {:ok, pool} <- resolve_pool(identifier),
         :ok <- authorize_claim(pool, user) do
      {:ok, pool}
    end
  end

  defp authorize_pool(id, user) do
    with {:ok, pool} <- SessionPools.fetch_pool(id),
         :ok <- authorize_claim(pool, user) do
      {:ok, pool}
    end
  end

  defp resolve_pool("default"), do: SessionPools.fetch_pool(:default)
  defp resolve_pool(id), do: SessionPools.fetch_pool(id)

  defp authorize_claim(%{system: true}, _user), do: :ok

  defp authorize_claim(%{owner_id: owner_id}, %{id: user_id}) when owner_id == user_id, do: :ok

  defp authorize_claim(_pool, _user), do: {:error, :forbidden}
end
