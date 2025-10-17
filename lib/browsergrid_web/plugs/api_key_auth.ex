defmodule BrowsergridWeb.Plugs.APIKeyAuth do
  @moduledoc """
  Plug that enforces API key authentication for request pipelines.
  """

  import Plug.Conn

  alias Browsergrid.ApiKeys
  require Logger

  @behaviour Plug

  @impl Plug
  def init(opts) do
    %{
      track_usage?: Keyword.get(opts, :track_usage, true),
      rate_limit?: Keyword.get(opts, :rate_limit, true),
      rate_options: Keyword.get(opts, :rate_options, [])
    }
  end

  @impl Plug
  def call(conn, %{track_usage?: track_usage?, rate_limit?: rate_limit?, rate_options: rate_options}) do
    with {:ok, raw_token} <- extract_token(conn),
         {:ok, api_key} <- ApiKeys.verify_token(raw_token),
         {:ok, rate_meta} <- apply_rate_limit(api_key, rate_limit?, rate_options),
         {:ok, tracked_key} <- maybe_track_usage(api_key, track_usage?) do
      conn
      |> maybe_put_rate_headers(rate_meta)
      |> assign(:api_key, tracked_key)
      |> assign(:token, build_token_assign(tracked_key))
    else
      {:error, :missing_token} ->
        deny(conn, 401, "invalid_token")

      {:error, :invalid_token} ->
        deny(conn, 401, "invalid_token")

      {:error, :revoked} ->
        deny(conn, 401, "invalid_token")

      {:error, :expired} ->
        deny(conn, 401, "invalid_token")

      {:error, :rate_limited, %{retry_after_ms: retry_after}} ->
        deny(conn, 429, "rate_limited", retry_after)

      {:error, reason} ->
        Logger.error("API key auth failure: #{inspect(reason)}")
        deny(conn, 401, "invalid_token")
    end
  end

  defp extract_token(conn) do
    case token_from_header(conn) do
      {:ok, token} -> {:ok, token}
      :error -> token_from_query(conn)
    end
  end

  defp token_from_header(conn) do
    case get_req_header(conn, "authorization") do
      [] -> :error
      [value | _] ->
        case String.split(value, " ", parts: 2) do
          [scheme, token] when String.downcase(scheme) == "bearer" and token != "" ->
            {:ok, String.trim(token)}

          _ ->
            :error
        end
    end
  end

  defp token_from_query(conn) do
    conn = fetch_query_params(conn)

    case conn.params do
      %{"token" => token} when is_binary(token) and token != "" -> {:ok, token}
      _ -> {:error, :missing_token}
    end
  end

  defp apply_rate_limit(_api_key, false, _opts), do: {:ok, %{}}
  defp apply_rate_limit(api_key, true, opts), do: ApiKeys.check_rate_limit(api_key, opts)

  defp maybe_track_usage(api_key, false), do: {:ok, api_key}

  defp maybe_track_usage(api_key, true) do
    case ApiKeys.register_usage(api_key) do
      {:ok, updated} -> {:ok, updated}
      _ -> {:ok, api_key}
    end
  end

  defp build_token_assign(api_key) do
    %{
      id: api_key.id,
      name: api_key.name,
      metadata: api_key.metadata,
      expires_at: api_key.expires_at
    }
  end

  defp maybe_put_rate_headers(conn, %{remaining: remaining, reset_at: reset_at}) do
    conn
    |> put_resp_header("x-ratelimit-remaining", Integer.to_string(max(remaining, 0)))
    |> put_resp_header("x-ratelimit-reset", Integer.to_string(reset_at))
  end

  defp maybe_put_rate_headers(conn, _), do: conn

  defp deny(conn, status, error, retry_after_ms \\ nil) do
    body = Jason.encode!(%{error: error})

    conn
    |> put_resp_content_type("application/json")
    |> maybe_put_retry_after(retry_after_ms)
    |> send_resp(status, body)
    |> halt()
  end

  defp maybe_put_retry_after(conn, nil), do: conn

  defp maybe_put_retry_after(conn, retry_after_ms) do
    seconds = Integer.to_string(div(retry_after_ms + 999, 1000))
    put_resp_header(conn, "retry-after", seconds)
  end
end
