defmodule BrowsergridWeb.API.V1.ApiKeyJSON do
  alias Browsergrid.ApiKeys.APIKey

  def index(%{api_keys: api_keys}) do
    %{data: Enum.map(api_keys, &serialize/1)}
  end

  def show(%{api_key: api_key}) do
    %{data: serialize(api_key)}
  end

  def create(%{api_key: api_key, token: token}) do
    %{data: serialize(api_key) |> Map.put(:token, token)}
  end

  def regenerate(%{api_key: api_key, token: token}) do
    %{data: serialize(api_key) |> Map.put(:token, token)}
  end

  def revoke(%{api_key: api_key}) do
    %{data: serialize(api_key)}
  end

  defp serialize(%APIKey{} = api_key) do
    %{
      id: api_key.id,
      name: api_key.name,
      prefix: api_key.prefix,
      last_four: api_key.last_four,
      status: status(api_key),
      created_by: api_key.created_by,
      usage_count: api_key.usage_count,
      metadata: api_key.metadata,
      inserted_at: encode_datetime(api_key.inserted_at),
      updated_at: encode_datetime(api_key.updated_at),
      revoked_at: encode_datetime(api_key.revoked_at),
      expires_at: encode_datetime(api_key.expires_at),
      last_used_at: encode_datetime(api_key.last_used_at)
    }
  end

  defp serialize(_), do: %{}

  defp encode_datetime(nil), do: nil
  defp encode_datetime(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
  defp encode_datetime(%NaiveDateTime{} = ndt), do: DateTime.from_naive!(ndt, "Etc/UTC") |> DateTime.to_iso8601()

  defp status(%APIKey{revoked_at: revoked_at}) when not is_nil(revoked_at), do: "revoked"

  defp status(%APIKey{expires_at: nil}), do: "active"

  defp status(%APIKey{expires_at: expires_at}) do
    case DateTime.compare(expires_at, DateTime.utc_now()) do
      :lt -> "expired"
      _ -> "active"
    end
  end
end
