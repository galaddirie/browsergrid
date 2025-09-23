# lib/browsergrid/telemetry/metrics.ex
defmodule Browsergrid.Telemetry.Metrics do
  @moduledoc """
  Telemetry metrics for monitoring browser grid at scale.
  Tracks session lifecycle, resource usage, and performance.
  """
  use Supervisor
  import Telemetry.Metrics

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    children = [
      {:telemetry_poller,
       measurements: periodic_measurements(),
       period: :timer.seconds(10)},

      {TelemetryMetricsPrometheus,
       metrics: metrics(),
       port: 9568,
       path: "/metrics",
       name: :prometheus_metrics}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def metrics do
    [
      # Session metrics
      counter("browsergrid.session.created.count",
        tags: [:browser_type],
        description: "Total number of sessions created"
      ),

      counter("browsergrid.session.failed.count",
        tags: [:browser_type, :reason],
        description: "Total number of failed session creations"
      ),

      counter("browsergrid.session.stopped.count",
        tags: [:browser_type],
        description: "Total number of sessions stopped"
      ),

      distribution("browsergrid.session.startup.duration",
        tags: [:browser_type],
        unit: {:native, :millisecond},
        description: "Time to start a browser session",
        reporter_options: [
          buckets: [10, 50, 100, 250, 500, 1000, 2500, 5000, 10000]
        ]
      ),

      last_value("browsergrid.session.active.count",
        tags: [:browser_type],
        description: "Currently active sessions"
      ),



      # System metrics (consolidated)
      last_value("browsergrid.system.memory.bytes",
        unit: :byte,
        description: "System memory usage"
      ),

      last_value("browsergrid.system.cpu.percent",
        unit: :percent,
        description: "System CPU usage"
      ),

      last_value("browsergrid.system.uptime.ms",
        unit: {:native, :millisecond},
        description: "System uptime"
      ),

      # Generic browser metrics
      counter("browsergrid.browser.process.started.count",
        tags: [:browser_type],
        description: "Number of browser processes started"
      ),

      counter("browsergrid.browser.process.failed.count",
        tags: [:browser_type],
        description: "Number of browser process start failures"
      ),

      counter("browsergrid.browser.session.ready.count",
        tags: [:browser_type],
        description: "Number of times browser sessions became ready"
      ),

      counter("browsergrid.browser.session.failed.count",
        tags: [:browser_type],
        description: "Number of browser session failures"
      )
    ]
  end

  defp periodic_measurements do
    [
      {__MODULE__, :measure_active_sessions, []},
      {__MODULE__, :measure_system_metrics, []}
    ]
  end

  def measure_active_sessions do
    sessions = Browsergrid.Sessions.list_sessions()

    sessions
    |> Enum.group_by(& &1.browser_type)
    |> Enum.each(fn {browser_type, type_sessions} ->
      count = length(type_sessions)

      :telemetry.execute(
        [:browsergrid, :session, :active],
        %{count: count},
        %{browser_type: browser_type}
      )
    end)
  end



  def measure_system_metrics do
    memory = :erlang.memory(:total)
    uptime_ms = :erlang.statistics(:wall_clock) |> elem(0)
    cpu_usage = get_cpu_usage()

    :telemetry.execute(
      [:browsergrid, :system, :metrics],
      %{
        memory_bytes: memory,
        uptime_ms: uptime_ms,
        cpu_percent: cpu_usage
      },
      %{}
    )
  end



  defp get_cpu_usage do
    try do
      {user_time, system_time} = :erlang.statistics(:runtime)
      total_cpu_time = user_time + system_time
      wall_time = :erlang.statistics(:wall_clock) |> elem(0)

      if wall_time > 0 do
        (total_cpu_time / wall_time) * 100
      else
        0
      end
    rescue
      _ -> 0
    end
  end
end
