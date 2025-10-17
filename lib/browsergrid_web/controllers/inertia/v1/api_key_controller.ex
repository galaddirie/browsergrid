defmodule BrowsergridWeb.Inertia.V1.ApiKeyController do
  use BrowsergridWeb, :controller

  alias Browsergrid.ApiKeys
  alias Browsergrid.ApiKeys.APIKey

  require Logger

  def index(conn, _params) do
    render_index(conn, %{})
  end

  def create(conn, %{"api_key" => api_key_params}) do
    case ApiKeys.create_api_key(api_key_params) do
      {:ok, %{api_key: api_key, token: token}} ->
        conn
        |> put_flash(:info, "API key created successfully")
        |> render_index(%{
          new_token: %{
            value: token,
            api_key: present_api_key(api_key)
          }
        })

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render_index(%{errors: format_errors(changeset)})
    end
  end

  def create(conn, params) do
    create(conn, %{"api_key" => params})
  end

  def regenerate(conn, %{"id" => id} = params) do
    attrs = Map.get(params, "api_key", %{})

    with {:ok, api_key} <- fetch_api_key(id) do
      case ApiKeys.regenerate_api_key(api_key, attrs) do
        {:ok, %{api_key: new_key, token: token, revoked_key: revoked}} ->
          conn
          |> put_flash(:info, "API key regenerated")
          |> render_index(%{
            regenerated: %{
              token: token,
              api_key: present_api_key(new_key),
              previous: present_api_key(revoked)
            }
          })

        {:error, %Ecto.Changeset{} = changeset} ->
          conn
          |> put_status(:unprocessable_entity)
          |> render_index(%{errors: format_errors(changeset)})
      end
    else
      {:error, reason} -> handle_error(conn, reason)
    end
  end

  def revoke(conn, %{"id" => id}) do
    with {:ok, api_key} <- fetch_api_key(id) do
      case ApiKeys.revoke_api_key(api_key) do
        {:ok, revoked} ->
          conn
          |> put_flash(:info, "API key revoked")
          |> render_index(%{revoked: present_api_key(revoked)})

        {:error, %Ecto.Changeset{} = changeset} ->
          conn
          |> put_status(:unprocessable_entity)
          |> render_index(%{errors: format_errors(changeset)})
      end
    else
      {:error, reason} -> handle_error(conn, reason)
    end
  end

  defp render_index(conn, extra_props) do
    api_keys = ApiKeys.list_api_keys(include_revoked: true)

    props =
      %{
        api_keys: Enum.map(api_keys, &present_api_key/1),
        stats: statistics(api_keys)
      }
      |> Map.merge(extra_props)

    render_inertia(conn, "APIKeys/Index", props)
  end

  defp present_api_key(%APIKey{} = api_key) do
    status = derive_status(api_key)

    %{
      id: api_key.id,
      name: api_key.name,
      prefix: api_key.prefix,
      lastFour: api_key.last_four,
      displayHint: "bg_#{api_key.prefix}_****#{api_key.last_four}",
      status: status,
      createdBy: api_key.created_by,
      metadata: api_key.metadata || %{},
      usageCount: api_key.usage_count,
      insertedAt: encode_datetime(api_key.inserted_at),
      updatedAt: encode_datetime(api_key.updated_at),
      revokedAt: encode_datetime(api_key.revoked_at),
      expiresAt: encode_datetime(api_key.expires_at),
      lastUsedAt: encode_datetime(api_key.last_used_at)
    }
  end

  defp statistics(api_keys) do
    %{
      total: length(api_keys),
      active: Enum.count(api_keys, &APIKey.active?/1),
      revoked: Enum.count(api_keys, &(not is_nil(&1.revoked_at))),
      expired: Enum.count(api_keys, &expired?/1)
    }
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end

  defp encode_datetime(nil), do: nil
  defp encode_datetime(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
  defp encode_datetime(%NaiveDateTime{} = ndt), do: DateTime.from_naive!(ndt, "Etc/UTC") |> DateTime.to_iso8601()

  defp derive_status(%APIKey{} = api_key) do
    cond do
      not is_nil(api_key.revoked_at) -> "revoked"
      expired?(api_key) -> "expired"
      true -> "active"
    end
  end

  defp expired?(%APIKey{expires_at: nil}), do: false

  defp expired?(%APIKey{expires_at: expires_at}) do
    DateTime.compare(expires_at, DateTime.utc_now()) == :lt
  end

  defp fetch_api_key(id) do
    case ApiKeys.get_api_key(id) do
      nil -> {:error, :not_found}
      api_key -> {:ok, api_key}
    end
  end

  defp handle_error(conn, :not_found) do
    conn
    |> put_status(:not_found)
    |> render_index(%{errors: %{base: "API key not found"}})
  end

  defp handle_error(conn, reason) do
    Logger.error("API key operation failed: #{inspect(reason)}")

    conn
    |> put_status(:internal_server_error)
    |> render_index(%{errors: %{base: "Unexpected error"}})
  end
end
