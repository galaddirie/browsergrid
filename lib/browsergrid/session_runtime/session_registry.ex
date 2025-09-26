defmodule Browsergrid.SessionRuntime.SessionRegistry do
  @moduledoc """
  Global session registry backed by `Horde.Registry`.
  """
  use Horde.Registry

  alias Browsergrid.SessionRuntime

  def start_link(opts) do
    base_opts = [
      keys: :unique,
      name: __MODULE__,
      members: SessionRuntime.horde_members(:registry)
    ]

    Horde.Registry.start_link(Keyword.merge(base_opts, opts))
  end

  @impl true
  def init(opts) do
    base_opts = [keys: :unique, members: SessionRuntime.horde_members(:registry)]
    {:ok, Keyword.merge(base_opts, opts)}
  end
end
