defmodule Browsergrid.Connect.Supervisor do
  @moduledoc """
  Top-level supervisor for the Connect subsystem. Starts the idle pool when
  enabled via configuration.
  """
  use Supervisor

  alias Browsergrid.Connect.Config
  alias Browsergrid.Connect.IdlePool

  require Logger

  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    if Config.enabled?() do
      pool_opts =
        Keyword.merge(
          [
            pool_size: Config.pool_size(),
            claim_timeout_ms: Config.claim_timeout_ms(),
            session_prefix: Config.session_prefix(),
            session_metadata: Config.session_metadata(),
            browser_type: Config.browser_type()
          ],
          opts
        )

      children = [
        {IdlePool, pool_opts}
      ]

      Supervisor.init(children, strategy: :one_for_one)
    else
      Logger.info("Connect subsystem disabled")
      Supervisor.init([], strategy: :one_for_one)
    end
  end
end
