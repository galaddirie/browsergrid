defmodule Browsergrid.SessionRuntime.Browser.Adapters.Default do
  @moduledoc false
  @behaviour Browsergrid.SessionRuntime.Browser.Adapter

  @impl true
  def command_candidates, do: []

  @impl true
  def default_args(_context), do: []

  @impl true
  def default_env(_context), do: []
end
