defmodule Browsergrid.SessionRuntime.PortAllocator do
  @moduledoc """
  Per-node port allocator for local CDP processes.
  """
  use GenServer

  alias Browsergrid.SessionRuntime

  require Logger

  @type session_id :: String.t()
  @type tcp_port :: non_neg_integer()

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Lease a port for the given session.
  """
  @spec lease(session_id(), keyword()) :: {:ok, tcp_port()} | {:error, :no_ports_available | :out_of_range}
  def lease(session_id, opts \\ []) do
    GenServer.call(__MODULE__, {:lease, session_id, opts})
  end

  @doc """
  Release a previously leased port.
  """
  @spec release(session_id()) :: :ok
  def release(session_id) do
    GenServer.cast(__MODULE__, {:release, session_id})
  end

  @doc """
  Lookup the port assigned to the session.
  """
  @spec lookup(session_id()) :: {:ok, tcp_port()} | :error
  def lookup(session_id) do
    GenServer.call(__MODULE__, {:lookup, session_id})
  end

  @impl true
  def init(opts) do
    port_range = opts[:port_range] || SessionRuntime.port_range()

    ports =
      port_range
      |> Enum.to_list()
      |> Enum.shuffle()

    state = %{
      available: ports,
      assigned: %{},
      reverse: %{},
      port_range: port_range
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:lease, session_id, opts}, _from, state) do
    preferred = opts[:preferred_port]

    cond do
      Map.has_key?(state.assigned, session_id) ->
        port = Map.fetch!(state.assigned, session_id)
        {:reply, {:ok, port}, state}

      preferred && allocated?(state, preferred) ->
        {:reply, {:error, :out_of_range}, state}

      preferred && in_range?(preferred, state.port_range) && available?(state, preferred) ->
        {:reply, {:ok, preferred}, allocate(session_id, preferred, state)}

      true ->
        case state.available do
          [port | rest] ->
            state = allocate(%{state | available: rest}, session_id, port)
            {:reply, {:ok, port}, state}

          [] ->
            {:reply, {:error, :no_ports_available}, state}
        end
    end
  end

  def handle_call({:lookup, session_id}, _from, state) do
    case Map.fetch(state.assigned, session_id) do
      {:ok, port} -> {:reply, {:ok, port}, state}
      :error -> {:reply, :error, state}
    end
  end

  @impl true
  def handle_cast({:release, session_id}, state) do
    case Map.pop(state.assigned, session_id) do
      {nil, _assigned} ->
        {:noreply, state}

      {port, assigned} ->
        reverse = Map.delete(state.reverse, port)
        available = [port | state.available]
        {:noreply, %{state | assigned: assigned, reverse: reverse, available: available}}
    end
  end

  defp allocate(session_id, port, state) do
    assigned = Map.put(state.assigned, session_id, port)
    reverse = Map.put(state.reverse, port, session_id)
    %{state | assigned: assigned, reverse: reverse, available: List.delete(state.available, port)}
  end

  defp available?(state, port), do: not Map.has_key?(state.reverse, port)

  defp allocated?(state, port) do
    not in_range?(port, state.port_range) or Map.has_key?(state.reverse, port)
  end

  defp in_range?(port, %Range{first: first, last: last, step: step}) do
    step = if step == 0, do: 1, else: step

    cond do
      step > 0 -> port >= first and port <= last and rem(port - first, step) == 0
      step < 0 -> port <= first and port >= last and rem(first - port, abs(step)) == 0
      true -> false
    end
  end
end
