defmodule Browsergrid.SessionRuntime.Supervisor do
  @moduledoc """
  Supervision tree for the session runtime components.
  """
  use Supervisor

  alias Browsergrid.SessionRuntime
  alias Browsergrid.SessionRuntime.NodeListener
  alias Browsergrid.SessionRuntime.PortAllocator
  alias Browsergrid.SessionRuntime.SessionRegistry
  alias Browsergrid.SessionRuntime.SessionSupervisor
  alias Browsergrid.SessionRuntime.StateStore

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children = [
      StateStore.child_spec([]),
      {PortAllocator, [port_range: SessionRuntime.port_range()]},
      {SessionRegistry, []},
      {SessionSupervisor, []},
      {NodeListener, []}
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
