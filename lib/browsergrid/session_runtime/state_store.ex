defmodule Browsergrid.SessionRuntime.StateStore do
  @moduledoc """
  Delegates snapshot persistence to a configurable adapter (Delta CRDT by default).
  """

  alias Browsergrid.SessionRuntime

  @type session_id :: String.t()
  @type snapshot :: map()

  @callback child_spec(keyword()) :: Supervisor.child_spec()
  @callback put(session_id(), snapshot()) :: :ok | {:error, term()}
  @callback get(session_id()) :: {:ok, snapshot()} | :error
  @callback delete(session_id()) :: :ok
  @callback join_all() :: :ok

  @spec child_spec(keyword()) :: Supervisor.child_spec()
  def child_spec(opts \\ []) do
    adapter().child_spec(adapter_opts(opts))
  end

  @spec put(session_id(), snapshot()) :: :ok | {:error, term()}
  def put(session_id, snapshot) do
    adapter().put(session_id, snapshot)
  end

  @spec get(session_id()) :: {:ok, snapshot()} | :error
  def get(session_id) do
    adapter().get(session_id)
  end

  @spec delete(session_id()) :: :ok
  def delete(session_id) do
    adapter().delete(session_id)
  end

  @spec join_all() :: :ok
  def join_all do
    adapter().join_all()
  end

  defp adapter do
    session_cfg = SessionRuntime.state_store_config()
    Keyword.get(session_cfg, :adapter, Browsergrid.SessionRuntime.StateStore.DeltaCrdt)
  end

  defp adapter_opts(opts) do
    session_cfg = SessionRuntime.state_store_config()
    Keyword.merge(Keyword.get(session_cfg, :adapter_opts, []), opts)
  end
end
