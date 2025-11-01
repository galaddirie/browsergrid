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
         {:ok, _deleted} <- SessionPools.delete_pool(pool, actor: user) do
      send_resp(conn, :no_content, "")
    else
      {:error, :system_pool} ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "cannot_delete_system_pool"})

      {:error, :last_system_pool} ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "cannot_delete_last_system_pool"})

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

  defp fetch_pool_for_user(identifier, user) do
    with {:ok, pool} <- SessionPools.resolve_pool_identifier(identifier),
         :ok <- SessionPools.authorize_manage(pool, user) do
      {:ok, pool}
    end
  end

  defp fetch_pool_for_claim(identifier, user) do
    SessionPools.fetch_pool_for_claim(identifier, user)
  end
end
