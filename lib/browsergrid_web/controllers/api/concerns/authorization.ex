defmodule BrowsergridWeb.Controllers.API.Concerns.Authorization do
  @moduledoc """
  Shared helpers for enforcing ownership of resources within API controllers.
  """
  import Plug.Conn

  alias Browsergrid.Accounts.User

  @doc """
  Ensures the given resource is owned by the current user assigned to the connection.
  """
  @spec authorize_resource(Plug.Conn.t(), %{user_id: Ecto.UUID.t() | nil}) ::
          {:ok, any()} | {:error, Plug.Conn.t()}
  def authorize_resource(conn, %{user_id: resource_user_id} = resource) when is_binary(resource_user_id) do
    case conn.assigns[:current_user] do
      %User{id: ^resource_user_id} ->
        {:ok, resource}

      _ ->
        {:error, forbid(conn)}
    end
  end

  def authorize_resource(conn, _resource), do: {:error, forbid(conn)}

  defp forbid(conn) do
    body =
      %{
        error: "forbidden",
        reason: "not_owner"
      }
      |> Jason.encode!()

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(:forbidden, body)
    |> halt()
  end
end
