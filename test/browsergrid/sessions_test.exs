defmodule Browsergrid.SessionsTest do
  use Browsergrid.DataCase, async: true

  import Mock

  alias Browsergrid.Factory
  alias Browsergrid.Sessions

  describe "list_sessions/1" do
    test "returns all sessions ordered by inserted_at desc" do
      _session1 = Factory.insert(:session, inserted_at: ~N[2024-01-01 10:00:00])
      session2 = Factory.insert(:session, inserted_at: ~N[2024-01-01 11:00:00])
      session3 = Factory.insert(:session, inserted_at: ~N[2024-01-01 09:00:00])

      sessions = Sessions.list_sessions()

      assert length(sessions) == 3
      assert hd(sessions).id == session2.id
      assert List.last(sessions).id == session3.id
    end

    test "preloads profile when preload option is true" do
      profile = Factory.insert(:profile)
      session = Factory.insert(:session, profile_id: profile.id)

      sessions = Sessions.list_sessions(preload: true)
      session_with_profile = Enum.find(sessions, &(&1.id == session.id))

      assert session_with_profile.profile.id == profile.id
    end

    test "does not preload profile by default" do
      profile = Factory.insert(:profile)
      session = Factory.insert(:session, profile_id: profile.id)

      sessions = Sessions.list_sessions()
      session_without_profile = Enum.find(sessions, &(&1.id == session.id))

      assert %Ecto.Association.NotLoaded{} = session_without_profile.profile
    end
  end

  describe "get_session/1" do
    test "returns session when id is valid" do
      session = Factory.insert(:session)

      assert {:ok, found_session} = Sessions.get_session(session.id)
      assert found_session.id == session.id
      assert found_session.name == session.name
    end

    test "returns error when session not found" do
      assert {:error, :not_found} = Sessions.get_session(Ecto.UUID.generate())
    end

    test "returns error when id is invalid UUID" do
      assert {:error, :invalid_id} = Sessions.get_session("invalid-uuid")
    end
  end

  describe "get_session!/1" do
    test "returns session when found" do
      session = Factory.insert(:session)
      found_session = Sessions.get_session!(session.id)

      assert found_session.id == session.id
    end

    test "raises when session not found" do
      assert_raise Ecto.NoResultsError, fn ->
        Sessions.get_session!(Ecto.UUID.generate())
      end
    end
  end

  describe "get_session_with_profile!/1" do
    test "returns session with profile preloaded" do
      profile = Factory.insert(:profile)
      session = Factory.insert(:session, profile_id: profile.id)

      found_session = Sessions.get_session_with_profile!(session.id)

      assert found_session.id == session.id
      assert found_session.profile.id == profile.id
    end
  end

  describe "create_session/1" do
    test "creates session with valid attrs" do
      attrs = %{
        browser_type: :chrome,
        cluster: "test-cluster",
        headless: true,
        timeout: 45
      }

      with_mock Browsergrid.SessionRuntime, [:passthrough],
        ensure_session_started: fn _session_id, _opts -> {:ok, self()} end do
        assert {:ok, session} = Sessions.create_session(attrs)
        assert session.browser_type == :chrome
        # Status changes to running after runtime start
        assert session.status == :running
        assert session.cluster == "test-cluster"
        assert session.headless == true
        assert session.timeout == 45
        assert session.name =~ ~r/Session \d+/
      end
    end

    test "returns error with invalid attrs" do
      attrs = %{browser_type: :invalid_browser}

      assert {:error, changeset} = Sessions.create_session(attrs)
      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).browser_type
    end

    test "sets default name when not provided" do
      attrs = %{browser_type: :chrome}

      with_mock Browsergrid.SessionRuntime, [:passthrough],
        ensure_session_started: fn _session_id, _opts -> {:ok, self()} end do
        {:ok, session} = Sessions.create_session(attrs)
        assert session.name =~ ~r/Session \d+/
      end
    end
  end

  describe "create_session_with_profile/2" do
    test "creates session with profile" do
      profile = Factory.insert(:profile, browser_type: :firefox)
      attrs = %{cluster: "test-cluster"}

      with_mock Browsergrid.SessionRuntime, [:passthrough],
        ensure_session_started: fn _session_id, _opts -> {:ok, self()} end do
        assert {:ok, session} = Sessions.create_session_with_profile(attrs, profile.id)
        assert session.profile_id == profile.id
        # Should match profile
        assert session.browser_type == :firefox
      end
    end
  end

  describe "clone_session/1" do
    test "creates clone with modified name" do
      original =
        Factory.insert(:session,
          name: "Original Session",
          browser_type: :firefox,
          screen: %{"width" => 1280, "height" => 720},
          headless: true,
          timeout: 60
        )

      with_mock Browsergrid.SessionRuntime, [:passthrough],
        ensure_session_started: fn _session_id, _opts -> {:ok, self()} end do
        assert {:ok, clone} = Sessions.clone_session(original)
        assert clone.name == "Original Session (Clone)"
        assert clone.browser_type == :firefox
        assert clone.screen == original.screen
        assert clone.headless == true
        assert clone.timeout == 60
        assert clone.id != original.id
      end
    end
  end

  describe "update_session/2" do
    test "updates session with valid attrs" do
      session = Factory.insert(:session, status: :pending)

      update_attrs = %{
        name: "Updated Name",
        status: :running,
        headless: true
      }

      assert {:ok, updated_session} = Sessions.update_session(session, update_attrs)
      assert updated_session.name == "Updated Name"
      assert updated_session.status == :running
      assert updated_session.headless == true
    end

    test "returns error with invalid attrs" do
      session = Factory.insert(:session)

      assert {:error, changeset} = Sessions.update_session(session, %{browser_type: :invalid})
      refute changeset.valid?
    end
  end

  describe "update_status/2" do
    test "updates session status" do
      session = Factory.insert(:session, status: :pending)

      assert {:ok, updated_session} = Sessions.update_status(session, :running)
      assert updated_session.status == :running
    end
  end

  describe "update_status_by_id/2" do
    test "updates status by id" do
      session = Factory.insert(:session, status: :pending)

      assert {:ok, updated_session} = Sessions.update_status_by_id(session.id, :running)
      assert updated_session.status == :running
    end

    test "returns error when session not found" do
      assert {:error, :not_found} = Sessions.update_status_by_id(Ecto.UUID.generate(), :running)
    end
  end

  describe "delete_session/1" do
    test "deletes session" do
      session = Factory.insert(:session)

      assert {:ok, deleted_session} = Sessions.delete_session(session)
      assert deleted_session.id == session.id

      assert {:error, :not_found} = Sessions.get_session(session.id)
    end
  end

  describe "start_session/1" do
    test "starts session and updates status" do
      session = Factory.insert(:session, status: :pending)

      with_mock Browsergrid.SessionRuntime, [:passthrough],
        ensure_session_started: fn _session_id, _opts -> {:ok, self()} end do
        assert {:ok, started_session} = Sessions.start_session(session)
        assert started_session.status == :running
      end
    end
  end

  describe "stop_session/1" do
    test "stops session and updates status" do
      session = Factory.insert(:session, status: :running)

      assert {:ok, stopped_session} = Sessions.stop_session(session)
      assert stopped_session.status == :stopped
    end
  end

  describe "get_session_info/1" do
    test "returns session info with runtime details" do
      session = Factory.insert(:session)

      assert {:ok, info} = Sessions.get_session_info(session.id)
      assert info.session.id == session.id
      # Runtime might be nil in tests since no actual runtime is started
      assert Map.has_key?(info, :runtime)
    end

    test "returns error when session not found" do
      assert {:error, :not_found} = Sessions.get_session_info(Ecto.UUID.generate())
    end
  end

  describe "get_connection_info/1" do
    test "returns connection info" do
      session = Factory.insert(:session)

      with_mock Browsergrid.SessionRuntime, [:passthrough],
        upstream_endpoint: fn _session_id -> {:ok, %{host: "localhost", port: 9222}} end do
        assert {:ok, %{url: _url, connection: connection}} = Sessions.get_connection_info(session.id)
        assert connection.session == session.id
        assert connection.http_proxy =~ "/sessions/#{session.id}/http"
        assert connection.ws_proxy =~ "/sessions/#{session.id}/ws"
      end
    end

    test "returns error when session not found" do
      assert {:error, :not_found} = Sessions.get_connection_info(Ecto.UUID.generate())
    end
  end

  describe "get_sessions_by_profile/1" do
    test "returns sessions for profile" do
      profile = Factory.insert(:profile)
      session1 = Factory.insert(:session, profile_id: profile.id)
      session2 = Factory.insert(:session, profile_id: profile.id)
      # Different profile
      Factory.insert(:session)

      sessions = Sessions.get_sessions_by_profile(profile.id)

      assert length(sessions) == 2
      session_ids = Enum.map(sessions, & &1.id)
      assert session1.id in session_ids
      assert session2.id in session_ids
    end
  end

  describe "get_active_sessions_by_profile/1" do
    test "returns only active sessions for profile" do
      profile = Factory.insert(:profile)
      active_session = Factory.insert(:session, profile_id: profile.id, status: :running)
      Factory.insert(:session, profile_id: profile.id, status: :stopped)
      Factory.insert(:session, profile_id: profile.id, status: :error)

      active_sessions = Sessions.get_active_sessions_by_profile(profile.id)

      assert length(active_sessions) == 1
      assert hd(active_sessions).id == active_session.id
    end
  end

  describe "profile_in_use?/1" do
    test "returns true when profile has active sessions" do
      profile = Factory.insert(:profile)
      Factory.insert(:session, profile_id: profile.id, status: :running)

      assert Sessions.profile_in_use?(profile.id)
    end

    test "returns false when profile has no active sessions" do
      profile = Factory.insert(:profile)
      Factory.insert(:session, profile_id: profile.id, status: :stopped)

      refute Sessions.profile_in_use?(profile.id)
    end
  end

  describe "get_statistics/0" do
    test "returns session statistics" do
      Factory.insert(:session, status: :running)
      Factory.insert(:session, status: :running)
      Factory.insert(:session, status: :pending)
      Factory.insert(:session, status: :stopped)
      Factory.insert(:session, status: :error)

      stats = Sessions.get_statistics()

      assert stats.total == 5
      assert stats.by_status.running == 2
      assert stats.by_status.pending == 1
      assert stats.by_status.stopped == 1
      assert stats.by_status.error == 1
      # running + pending
      assert stats.active == 3
      # pending
      assert stats.available == 1
      # stopped + error
      assert stats.failed == 2
    end
  end

  describe "change_session/2" do
    test "returns changeset for session" do
      session = Factory.insert(:session)
      attrs = %{name: "New Name"}

      changeset = Sessions.change_session(session, attrs)
      assert changeset.valid?
      assert get_change(changeset, :name) == "New Name"
    end
  end
end
