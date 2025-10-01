defmodule Browsergrid.SessionRuntime.SessionTest do
  use ExUnit.Case, async: false

  alias Browsergrid.SessionRuntime.Session
  alias Browsergrid.SessionRuntime.Session.State
  alias Browsergrid.SessionRuntime.StateStore

  describe "session lifecycle" do
    test "starts session actor and persists snapshot" do
      session_id = unique_session_id()
      on_exit(fn -> cleanup_session(session_id) end)

      metadata = %{"foo" => "bar"}
      owner = %{"account_id" => "acct-1"}
      limits = %{"max_runtime_ms" => 120_000}

      pid = start_supervised!({Session, session_id: session_id, metadata: metadata, owner: owner, limits: limits})

      assert Process.alive?(pid)

      snapshot = await_snapshot(session_id)

      assert snapshot["id"] == session_id
      assert snapshot["node"] == Atom.to_string(Node.self())
      assert Map.get(snapshot["metadata"], "foo") == "bar"
      assert snapshot["owner"] == owner
      assert snapshot["limits"] == limits
      assert snapshot["ready"]
      assert snapshot["browser_type"] == :chrome
      assert File.dir?(snapshot["profile_dir"])
      assert %{"host" => host, "port" => port} = snapshot["endpoint"]
      assert is_binary(host)
      assert is_integer(port)

      assert {:ok, description} = GenServer.call(pid, :describe)
      assert description.id == session_id
      assert description.ready?
      assert description.browser_type == :chrome
      assert description.node == Node.self()
      assert %DateTime{} = description.started_at
      assert %DateTime{} = description.checkpoint_at
      assert %{
               host: ^host,
               port: ^port,
               scheme: "http"
             } = description.endpoint

      assert %State{browser_type: :chrome, endpoint: %{host: ^host, port: ^port}} = :sys.get_state(pid)
    end

    test "rehydrates snapshot data and merges options" do
      session_id = unique_session_id()
      on_exit(fn -> cleanup_session(session_id) end)

      profile_dir = Path.join(System.tmp_dir!(), "browsergrid-profile-#{session_id}")

      seed_snapshot =
        %{
          "id" => session_id,
          "node" => Atom.to_string(Node.self()),
          "browser_type" => "chromium",
          "profile_dir" => profile_dir,
          "profile_snapshot" => "s3://bucket/snap",
          "metadata" => %{"from_snapshot" => true, "override" => "old"},
          "owner" => %{"account_id" => "from_snapshot"},
          "limits" => %{"max_runtime_ms" => 60_000},
          "ready" => false,
          "endpoint" => %{"host" => "10.0.0.1", "port" => 9000},
          "last_seen_at" => DateTime.utc_now(),
          "updated_at" => DateTime.utc_now()
        }

      :ok = StateStore.put(session_id, seed_snapshot)

      pid =
        start_supervised!(
          {Session,
           session_id: session_id,
           metadata: %{"override" => "new", "extra" => true},
           limits: %{"idle_timeout_ms" => 30_000}}
        )

      %State{} = state = :sys.get_state(pid)

      assert state.id == session_id
      assert state.profile_dir == profile_dir
      assert state.profile_snapshot == "s3://bucket/snap"
      assert state.metadata["from_snapshot"]
      assert state.metadata["override"] == "new"
      assert state.metadata["extra"]
      assert state.owner == %{"account_id" => "from_snapshot"}
      assert state.limits["max_runtime_ms"] == 60_000
      assert state.limits["idle_timeout_ms"] == 30_000
      assert state.browser_type == :chrome
      assert %{host: host, port: port} = state.endpoint

      snapshot = await_snapshot(session_id)
      assert snapshot["browser_type"] == :chrome
      assert snapshot["metadata"]["override"] == "new"
      assert snapshot["metadata"]["extra"]
      assert snapshot["limits"]["idle_timeout_ms"] == 30_000
      assert snapshot["endpoint"]["host"] == host
      assert snapshot["endpoint"]["port"] == port
    end

    test "heartbeat updates last_seen_at" do
      session_id = unique_session_id()
      on_exit(fn -> cleanup_session(session_id) end)

      pid = start_supervised!({Session, session_id: session_id})

      snapshot = await_snapshot(session_id)
      initial_seen_at = snapshot["last_seen_at"]
      assert %DateTime{} = initial_seen_at

      GenServer.cast(pid, :heartbeat)

      updated_snapshot = await_snapshot(session_id)
      updated_seen_at = updated_snapshot["last_seen_at"]
      assert DateTime.compare(updated_seen_at, initial_seen_at) in [:gt, :eq]
      assert match?(%DateTime{}, updated_snapshot["updated_at"])
    end

    test "checkpoint flushes metadata to state store" do
      session_id = unique_session_id()
      on_exit(fn -> cleanup_session(session_id) end)

      pid = start_supervised!({Session, session_id: session_id})

      GenServer.cast(pid, {:update_metadata, fn meta -> Map.put(meta, "checkpointed", true) end})

      send(pid, :checkpoint)

      snapshot = await_snapshot(session_id)
      assert snapshot["metadata"]["checkpointed"]
    end

    test "terminate persists final snapshot" do
      session_id = unique_session_id()
      on_exit(fn -> cleanup_session(session_id) end)

      pid = start_supervised!({Session, session_id: session_id})

      GenServer.cast(pid, {:update_metadata, fn meta -> Map.put(meta, "final", true) end})

      snapshot_before = await_snapshot(session_id)

      :ok = GenServer.stop(pid, :normal)

      refute Process.alive?(pid)

      snapshot_after = await_snapshot(session_id)
      assert snapshot_after["metadata"]["final"]
      assert snapshot_after["endpoint"] == snapshot_before["endpoint"]
    end
  end

  defp unique_session_id do
    "session-#{System.unique_integer([:positive])}"
  end

  defp cleanup_session(session_id) do
    StateStore.delete(session_id)
    :ok
  end

  defp await_snapshot(session_id, attempts \\ 50)
  defp await_snapshot(_session_id, 0), do: flunk("snapshot not available")

  defp await_snapshot(session_id, attempts) do
    case StateStore.get(session_id) do
      {:ok, snapshot} ->
        snapshot

      :error ->
        Process.sleep(20)
        await_snapshot(session_id, attempts - 1)
    end
  end
end
