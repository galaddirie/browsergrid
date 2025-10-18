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
      conn
      |> send_resp(:gone, "websocket upgrade no longer supported")
      |> halt()
    else
      handle_http(conn, session_id, path, base_path)
    end
  end

  defp websocket_upgrade?(conn) do
    conn
    |> get_req_header("upgrade")
    |> Enum.any?(fn header -> String.downcase(header) == "websocket" end)
  end

  defp handle_http(conn, session_id, path, base_path) do
    case SessionRuntime.upstream_endpoint(session_id) do
      {:ok, %{host: host, port: port}} ->
        if stream_request?(conn, path) do
          stream_proxied_response(conn, host, port, path, base_path)
        else
          with {:ok, body, conn} <- read_full_body(conn),
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

      {:error, :not_found} ->
        send_resp(conn, 404, "session not running")

      {:error, reason} ->
        Logger.error("proxy failed: #{inspect(reason)}")
        send_resp(conn, 500, "proxy failure")
    end
  end

  defp stream_request?(conn, path) do
    request_method(conn) == :get and path == "/stream"
  end

  defp stream_proxied_response(conn, host, port, path, base_path) do
    request =
      Finch.build(
        :get,
        build_target_uri(host, port, path, conn.query_string),
        proxy_request_headers(conn, host, port, base_path)
      )

    initial_state = %{
      conn: conn,
      status: nil,
      chunked?: false
    }

    case Finch.stream(request, Browsergrid.Finch, initial_state, &stream_chunk/2, receive_timeout: :infinity) do
      {:ok, %{conn: streamed_conn}} ->
        Plug.Conn.halt(streamed_conn)

      {:error, reason, %{conn: streamed_conn, chunked?: true}} ->
        Logger.error("stream proxy failed after starting response: #{inspect(reason)}")
        Plug.Conn.halt(streamed_conn)

      {:error, reason, %{conn: streamed_conn}} ->
        Logger.error("stream proxy failed: #{inspect(reason)}")

        streamed_conn
        |> send_resp(502, "upstream error")
        |> Plug.Conn.halt()
    end
  end

  defp stream_chunk(event, {:cont, inner_state}) do
    stream_chunk(event, inner_state)
  end

  defp stream_chunk(event, {:halt, inner_state}) do
    stream_chunk(event, inner_state)
  end

  defp stream_chunk({:status, status}, state) do
    {:cont, %{state | status: status}}
  end

  defp stream_chunk({:headers, headers}, %{conn: conn, status: status, chunked?: chunked?} = state) do
    conn =
      conn
      |> put_proxy_resp_headers(headers)
      |> Plug.Conn.delete_resp_header("content-length")
      |> Plug.Conn.delete_resp_header("transfer-encoding")
      |> put_cors_headers()

    conn =
      if chunked? do
        conn
      else
        Plug.Conn.send_chunked(conn, status || 200)
      end

    {:cont, %{state | conn: conn, chunked?: true}}
  end

  defp stream_chunk({:data, data}, %{conn: conn} = state) do
    case Plug.Conn.chunk(conn, data) do
      {:ok, updated_conn} ->
        {:cont, %{state | conn: updated_conn}}

      {:error, :closed} ->
        {:halt, %{state | conn: conn}}

      {:error, reason} ->
        Logger.warning("failed to stream chunk: #{inspect(reason)}")
        {:halt, %{state | conn: conn}}
    end
  end

  defp stream_chunk({:trailers, trailers}, %{conn: conn} = state) do
    conn =
      Enum.reduce(trailers, conn, fn {key, value}, acc ->
        Plug.Conn.put_resp_header(acc, key, value)
      end)

    {:cont, %{state | conn: conn}}
  end

  defp stream_chunk(:done, state), do: {:cont, state}

  defp stream_chunk({:error, reason}, %{conn: conn} = state) do
    Logger.warning("stream error", reason: inspect(reason))
    {:halt, %{state | conn: conn}}
  end

  defp stream_chunk(other, state) do
    Logger.debug("Unhandled stream event: #{inspect(other)}, state: #{inspect(state)}")
    {:cont, state}
  end

  defp put_cors_headers(conn) do
    conn
    |> Plug.Conn.put_resp_header("access-control-allow-origin", "*")
    |> Plug.Conn.put_resp_header("access-control-allow-methods", "GET, OPTIONS")
    |> Plug.Conn.put_resp_header("access-control-allow-headers", "Range")
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

  defp proxy_request_headers(conn, host, port, base_path) do
    {external_host, external_host_with_prefix, external_scheme} =
      external_connection_parts(conn, base_path)

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
        List.keyreplace(
          headers,
          "x-forwarded-for",
          0,
          {"x-forwarded-for", existing <> ", " <> forwarded}
        )
    end
  end

  defp put_proxy_resp_headers(conn, headers) do
    headers
    |> Enum.reject(fn {key, _} -> String.downcase(key) in @hop_by_hop_headers end)
    |> Enum.reduce(conn, fn {key, value}, acc -> Plug.Conn.put_resp_header(acc, key, value) end)
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
