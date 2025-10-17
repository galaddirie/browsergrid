defmodule Browsergrid.MuxCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require the Mux components.

  It ensures registries are properly started and cleaned up.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      use ExUnit.Case, async: false

      import Browsergrid.MuxCase
    end
  end

  setup _tags do
    # Ensure required registries are started
    ensure_registry_started(Browsergrid.Registry)
    ensure_registry_started(Browsergrid.NodeRuntime.Registry)
    ensure_registry_started(Browsergrid.NodeRuntime.ConnectionRegistry, keys: :duplicate)

    :ok
  end

  @doc """
  Ensures a registry is started with the given options.
  If already started, does nothing.
  """
  def ensure_registry_started(name, opts \\ [keys: :unique]) do
    opts = Keyword.put(opts, :name, name)

    case Registry.start_link(opts) do
      {:ok, pid} ->
        # Don't stop on exit - let it live for other tests
        pid

      {:error, {:already_started, pid}} ->
        pid
    end
  end

  @doc """
  Creates a unique session ID for testing
  """
  def unique_session_id do
    "test-session-#{System.unique_integer([:positive])}"
  end

  @doc """
  Creates test session options
  """
  def test_session_opts(overrides \\ []) do
    defaults = [
      session_id: unique_session_id(),
      browser_port: 9222,
      # Use consistent port for tests
      mux_port: 8080
    ]

    Keyword.merge(defaults, overrides)
  end
end
