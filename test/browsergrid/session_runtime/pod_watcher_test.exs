defmodule Browsergrid.SessionRuntime.PodWatcherTest do
  use Browsergrid.DataCase, async: true

  alias Browsergrid.Factory
  alias Browsergrid.Routing
  alias Browsergrid.SessionRuntime.PodWatcher
  alias Browsergrid.Sessions

  describe "process_event/1" do
    test "marks session as failed and removes route on pod deletion" do
      session = Factory.insert(:session, status: :running)
      Factory.insert(:route, id: session.id)

      event = %{
        "type" => "DELETED",
        "object" => %{
          "metadata" => %{
            "labels" => %{"browsergrid/session-id" => session.id},
            "namespace" => "browsergrid"
          },
          "status" => %{"phase" => "Failed"}
        }
      }

      :ok = PodWatcher.process_event(event)

      assert {:ok, updated} = Sessions.get_session(session.id)
      assert updated.status == :error
      assert Routing.get_route(session.id) == nil
    end

    test "marks session as failed when container enters CrashLoopBackOff" do
      session = Factory.insert(:session, status: :running)

      event = %{
        "type" => "MODIFIED",
        "object" => %{
          "metadata" => %{
            "labels" => %{"browsergrid/session-id" => session.id},
            "namespace" => "browsergrid"
          },
          "status" => %{
            "phase" => "Running",
            "containerStatuses" => [
              %{
                "state" => %{
                  "waiting" => %{"reason" => "CrashLoopBackOff"}
                }
              }
            ]
          }
        }
      }

      :ok = PodWatcher.process_event(event)

      assert {:ok, updated} = Sessions.get_session(session.id)
      assert updated.status == :error
    end
  end
end
