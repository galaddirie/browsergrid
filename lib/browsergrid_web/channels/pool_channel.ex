defmodule BrowsergridWeb.PoolChannel do
  @moduledoc """
  Phoenix channel for real-time pool updates.
  Handles broadcasting pool status changes and session pool events.
  """

  use Phoenix.Channel

  alias Browsergrid.SessionPools

  @impl true
  def join("pools", _payload, socket) do
    # TODO: ensure auth
    {:ok, socket}
  end

  @impl true
  def handle_in("get_pools", _payload, socket) do
    pools = SessionPools.list_pools()
    {:reply, {:ok, %{pools: pools}}, socket}
  end

  @impl true
  def handle_in("ping", payload, socket) do
    {:reply, {:ok, payload}, socket}
  end

  # Handle pool status updates
  def broadcast_pool_update(pool) do
    BrowsergridWeb.Endpoint.broadcast(
      "pools",
      "pool_updated",
      %{pool: pool}
    )
  end

  # Handle new pool creation
  def broadcast_pool_created(pool) do
    BrowsergridWeb.Endpoint.broadcast(
      "pools",
      "pool_created",
      %{pool: pool}
    )
  end

  # Handle pool deletion
  def broadcast_pool_deleted(pool_id) do
    BrowsergridWeb.Endpoint.broadcast(
      "pools",
      "pool_deleted",
      %{pool_id: pool_id}
    )
  end
end


