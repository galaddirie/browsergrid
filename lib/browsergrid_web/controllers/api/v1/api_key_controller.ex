defmodule BrowsergridWeb.API.V1.ApiKeyController do
  use BrowsergridWeb, :controller

  alias Browsergrid.ApiKeys

  action_fallback BrowsergridWeb.API.V1.FallbackController

  def index(conn, params) do
    include_revoked? = truthy_param?(Map.get(params, "include_revoked", "true"))

    api_keys =
      ApiKeys.list_api_keys(include_revoked: include_revoked?)

    render(conn, :index, api_keys: api_keys)
  end

  def create(conn, params) do
    attrs = permitted_params(params)

    with {:ok, %{api_key: api_key, token: token}} <- ApiKeys.create_api_key(attrs) do
      conn
      |> put_status(:created)
      |> render(:create, api_key: api_key, token: token)
    end
  end

  def revoke(conn, %{"id" => id}) do
    with {:ok, api_key} <- fetch_api_key(id),
         {:ok, revoked} <- ApiKeys.revoke_api_key(api_key) do
      render(conn, :revoke, api_key: revoked)
    end
  end

  def regenerate(conn, %{"id" => id} = params) do
    attrs = permitted_params(Map.delete(params, "id"))

    with {:ok, api_key} <- fetch_api_key(id),
         {:ok, %{api_key: new_key, token: token}} <- ApiKeys.regenerate_api_key(api_key, attrs) do
      render(conn, :regenerate, api_key: new_key, token: token)
    end
  end

  def show(conn, %{"id" => id}) do
    with {:ok, api_key} <- fetch_api_key(id) do
      render(conn, :show, api_key: api_key)
    end
  end

  defp permitted_params(params) do
    Map.take(params, ["name", "metadata", "expires_at", "created_by"])
  end

  defp fetch_api_key(id) do
    case ApiKeys.get_api_key(id) do
      nil -> {:error, :not_found}
      api_key -> {:ok, api_key}
    end
  end

  defp truthy_param?(value) when is_binary(value) do
    value
    |> String.downcase()
    |> case do
      v when v in ["1", "true", "yes", "on"] -> true
      _ -> false
    end
  end

  defp truthy_param?(value) when value in [true, false], do: value
  defp truthy_param?(_), do: false
end
