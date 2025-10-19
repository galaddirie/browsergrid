defmodule Browsergrid.Routing do
  @moduledoc """
  Routing context for the authoritative routes table.
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

    Repo.insert_or_update(changeset)
  end

  @spec delete_route(String.t()) :: :ok
  def delete_route(session_id) do
    case Repo.get(Route, session_id) do
      nil ->
        :ok

      %Route{} = route ->
        Repo.delete(route)
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
