defmodule BrowsergridWeb.API.V1.ConnectController do
  use BrowsergridWeb, :controller

  alias Browsergrid.SessionPools
  alias Browsergrid.SessionRuntime

  action_fallback BrowsergridWeb.API.V1.FallbackController

  @finch_timeout 5_000

  def show(conn, params) do
    user = conn.assigns.current_user
    path_segments = normalize_path(Map.get(params, "path"))
    pool_identifier = Map.get(conn.params, "pool")

    with {:ok, pool} <- SessionPools.fetch_pool_for_claim(pool_identifier, user),
         {:ok, session} <- SessionPools.claim_or_provision_session(pool, user),
         {:ok, payload} <- fetch_cdp_payload(session.id, path_segments, conn) do
      json(conn, payload)
    else
      {:error, :no_available_sessions} ->
        conn
        |> put_status(:conflict)
        |> json(%{error: "no_available_sessions"})

      {:error, :pool_at_capacity} ->
        conn
        |> put_status(:conflict)
        |> json(%{
          error: "pool_at_capacity",
          message: "Pool has reached maximum capacity. Try again later."
        })

      {:error, {:upstream_error, status}} ->
        conn
        |> put_status(:bad_gateway)
        |> json(%{error: "upstream_error", status: status})

      {:error, :upstream_unavailable} ->
        conn
        |> put_status(:bad_gateway)
        |> json(%{error: "upstream_unavailable"})

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp normalize_path(nil), do: ["json"]
  defp normalize_path([]), do: ["json"]

  defp normalize_path(segments) when is_list(segments) do
    segments
    |> Enum.map(&to_string/1)
    |> case do
      [] -> ["json"]
      list -> list
    end
  end

  defp normalize_path(segment), do: [to_string(segment)]

  defp fetch_cdp_payload(session_id, path_segments, conn) do
    with {:ok, endpoint} <- SessionRuntime.upstream_endpoint(session_id),
         {:ok, body} <- request_upstream(endpoint, path_segments, conn),
         {:ok, decoded} <- decode_payload(body) do
      {:ok, rewrite_cdp_payload(decoded, conn, session_id)}
    else
      {:error, %Jason.DecodeError{}} ->
        {:error, :upstream_unavailable}

      {:error, {:upstream_error, _status} = error} ->
        {:error, error}

      {:error, :not_found} ->
        {:error, :upstream_unavailable}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp request_upstream(endpoint, path_segments, conn) do
    scheme = endpoint_scheme(endpoint)

    uri =
      URI.to_string(%URI{
        scheme: scheme,
        host: endpoint.host,
        port: endpoint.port,
        path: "/" <> Enum.join(path_segments, "/"),
        query: encode_upstream_query(conn)
      })

    :get
    |> Finch.build(uri)
    |> Finch.request(Browsergrid.Finch, receive_timeout: @finch_timeout, pool_timeout: @finch_timeout)
    |> case do
      {:ok, %Finch.Response{status: status, body: body}} when status in 200..299 ->
        {:ok, body}

      {:ok, %Finch.Response{status: status}} ->
        {:error, {:upstream_error, status}}

      {:error, _} = error ->
        error
    end
  end

  defp endpoint_scheme(%{scheme: scheme}) when is_binary(scheme), do: scheme
  defp endpoint_scheme(_), do: "http"

  defp encode_upstream_query(conn) do
    conn.query_params
    |> Enum.reduce(%{}, fn
      {"token", _value}, acc ->
        acc

      {"pool", _value}, acc ->
        acc

      {"path", _value}, acc ->
        acc

      {key, value}, acc ->
        case normalize_query_value(value) do
          nil -> acc
          normalized -> Map.put(acc, key, normalized)
        end
    end)
    |> case do
      map when map_size(map) == 0 -> nil
      map -> URI.encode_query(map)
    end
  end

  defp normalize_query_value(value) when is_binary(value) do
    trimmed = String.trim(value)
    if trimmed == "", do: nil, else: trimmed
  end

  defp normalize_query_value(value) when is_integer(value), do: Integer.to_string(value)
  defp normalize_query_value(value) when is_float(value), do: :erlang.float_to_binary(value, [:compact])
  defp normalize_query_value(value) when is_list(value), do: Enum.join(value, ",")
  defp normalize_query_value(_), do: nil

  defp decode_payload(body) do
    case Jason.decode(body) do
      {:ok, decoded} -> {:ok, decoded}
      error -> error
    end
  end

  defp rewrite_cdp_payload(payload, conn, session_id) when is_map(payload) do
    rewrite_cdp_object(payload, conn, session_id)
  end

  defp rewrite_cdp_payload(payload, conn, session_id) when is_list(payload) do
    Enum.map(payload, &rewrite_cdp_payload(&1, conn, session_id))
  end

  defp rewrite_cdp_payload(payload, _conn, _session_id), do: payload

  defp rewrite_cdp_object(map, conn, session_id) do
    original_ws = Map.get(map, "webSocketDebuggerUrl")

    rewritten =
      Enum.reduce(map, %{}, fn {key, value}, acc ->
        Map.put(acc, key, rewrite_cdp_payload(value, conn, session_id))
      end)

    ws_path =
      case extract_ws_path(original_ws) do
        nil -> derive_ws_path(rewritten)
        path -> path
      end

    case build_proxied_ws_url(ws_path, conn, session_id) do
      nil ->
        rewritten

      ws_url ->
        rewritten
        |> Map.put("webSocketDebuggerUrl", ws_url)
        |> Map.put("devtoolsFrontendUrl", ws_url)
        |> maybe_put_devtools_compat(ws_url, map)
    end
  end

  defp maybe_put_devtools_compat(map, ws_url, original_map) do
    if Map.has_key?(original_map, "devtoolsFrontendUrlCompat") do
      Map.put(map, "devtoolsFrontendUrlCompat", ws_url)
    else
      map
    end
  end

  defp extract_ws_path(nil), do: nil
  defp extract_ws_path(""), do: nil

  defp extract_ws_path(url) when is_binary(url) do
    case URI.parse(url) do
      %URI{path: path, query: query} ->
        cond do
          is_binary(path) and is_binary(query) and query != "" -> path <> "?" <> query
          is_binary(path) -> path
          true -> nil
        end

      _ ->
        nil
    end
  end

  defp extract_ws_path(_), do: nil

  defp derive_ws_path(%{"type" => "page", "id" => id}) when is_binary(id) do
    "/devtools/page/" <> id
  end

  defp derive_ws_path(%{"id" => id}) when is_binary(id) do
    "/devtools/browser/" <> id
  end

  defp derive_ws_path(_), do: nil

  defp build_proxied_ws_url(nil, _conn, _session_id), do: nil

  defp build_proxied_ws_url(ws_path, conn, session_id) do
    proxied_path =
      ws_path
      |> ensure_leading_slash()
      |> maybe_prefix_session(session_id)

    ws_scheme = external_ws_scheme(conn)
    host = external_host(conn)

    "#{ws_scheme}://#{host}#{proxied_path}"
  end

  defp ensure_leading_slash(path) do
    cond do
      is_binary(path) and String.starts_with?(path, "/") -> path
      is_binary(path) -> "/" <> path
      true -> "/"
    end
  end

  defp maybe_prefix_session("/sessions/" <> _rest = path, _session_id), do: path

  defp maybe_prefix_session(path, session_id) do
    "/sessions/#{session_id}/connect" <> path
  end

  defp external_ws_scheme(conn) do
    case external_scheme(conn) do
      scheme when scheme in ["https", "wss"] -> "wss"
      _ -> "ws"
    end
  end

  defp external_scheme(conn) do
    conn
    |> get_req_header("x-forwarded-proto")
    |> List.first()
    |> presence()
    |> case do
      nil -> Atom.to_string(conn.scheme)
      scheme -> scheme
    end
  end

  defp external_host(conn) do
    forwarded_host =
      conn
      |> get_req_header("x-forwarded-host")
      |> List.first()
      |> presence()

    case forwarded_host do
      nil -> build_host(conn)
      host -> host
    end
  end

  defp build_host(conn) do
    scheme = Atom.to_string(conn.scheme)
    port = conn.port

    if default_port?(scheme, port) do
      conn.host
    else
      "#{conn.host}:#{port}"
    end
  end

  defp default_port?("http", 80), do: true
  defp default_port?("https", 443), do: true
  defp default_port?(_scheme, _port), do: false

  defp presence(nil), do: nil
  defp presence(""), do: nil
  defp presence(value), do: value
end
