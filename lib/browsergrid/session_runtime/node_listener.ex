defmodule Browsergrid.SessionRuntime.NodeListener do
  @moduledoc """
  Tracks nodeup/nodedown events and keeps Horde + state store membership in sync.
  """
  use GenServer

  alias Browsergrid.SessionRuntime
  alias Browsergrid.SessionRuntime.StateStore

  require Logger

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    :ok = :net_kernel.monitor_nodes(true, node_type: :all)
    schedule_sync(0)
    {:ok, %{last_sync: nil}}
  end

  @impl true
  def handle_info({:nodeup, node, _info}, state) do
    Logger.info("node up detected: #{inspect(node)}")
    resync()
    {:noreply, state}
  end

  def handle_info({:nodedown, node, _info}, state) do
    Logger.warning("node down detected: #{inspect(node)}")
    resync()
    {:noreply, state}
  end

  def handle_info(:sync, state) do
    resync()
    schedule_sync(5_000)
    {:noreply, %{state | last_sync: System.system_time(:millisecond)}}
  end

  defp schedule_sync(interval_ms) do
    Process.send_after(self(), :sync, interval_ms)
  end

  defp resync do
    SessionRuntime.sync_horde_membership()
    StateStore.join_all()
  rescue
    exception ->
      Logger.error("session runtime resync failed: #{Exception.message(exception)}")
      :ok
  end
end
