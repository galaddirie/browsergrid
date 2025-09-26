defmodule Browsergrid.SessionRuntime.SessionSupervisor do
  @moduledoc """
  Distributed session supervisor using `Horde.DynamicSupervisor`.
  """
  use Horde.DynamicSupervisor

  alias Browsergrid.SessionRuntime

  def start_link(opts) do
    base_opts = [name: __MODULE__, members: SessionRuntime.horde_members(:supervisor)]
    Horde.DynamicSupervisor.start_link(__MODULE__, Keyword.merge(base_opts, opts), name: __MODULE__)
  end

  @impl true
  def init(opts) do
    strategy = Keyword.get(opts, :strategy, :one_for_one)

    Horde.DynamicSupervisor.init(
      strategy: strategy,
      members: SessionRuntime.horde_members(:supervisor)
    )
  end
end
