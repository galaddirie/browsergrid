defmodule Browsergrid.SessionRuntime.Browser.Adapter do
  @moduledoc """
  Behaviour describing browser-specific defaults for the session runtime.
  """

  @callback command_candidates() :: [String.t()]
  @callback default_args(map()) :: list()
  @callback default_env(map()) :: keyword()
end
