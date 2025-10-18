defmodule Browsergrid.SessionPools.Manager do
  @moduledoc """
  Periodically reconciles session pools to maintain the target number of ready sessions.
  """
  use GenServer

  alias Browsergrid.SessionPools

  require Logger

  @default_interval_ms 5_000

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    interval = Keyword.get(opts, :interval_ms, @default_interval_ms)

    SessionPools.ensure_system_pools!()
    schedule_reconcile(interval)

    {:ok, %{interval: interval}}
  end

  @impl true
  def handle_info(:reconcile, %{interval: interval} = state) do
    Enum.each(SessionPools.list_pools(), fn pool ->
      try do
        expired = SessionPools.reap_expired_claims(pool)

        if expired > 0 do
          Logger.info("Reclaimed #{expired} expired sessions from pool #{pool.id}")
        end

        SessionPools.reconcile_pool(pool)
      rescue
        exception ->
          Logger.error("Session pool reconciliation failed: #{Exception.message(exception)}",
            pool_id: pool.id,
            stacktrace: __STACKTRACE__
          )
      end
    end)

    schedule_reconcile(interval)

    {:noreply, state}
  end

  defp schedule_reconcile(interval) do
    Process.send_after(self(), :reconcile, interval)
  end
end
