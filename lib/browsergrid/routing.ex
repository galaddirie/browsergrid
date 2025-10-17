defmodule Browsergrid.Routing do
  @moduledoc """
  Routing context for authoritative routes table and Redis fanout.
  """
  import Ecto.Query, warn: false

  alias Browsergrid.Repo
  alias Browsergrid.Routing.Route

  require Logger

  @spec upsert_route(String.t(), String.t(), non_neg_integer()) :: {:ok, Route.t()} | {:error, Ecto.Changeset.t()}
  def upsert_route(session_id, ip, port) do
    Logger.debug("upsert_route called for session #{session_id}: #{ip}:#{port}")
    attrs = %{session_id: session_id, ip: ip, port: port}

    existing_route = Repo.get(Route, session_id)
    Logger.debug("Existing route for session #{session_id}: #{inspect(existing_route)}")

    changeset =
      case existing_route do
        nil ->
          Logger.debug("Creating new route for session #{session_id}")
          Route.changeset(%Route{id: session_id}, attrs)

        %Route{} = route ->
          Logger.debug("Updating existing route for session #{session_id}")
          Route.changeset(route, attrs)
      end

    Logger.debug("Changeset for session #{session_id}: #{inspect(changeset)}")

    case Repo.insert_or_update(changeset) do
      {:ok, route} ->
        Logger.debug("Route inserted/updated successfully: #{inspect(route)}")
        Logger.debug("Publishing route to Redis for session #{session_id}")

        case Browsergrid.Redis.publish_route_upsert(session_id, ip, port) do
          {:ok, _subscribers} ->
            Logger.debug("Route published to Redis successfully for session #{session_id}")
            {:ok, route}

          error ->
            Logger.error("Failed to publish route to Redis for session #{session_id}: #{inspect(error)}")
            {:ok, route}
        end

      error ->
        Logger.error("Failed to upsert route for session #{session_id}: #{inspect(error)}")
        error
    end
  end

  @spec delete_route(String.t()) :: :ok
  def delete_route(session_id) do
    case Repo.get(Route, session_id) do
      nil ->
        :ok

      %Route{} = route ->
        {:ok, _} = Repo.delete(route)

        case Browsergrid.Redis.publish_route_delete(session_id) do
          {:ok, _subscribers} ->
            Logger.debug("Route deletion published to Redis for session #{session_id}")

          error ->
            Logger.error("Failed to publish route deletion to Redis for session #{session_id}: #{inspect(error)}")
        end

        :ok
    end
  end

  @spec get_route(String.t()) :: %{ip: String.t(), port: non_neg_integer()} | nil
  def get_route(session_id) do
    case Repo.get(Route, session_id) do
      nil -> nil
      %Route{ip: ip, port: port} -> %{ip: ip, port: port}
    end
  end

  @spec list_routes(non_neg_integer(), non_neg_integer()) :: [%Route{}]
  def list_routes(limit \\ 1000, offset \\ 0) do
    Route
    |> order_by([r], asc: r.version)
    |> limit(^limit)
    |> offset(^offset)
    |> Repo.all()
  end
end
