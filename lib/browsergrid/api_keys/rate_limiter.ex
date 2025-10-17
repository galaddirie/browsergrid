defmodule Browsergrid.ApiKeys.RateLimiter do
  @moduledoc """
  Simple per-key token bucket limiter backed by ETS.
  """

  use GenServer

  @table :browsergrid_api_key_limits


  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))
  end

  def check(key, opts \\ []) do
    GenServer.call(name(opts), {:check, key, opts})
  end

  def reset(key, opts \\ []) do
    GenServer.call(name(opts), {:reset, key})
  end

  defp name(opts), do: Keyword.get(opts, :name, __MODULE__)


  @impl true
  def init(opts) do
    table_opts = [:named_table, :set, :public, read_concurrency: true, write_concurrency: true]

    case :ets.whereis(@table) do
      :undefined -> :ets.new(@table, table_opts)
      _ -> :ets.delete_all_objects(@table)
    end

    state = %{
      limit: Keyword.get(opts, :limit, default_limit()),
      interval_ms: Keyword.get(opts, :interval_ms, default_interval())
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:check, key, opts}, _from, state) do
    limit = Keyword.get(opts, :limit, state.limit)
    interval_ms = Keyword.get(opts, :interval_ms, state.interval_ms)
    now = System.system_time(:millisecond)

    reply =
      case :ets.lookup(@table, key) do
        [] ->
          :ets.insert(@table, {key, now, 1, interval_ms})
          {:ok, %{remaining: limit - 1, reset_at: now + interval_ms}}

        [{^key, window_start, count, stored_interval}] ->
          effective_interval = stored_interval || interval_ms

          cond do
            window_start + effective_interval <= now ->
              :ets.insert(@table, {key, now, 1, interval_ms})
              {:ok, %{remaining: limit - 1, reset_at: now + interval_ms}}

            count < limit ->
              :ets.insert(@table, {key, window_start, count + 1, effective_interval})
              {:ok, %{remaining: limit - (count + 1), reset_at: window_start + effective_interval}}

            true ->
              retry_after = max(window_start + effective_interval - now, 0)
              {:error, :rate_limited, %{retry_after_ms: retry_after}}
          end
      end

    {:reply, reply, state}
  end

  @impl true
  def handle_call({:reset, key}, _from, state) do
    :ets.delete(@table, key)
    {:reply, :ok, state}
  end

  defp default_limit do
    :browsergrid
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(:limit, 120)
  end

  defp default_interval do
    :browsergrid
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(:interval_ms, 60_000)
  end
end
