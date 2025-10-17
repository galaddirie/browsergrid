defmodule Browsergrid.Telemetry.MetricsTest do
  use Browsergrid.DataCase, async: false

  alias Browsergrid.Repo
  alias Browsergrid.Sessions.Session
  alias Browsergrid.Telemetry.Metrics

  test "measure_active_sessions emits counts by type" do
    handler_id = make_ref()
    test_pid = self()

    :telemetry.attach(
      handler_id,
      [:browsergrid, :session, :active],
      fn _event, %{count: count}, %{browser_type: type}, _config ->
        send(test_pid, {:metric, type, count})
      end,
      nil
    )

    {:ok, _} = %{"browser_type" => "chrome"} |> Session.create_changeset() |> Repo.insert()
    {:ok, _} = %{"browser_type" => "chrome"} |> Session.create_changeset() |> Repo.insert()
    {:ok, _} = %{"browser_type" => "chromium"} |> Session.create_changeset() |> Repo.insert()

    Metrics.measure_active_sessions()

    assert_receive {:metric, :chrome, 2}
    assert_receive {:metric, :chromium, 1}

    :telemetry.detach(handler_id)
  end

  test "measure_system_metrics emits keys" do
    handler_id = make_ref()
    test_pid = self()

    :telemetry.attach(
      handler_id,
      [:browsergrid, :system, :metrics],
      fn _event, measurements, _meta, _config ->
        send(test_pid, {:sys, measurements})
      end,
      nil
    )

    Metrics.measure_system_metrics()
    assert_receive {:sys, %{memory_bytes: mem, uptime_ms: up, cpu_percent: cpu}}
    assert is_integer(mem)
    assert is_integer(up)
    assert is_number(cpu)

    :telemetry.detach(handler_id)
  end
end
