defmodule Browsergrid.Connect.Socket do
  @moduledoc """
  WebSock adapter that binds a claimed pooled session to a client WebSocket.
  """
  @behaviour WebSock

  alias Browsergrid.Connect
  alias Browsergrid.Connect.SessionInfo
  alias BrowsergridWeb.SessionProxySocket.Client

  require Logger

  @impl true
  def init(%{token: token, target_path: target, query: query, headers: headers} = init_state) do
    Process.flag(:trap_exit, true)

    case Connect.attach_websocket(token, self()) do
      {:ok, %SessionInfo{endpoint: endpoint} = session} ->
        case start_upstream(endpoint, target, query, headers) do
          {:ok, client_pid} ->
            {:ok,
             %{
               token: token,
               session_id: session.id,
               endpoint: endpoint,
               client: client_pid,
               connected?: false,
               pending: [],
               target: target,
               query: query,
               headers: headers
             }}

          {:error, reason} ->
            Logger.error("connect upstream websocket failed", session_id: session.id, reason: inspect(reason))
            Connect.release(token, {:upstream_start_failed, reason})
            {:stop, {:error, reason}, init_state}
        end

      {:error, reason} ->
        Logger.warning("connect websocket attach failed", reason: inspect(reason))
        {:stop, {:error, reason}, init_state}
    end
  end

  @impl true
  def handle_in({payload, [opcode: opcode]}, %{connected?: false} = state) do
    frame = to_remote_frame(opcode, payload)
    {:ok, %{state | pending: [frame | state.pending]}}
  end

  def handle_in({payload, [opcode: opcode]}, state) do
    frame = to_remote_frame(opcode, payload)

    case Client.send_frame(state.client, frame) do
      :ok ->
        {:ok, state}

      {:error, reason} ->
        Logger.error("failed to forward connect websocket frame", reason: inspect(reason))
        {:stop, {:error, reason}, state}
    end
  end

  @impl true
  def handle_control({payload, [opcode: opcode]}, state) do
    handle_in({payload, [opcode: opcode]}, state)
  end

  @impl true
  def handle_info(:remote_connected, state) do
    state.pending
    |> Enum.reverse()
    |> Enum.each(&Client.send_frame(state.client, &1))

    {:ok, %{state | connected?: true, pending: []}}
  end

  def handle_info({:remote_frame, frame}, state) do
    {:push, frame, state}
  end

  def handle_info({:remote_disconnect, reason}, state) do
    {:stop, {:remote, reason}, state}
  end

  def handle_info({:remote_error, reason}, state) do
    {:stop, {:error, reason}, state}
  end

  def handle_info({:remote_info, message}, state) do
    Logger.debug("connect upstream info", message: inspect(message))
    {:ok, state}
  end

  def handle_info({:EXIT, pid, reason}, %{client: pid} = state) do
    {:stop, {:remote, reason}, state}
  end

  def handle_info(_message, state), do: {:ok, state}

  @impl true
  def terminate(reason, state) do
    Logger.info("connect websocket terminating", session_id: Map.get(state, :session_id), reason: inspect(reason))
    maybe_stop_client(state)
    maybe_release(state, reason)
    :ok
  end

  defp start_upstream(%{host: host, port: port}, target, query, headers) do
    url = build_ws_url(host, port, target, query)
    Client.start_link(url, self(), headers)
  end

  defp build_ws_url(host, port, target, ""), do: "ws://#{host}:#{port}#{target}"
  defp build_ws_url(host, port, target, query), do: "ws://#{host}:#{port}#{target}?#{query}"

  defp to_remote_frame(:text, payload), do: {:text, payload}
  defp to_remote_frame(:binary, payload), do: {:binary, payload}
  defp to_remote_frame(:ping, payload), do: {:ping, payload}
  defp to_remote_frame(:pong, payload), do: {:pong, payload}
  defp to_remote_frame(_other, payload), do: {:binary, payload}

  defp maybe_stop_client(%{client: pid}) when is_pid(pid) do
    if Process.alive?(pid), do: Process.exit(pid, :normal)
    :ok
  end

  defp maybe_stop_client(_), do: :ok

  defp maybe_release(%{token: token}, reason) when is_binary(token) do
    Connect.release(token, {:websocket_terminate, reason})
  end

  defp maybe_release(_, _reason), do: :ok
end
