defmodule Browsergrid.SessionRuntime.SessionTest do
  use ExUnit.Case, async: false

  alias Browsergrid.SessionRuntime.PortAllocator
  alias Browsergrid.SessionRuntime.Session
  alias Browsergrid.SessionRuntime.Session.State
  alias Browsergrid.SessionRuntime.StateStore

  @port_range 55_000..56_000

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
      assert snapshot["metadata"]["browser_type"] == :chrome
      assert snapshot["owner"] == owner
      assert snapshot["limits"] == limits
      assert snapshot["ready"]
      assert snapshot["port"] in @port_range
      assert snapshot["browser_port"] in @port_range
      assert snapshot["browser_type"] == :chrome
      assert File.dir?(snapshot["profile_dir"])

      assert {:ok, port} = PortAllocator.lookup(session_id)
      assert port == snapshot["port"]

      browser_key = session_id <> "-browser"
      assert {:ok, browser_port} = PortAllocator.lookup(browser_key)
      assert browser_port == snapshot["browser_port"]

      assert {:ok, description} = GenServer.call(pid, :describe)
      assert description.id == session_id
      assert description.ready?
      assert description.port == snapshot["port"]
      assert description.browser_port == snapshot["browser_port"]
      assert description.browser_type == :chrome
      assert description.node == Node.self()
      assert %DateTime{} = description.started_at
      assert %DateTime{} = description.checkpoint_at

      assert %State{browser_type: :chrome} = :sys.get_state(pid)
    end

    test "rehydrates snapshot data and merges options" do
      session_id = unique_session_id()
      on_exit(fn -> cleanup_session(session_id) end)

      port = Enum.random(@port_range)
      profile_dir = Path.join(System.tmp_dir!(), "browsergrid-profile-#{session_id}")
      browser_port =
        if port >= @port_range.last do
          port - 1
        else
          port + 1
        end

      seed_snapshot =
        %{
          "id" => session_id,
          "node" => Atom.to_string(Node.self()),
          "port" => port,
          "browser_port" => browser_port,
          "browser_type" => "chromium",
          "profile_dir" => profile_dir,
          "profile_snapshot" => "s3://bucket/snap"
        }
        |> Map.put("metadata", %{"from_snapshot" => true, "override" => "old"})
        |> Map.put("owner", %{"account_id" => "from_snapshot"})
        |> Map.put("limits", %{"max_runtime_ms" => 60_000})
        |> Map.put("ready", false)
        |> Map.put("last_seen_at", DateTime.utc_now())
        |> Map.put("updated_at", DateTime.utc_now())

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
      assert state.port == port
      assert state.browser_port == browser_port
      assert state.profile_dir == profile_dir
      assert state.profile_snapshot == "s3://bucket/snap"
      assert state.metadata["from_snapshot"]
      assert state.metadata["override"] == "new"
      assert state.metadata["extra"]
      assert state.owner == %{"account_id" => "from_snapshot"}
      assert state.limits["max_runtime_ms"] == 60_000
      assert state.limits["idle_timeout_ms"] == 30_000
      assert state.browser_type == :chrome

      snapshot = await_snapshot(session_id)
      assert snapshot["port"] == port
      assert snapshot["browser_port"] == browser_port
      assert snapshot["browser_type"] == :chrome
      assert snapshot["metadata"]["override"] == "new"
      assert snapshot["metadata"]["extra"]
      assert snapshot["limits"]["idle_timeout_ms"] == 30_000

      assert {:ok, browser_port} == PortAllocator.lookup(session_id <> "-browser")
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

    test "terminate releases port and persists final snapshot" do
      session_id = unique_session_id()
      on_exit(fn -> cleanup_session(session_id) end)

      pid = start_supervised!({Session, session_id: session_id})

      GenServer.cast(pid, {:update_metadata, fn meta -> Map.put(meta, "final", true) end})

      snapshot_before = await_snapshot(session_id)
      port = snapshot_before["port"]

      :ok = GenServer.stop(pid, :normal)

      refute Process.alive?(pid)

      snapshot_after = await_snapshot(session_id)
      assert snapshot_after["metadata"]["final"]

      assert :error == PortAllocator.lookup(session_id)
      assert :error == PortAllocator.lookup(session_id <> "-browser")
      assert snapshot_after["port"] == port
    end

    test "restarts cdp process when it exits" do
      session_id = unique_session_id()
      on_exit(fn -> cleanup_session(session_id) end)

      pid = start_supervised!({Session, session_id: session_id})
      %State{cdp: %{pid: cdp_pid}} = :sys.get_state(pid)

      Process.exit(cdp_pid, :normal)

      new_state =
        await_state(pid, fn
          %State{cdp: %{pid: new_pid}, ready?: true, restart_attempts: 0} = state when new_pid != cdp_pid ->
            {:ok, state}

          _ ->
            :retry
        end)

      assert %State{} = new_state
      assert new_state.ready?
    end

    test "stores provided cdp options in state" do
      session_id = unique_session_id()
      on_exit(fn -> cleanup_session(session_id) end)

      cdp_opts = [browser_url: "ws://browsermux/devtools/browser", frontend_url: "http://frontend"]

      pid = start_supervised!({Session, session_id: session_id, cdp: cdp_opts})

      %State{cdp_opts: stored_opts} = :sys.get_state(pid)

      # Keyword equality ignores ordering differences
      assert Keyword.equal?(stored_opts, cdp_opts)
    end

    test "computes browser url when not provided" do
      session_id = unique_session_id()
      on_exit(fn -> cleanup_session(session_id) end)

      pid = start_supervised!({Session, session_id: session_id})

      %State{cdp_opts: stored_opts, browser_port: browser_port, browser_type: :chrome} =
        :sys.get_state(pid)

      expected_url = "ws://127.0.0.1:#{browser_port}/devtools/browser"
      assert Keyword.get(stored_opts, :browser_url) == expected_url
    end
  end

  defp unique_session_id do
    "session-#{System.unique_integer([:positive])}"
  end

  defp cleanup_session(session_id) do
    PortAllocator.release(session_id)
    PortAllocator.release(session_id <> "-browser")
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

  defp await_state(pid, fun, attempts \\ 50)
  defp await_state(_pid, _fun, 0), do: flunk("state not available")

  defp await_state(pid, fun, attempts) do
    state = :sys.get_state(pid)

    case fun.(state) do
      {:ok, value} ->
        value

      :retry ->
        Process.sleep(50)
        await_state(pid, fun, attempts - 1)
    end
  end
end
