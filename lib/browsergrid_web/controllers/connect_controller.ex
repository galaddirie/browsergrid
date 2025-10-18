defmodule BrowsergridWeb.ConnectController do
  use BrowsergridWeb, :controller

  alias Browsergrid.Connect
  alias Browsergrid.Connect.SessionInfo
  alias Browsergrid.Connect.Socket
  alias Plug.Conn.Query

  require Logger

  def index(conn, params) do
    with :ok <- ensure_route_allowed(conn),
         {:ok, token} <- extract_token(params) do
      if websocket_upgrade?(conn) do
        handle_websocket(conn, token)
      else
        respond_claim(conn, token, :json)
      end
    else
      {:error, :missing_token} -> respond_error(conn, :bad_request, "missing token parameter")
      {:error, :unauthorized} -> respond_error(conn, :unauthorized, "unauthorized")
      {:error, {:route_not_allowed, :path}} -> respond_error(conn, :not_found, "not found")
      {:error, {:route_not_allowed, :host}} -> respond_error(conn, :not_found, "not found")
    end
  end

  def version(conn, params) do
    with :ok <- ensure_route_allowed(conn),
         {:ok, token} <- extract_token(params) do
      respond_claim(conn, token, :version)
    else
      {:error, :missing_token} -> respond_error(conn, :bad_request, "missing token parameter")
      {:error, :unauthorized} -> respond_error(conn, :unauthorized, "unauthorized")
      {:error, {:route_not_allowed, _kind}} -> respond_error(conn, :not_found, "not found")
    end
  end

  defp respond_claim(conn, token, format) do
    case Connect.claim_session(token) do
      {:ok, %SessionInfo{} = session} ->
        conn
        |> cache_control()
        |> json(build_payload(conn, session, token, format))
        |> halt()

      {:error, :empty} ->
        respond_error(conn, :service_unavailable, "no idle sessions available")

      {:error, :invalid_token} ->
        respond_error(conn, :bad_request, "invalid token")

      {:error, :unauthorized} ->
        respond_error(conn, :unauthorized, "unauthorized")

      {:error, :missing_token} ->
        respond_error(conn, :bad_request, "missing token parameter")

      {:error, :stale_claim} ->
        respond_error(conn, :service_unavailable, "session unavailable")

      {:error, reason} ->
        Logger.error("connect claim failed", reason: inspect(reason))
        respond_error(conn, :internal_server_error, "claim failed")
    end
  end

  defp handle_websocket(conn, token) do
    case Connect.fetch_claim(token) do
      {:ok, %SessionInfo{} = session} ->
        {route_kind, prefix_segments} = route_kind(conn)
        base_path = base_path(prefix_segments)
        target_path = build_target_path(conn.path_info, prefix_segments)
        query = filtered_query(conn.query_string, ["token"])

        state = %{
          token: token,
          session_id: session.id,
          target_path: target_path,
          query: query,
          headers: websocket_headers(conn, base_path),
          metadata: %{
            route_kind: route_kind,
            base_path: base_path
          }
        }

        conn
        |> cache_control()
        |> WebSockAdapter.upgrade(Socket, state, timeout: 120_000)
        |> halt()

      {:error, :missing_token} ->
        respond_error(conn, :bad_request, "missing token parameter")

      {:error, :unauthorized} ->
        respond_error(conn, :unauthorized, "unauthorized")

      {:error, :not_found} ->
        respond_error(conn, :not_found, "claim not found")

      {:error, reason} ->
        Logger.warning("connect websocket upgrade failed", reason: inspect(reason))
        respond_error(conn, :bad_request, "unable to upgrade websocket")
    end
  end

  defp ensure_route_allowed(conn) do
    mode = Connect.routing_mode()
    {kind, prefix_segments} = route_kind(conn)

    case {kind, mode} do
      {:path, mode} when mode in [:path, :both] ->
        if path_prefix_matches?(conn.path_info, prefix_segments) do
          :ok
        else
          {:error, {:route_not_allowed, :path}}
        end

      {:host, mode} when mode in [:subdomain, :both] ->
        ensure_host_allowed(conn)

      {:host, _mode} ->
        {:error, {:route_not_allowed, :host}}

      {:path, _mode} ->
        {:error, {:route_not_allowed, :path}}
    end
  end

  defp ensure_host_allowed(conn) do
    case Connect.host() do
      nil ->
        :ok

      host ->
        if String.downcase(conn.host) == String.downcase(host) do
          :ok
        else
          {:error, {:route_not_allowed, :host}}
        end
    end
  end

  defp route_kind(conn) do
    prefix_segments = path_prefix_segments()

    if prefix_segments == [] do
      {:host, []}
    else
      request_prefix = Enum.take(conn.path_info, length(prefix_segments))

      if request_prefix == prefix_segments do
        {:path, prefix_segments}
      else
        {:host, []}
      end
    end
  end

  defp path_prefix_segments do
    Connect.path_prefix()
    |> String.trim("/")
    |> case do
      "" -> []
      segment -> String.split(segment, "/", trim: true)
    end
  end

  defp path_prefix_matches?(path_info, prefix_segments) do
    Enum.take(path_info, length(prefix_segments)) == prefix_segments
  end

  defp extract_token(%{"token" => token}) when is_binary(token) and token != "" do
    if Connect.token_authorised?(token) do
      {:ok, token}
    else
      {:error, :unauthorized}
    end
  end

  defp extract_token(%{"token" => _}), do: {:error, :missing_token}
  defp extract_token(_), do: {:error, :missing_token}

  defp build_payload(conn, session, token, :json) do
    ws_url = websocket_url(conn)
    claim_deadline = session |> claim_deadline() |> maybe_iso()

    [
      %{
        "id" => session.id,
        "type" => "page",
        "title" => "Browsergrid Session",
        "description" => "Pre-warmed pooled session",
        "webSocketDebuggerUrl" => ws_url,
        "browserWSEndpoint" => ws_url,
        "sessionId" => session.id,
        "status" => Atom.to_string(session.status),
        "claimedAt" => maybe_iso(session.claimed_at),
        "claimExpiresAt" => claim_deadline,
        "token" => token_tail(token)
      }
    ]
  end

  defp build_payload(conn, session, token, :version) do
    ws_url = websocket_url(conn)

    %{
      "Browser" => "Browsergrid/Connect",
      "Protocol-Version" => "1.3",
      "User-Agent" => "Browsergrid Connect",
      "V8-Version" => "unknown",
      "webSocketDebuggerUrl" => ws_url,
      "browserWSEndpoint" => ws_url,
      "sessionId" => session.id,
      "status" => Atom.to_string(session.status),
      "claimedAt" => maybe_iso(session.claimed_at),
      "claimExpiresAt" => session |> claim_deadline() |> maybe_iso(),
      "token" => token_tail(token)
    }
  end

  defp claim_deadline(%SessionInfo{claimed_at: nil}), do: nil

  defp claim_deadline(%SessionInfo{claimed_at: claimed_at}) do
    DateTime.add(claimed_at, Connect.claim_timeout_ms(), :millisecond)
  end

  defp maybe_iso(nil), do: nil
  defp maybe_iso(%DateTime{} = dt), do: DateTime.to_iso8601(dt)

  defp token_tail(token) when is_binary(token) do
    if byte_size(token) <= 4 do
      token
    else
      String.slice(token, -4, 4)
    end
  end

  defp websocket_url(conn) do
    scheme = if conn.scheme == :https, do: "wss", else: "ws"
    host = host_with_port(conn)
    qs = conn.query_string
    base = "#{scheme}://#{host}#{conn.request_path}"

    if qs in [nil, ""] do
      base
    else
      base <> "?" <> qs
    end
  end

  defp host_with_port(%Plug.Conn{host: host, port: port, scheme: scheme}) do
    case {scheme, port} do
      {:https, 443} -> host
      {:http, 80} -> host
      _ -> "#{host}:#{port}"
    end
  end

  defp websocket_upgrade?(conn) do
    conn
    |> get_req_header("upgrade")
    |> Enum.any?(fn header -> String.downcase(header) == "websocket" end)
  end

  defp cache_control(conn) do
    conn
    |> put_resp_header("cache-control", "no-store")
    |> put_resp_header("pragma", "no-cache")
  end

  defp respond_error(conn, status, message) do
    conn
    |> cache_control()
    |> put_status(status)
    |> json(%{error: message})
    |> halt()
  end

  defp build_target_path(path_info, prefix_segments) do
    relative_segments = Enum.drop(path_info, length(prefix_segments))
    "/" <> Enum.join(relative_segments, "/")
  end

  defp base_path([]), do: "/"
  defp base_path(segments), do: "/" <> Enum.join(segments, "/")

  defp filtered_query("", _drop_keys), do: ""

  defp filtered_query(query_string, drop_keys) do
    query_string
    |> Query.decode()
    |> Map.drop(drop_keys)
    |> Query.encode()
  end

  defp websocket_headers(conn, base_path) do
    forwarding_headers(conn, base_path) ++
      Enum.filter(conn.req_headers, fn {key, _} ->
        String.downcase(key) in ["sec-websocket-protocol", "origin"]
      end)
  end

  defp forwarding_headers(conn, base_path) do
    {external_host, external_host_with_prefix, external_scheme} =
      external_connection_parts(conn, base_path)

    forwarded_ip =
      conn.remote_ip
      |> :inet.ntoa()
      |> to_string()

    forwarded_header =
      conn
      |> get_req_header("x-forwarded-for")
      |> List.first()
      |> case do
        nil -> forwarded_ip
        existing -> existing <> ", " <> forwarded_ip
      end

    [
      {"x-forwarded-host", external_host},
      {"x-external-host", external_host_with_prefix},
      {"x-forwarded-proto", external_scheme},
      {"x-external-scheme", external_scheme},
      {"x-forwarded-for", forwarded_header}
    ]
  end

  defp external_connection_parts(conn, base_path) do
    external_host = forwarded_host(conn)
    external_scheme = if conn.scheme == :https, do: "https", else: "http"

    external_host_with_prefix =
      case base_path do
        "/" -> external_host
        path -> external_host <> path
      end

    {external_host, external_host_with_prefix, external_scheme}
  end

  defp forwarded_host(conn) do
    conn
    |> get_req_header("host")
    |> List.first()
    |> case do
      nil ->
        case conn.port do
          80 -> conn.host
          443 -> conn.host
          port -> "#{conn.host}:#{port}"
        end

      header ->
        header
    end
  end
end
