defmodule BrowsergridWeb.SessionProxyController do
  use BrowsergridWeb, :controller

  alias Browsergrid.SessionRuntime

  require Logger

  @hop_by_hop_headers ~w(connection keep-alive proxy-authenticate proxy-authorization te trailers transfer-encoding upgrade)

  def proxy(conn, %{"id" => session_id} = params) do
    path = build_path(Map.get(params, "path", []))

    with {:ok, %{host: host, port: port}} <- SessionRuntime.upstream_endpoint(session_id),
         {:ok, body, conn} <- read_full_body(conn),
         request =
           Finch.build(
             request_method(conn),
             build_target_uri(host, port, path, conn.query_string),
             proxy_request_headers(conn, host, port),
             body
           ),
         {:ok, %Finch.Response{status: status, headers: headers, body: response_body}} <-
           Finch.request(request, Browsergrid.Finch) do
      conn
      |> put_proxy_resp_headers(headers)
      |> send_resp(status, response_body)
      |> halt()
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

  def websocket(conn, %{"id" => session_id} = params) do
    target = Map.get(params, "target", "/")

    case SessionRuntime.upstream_endpoint(session_id) do
      {:ok, %{host: host, port: port}} ->
        state = %{
          session_id: session_id,
          host: host,
          port: port,
          target: target,
          headers: websocket_headers(conn)
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

  defp build_target_uri(host, port, path, ""), do: "http://#{host}:#{port}#{path}"
  defp build_target_uri(host, port, path, query), do: "http://#{host}:#{port}#{path}?#{query}"

  defp proxy_request_headers(conn, host, port) do
    conn.req_headers
    |> Enum.reject(fn {key, _} -> String.downcase(key) in @hop_by_hop_headers or key == "content-length" end)
    |> List.keystore("host", 0, {"host", "#{host}:#{port}"})
    |> put_forwarded_for(conn)
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

  defp websocket_headers(conn) do
    Enum.filter(conn.req_headers, fn {key, _} -> String.downcase(key) in ["sec-websocket-protocol", "origin"] end)
  end
end
