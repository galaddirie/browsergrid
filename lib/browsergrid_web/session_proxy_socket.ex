defmodule BrowsergridWeb.SessionProxySocket do
  @moduledoc """
  WebSock handler that proxies frames between the client and the per-session CDP port.
  """
  @behaviour WebSock

  alias BrowsergridWeb.SessionProxySocket.Client

  require Logger

  def init(%{host: host, port: port, target: target} = state) do
    Process.flag(:trap_exit, true)

    url = build_ws_url(host, port, target)
    headers = Map.get(state, :headers, [])

    case Client.start_link(url, self(), headers) do
      {:ok, pid} ->
        {:ok,
         %{
           client: pid,
           connected?: false,
           pending: [],
           target: target,
           port: port,
           host: host
         }}

      {:error, reason} ->
        Logger.error("failed to start upstream websocket: #{inspect(reason)}")
        {:stop, {:error, reason}, state}
    end
  end

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
        Logger.error("failed to forward websocket frame: #{inspect(reason)}")
        {:stop, {:error, reason}, state}
    end
  end

  def handle_control({payload, [opcode: opcode]}, state) do
    handle_in({payload, [opcode: opcode]}, state)
  end

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

  def handle_info({:EXIT, pid, reason}, %{client: pid} = state) do
    {:stop, {:remote, reason}, state}
  end

  def handle_info(_message, state), do: {:ok, state}

  def terminate(_reason, %{client: pid}) when is_pid(pid) do
    if Process.alive?(pid), do: Process.exit(pid, :normal)
    :ok
  end

  def terminate(_reason, _state), do: :ok

  defp to_remote_frame(:text, payload), do: {:text, payload}
  defp to_remote_frame(:binary, payload), do: {:binary, payload}
  defp to_remote_frame(:ping, payload), do: {:ping, payload}
  defp to_remote_frame(:pong, payload), do: {:pong, payload}
  defp to_remote_frame(_other, payload), do: {:binary, payload}

  defp build_ws_url(host, port, target) do
    {path, query} = split_target(target)
    base = "ws://#{host}:#{port}#{path}"

    case query do
      nil -> base
      qs -> base <> "?" <> qs
    end
  end

  defp split_target(target) when is_binary(target) do
    case String.split(target, "?", parts: 2) do
      [path, query] ->
        {normalize_path(path), query}

      [path] ->
        {normalize_path(path), nil}
    end
  end

  defp normalize_path(""), do: "/"
  defp normalize_path("/" <> _ = path), do: path
  defp normalize_path(path), do: "/" <> path

  defmodule Client do
    @moduledoc false
    use WebSockex

    def start_link(url, parent, headers) do
      WebSockex.start_link(url, __MODULE__, %{parent: parent}, extra_headers: headers)
    end

    @impl true
    def handle_connect(_conn, state) do
      send(state.parent, :remote_connected)
      {:ok, state}
    end

    @impl true
    def handle_frame(frame, state) do
      send(state.parent, {:remote_frame, frame})
      {:ok, state}
    end

    @impl true
    def handle_disconnect(reason, state) do
      send(state.parent, {:remote_disconnect, reason})
      {:ok, state}
    end

    @impl true
    def handle_info(message, state) do
      send(state.parent, {:remote_info, message})
      {:ok, state}
    end

    @impl true
    def terminate(reason, state) do
      send(state.parent, {:remote_error, reason})
      :ok
    end

    def send_frame(pid, frame) do
      WebSockex.send_frame(pid, frame)
    end
  end
end
