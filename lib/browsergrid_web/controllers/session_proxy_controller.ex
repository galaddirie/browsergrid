defmodule BrowsergridWeb.SessionProxyController do
  use BrowsergridWeb, :controller

  alias Browsergrid.SessionRuntime

  require Logger

  @hop_by_hop_headers ~w(connection keep-alive proxy-authenticate proxy-authorization te trailers transfer-encoding upgrade)

  def proxy(conn, %{"id" => session_id} = params) do
    path_segments = extract_path_segments(params)
    path = build_path(path_segments)
    base_path = build_base_path(conn.path_info, path_segments)

    if websocket_upgrade?(conn) do
      handle_websocket(conn, session_id, path, base_path)
    else
      handle_http(conn, session_id, path, base_path)
    end
  end

  defp websocket_upgrade?(conn) do
    conn
    |> get_req_header("upgrade")
    |> Enum.any?(fn header -> String.downcase(header) == "websocket" end)
  end

  defp handle_websocket(conn, session_id, path, base_path) do
    case SessionRuntime.upstream_endpoint(session_id) do
      {:ok, %{host: host, port: port}} ->
        state = %{
          session_id: session_id,
          host: host,
          port: port,
          target: append_query(path, conn.query_string),
          headers: websocket_headers(conn, base_path)
        }

        conn
        |> WebSockAdapter.upgrade(BrowsergridWeb.SessionProxySocket, state, timeout: 120_000)
        |> halt()

      {:error, :not_found} ->
        send_resp(conn, 404, "session not running")

      {:error, reason} ->
        Logger.error("websocket proxy failed: #{inspect(reason)}")
        send_resp(conn, 500, "proxy failure")
    end
  end

  defp handle_http(conn, session_id, path, base_path) do
    with {:ok, %{host: host, port: port}} <- SessionRuntime.upstream_endpoint(session_id),
         {:ok, body, conn} <- read_full_body(conn),
         request = build_proxied_request(conn, host, port, path, body, base_path),
         {:ok, response} <- Finch.request(request, Browsergrid.Finch) do
      send_proxied_response(conn, response)
    else
      {:error, :not_found} ->
        send_resp(conn, 404, "session not running")

      {:error, %Mint.TransportError{} = reason} ->
        Logger.error("proxy transport error: #{inspect(reason)}")
        send_resp(conn, 502, "upstream error")

      {:error, reason} ->
        Logger.error("proxy failed: #{inspect(reason)}")
        send_resp(conn, 500, "proxy failure")
    end
  end

  defp request_method(conn) do
    conn.method
    |> String.downcase()
    |> String.to_atom()
  end

  defp read_full_body(conn, acc \\ []) do
    case Plug.Conn.read_body(conn) do
      {:ok, body, conn} ->
        {:ok, IO.iodata_to_binary(Enum.reverse([body | acc])), conn}

      {:more, chunk, conn} ->
        read_full_body(conn, [chunk | acc])

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp build_path([]), do: "/"

  defp build_path(segments) when is_list(segments) do
    "/" <> Enum.join(segments, "/")
  end

  defp extract_path_segments(params) do
    case Map.get(params, "path") do
      nil -> []
      segments when is_list(segments) -> segments
      segment when is_binary(segment) -> [segment]
    end
  end

  defp build_base_path(path_info, path_segments) do
    take_count = max(length(path_info) - length(path_segments), 0)

    case Enum.take(path_info, take_count) do
      [] -> "/"
      segments -> "/" <> Enum.join(segments, "/")
    end
  end

  defp build_target_uri(host, port, path, ""), do: "http://#{host}:#{port}#{path}"
  defp build_target_uri(host, port, path, query), do: "http://#{host}:#{port}#{path}?#{query}"

  defp append_query(path, ""), do: path
  defp append_query(path, nil), do: path
  defp append_query(path, query), do: path <> "?" <> query

  defp proxy_request_headers(conn, host, port, base_path) do
    {external_host, external_host_with_prefix, external_scheme} = external_connection_parts(conn, base_path)

    conn.req_headers
    |> Enum.reject(fn {key, _} ->
      String.downcase(key) in @hop_by_hop_headers or key == "content-length"
    end)
    |> List.keystore("host", 0, {"host", "#{host}:#{port}"})
    |> List.keystore("x-forwarded-host", 0, {"x-forwarded-host", external_host})
    |> List.keystore("x-external-host", 0, {"x-external-host", external_host_with_prefix})
    |> List.keystore("x-forwarded-proto", 0, {"x-forwarded-proto", external_scheme})
    |> List.keystore("x-external-scheme", 0, {"x-external-scheme", external_scheme})
    |> put_forwarded_for(conn)
  end

  defp build_proxied_request(conn, host, port, path, body, base_path) do
    Finch.build(
      request_method(conn),
      build_target_uri(host, port, path, conn.query_string),
      proxy_request_headers(conn, host, port, base_path),
      body
    )
  end

  defp send_proxied_response(conn, %Finch.Response{status: status, headers: headers, body: body}) do
    conn
    |> put_proxy_resp_headers(headers)
    |> send_resp(status, body)
    |> halt()
  end

  defp put_forwarded_for(headers, conn) do
    forwarded =
      conn.remote_ip
      |> :inet.ntoa()
      |> to_string()

    case List.keyfind(headers, "x-forwarded-for", 0) do
      nil ->
        [{"x-forwarded-for", forwarded} | headers]

      {"x-forwarded-for", existing} ->
        List.keyreplace(headers, "x-forwarded-for", 0, {"x-forwarded-for", existing <> ", " <> forwarded})
    end
  end

  defp put_proxy_resp_headers(conn, headers) do
    headers
    |> Enum.reject(fn {key, _} -> String.downcase(key) in @hop_by_hop_headers end)
    |> Enum.reduce(conn, fn {key, value}, acc -> Plug.Conn.put_resp_header(acc, key, value) end)
  end

  defp websocket_headers(conn, base_path) do
    forwarding_headers(conn, base_path) ++
      Enum.filter(conn.req_headers, fn {key, _} -> String.downcase(key) in ["sec-websocket-protocol", "origin"] end)
  end

  defp forwarding_headers(conn, base_path) do
    {external_host, external_host_with_prefix, external_scheme} = external_connection_parts(conn, base_path)

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
    external_host =
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

        host_header ->
          host_header
      end

    external_scheme = if conn.scheme == :https, do: "https", else: "http"

    external_host_with_prefix =
      case base_path do
        "/" -> external_host
        base -> external_host <> base
      end

    {external_host, external_host_with_prefix, external_scheme}
  end
end
