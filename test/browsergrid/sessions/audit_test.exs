defmodule Browsergrid.Sessions.AuditTest do
  use Browsergrid.DataCase, async: true

  alias Browsergrid.Sessions.Audit
  alias Browsergrid.Factory

  describe "changeset/2" do
    test "valid changeset with required fields" do
      session = Factory.insert(:session)
      attrs = %{
        action: "session_created",
        session_id: session.id
      }

      changeset = Audit.changeset(%Audit{}, attrs)
      assert changeset.valid?
      assert get_field(changeset, :action) == "session_created"
      assert get_field(changeset, :session_id) == session.id
      assert get_field(changeset, :metadata) == %{}
    end

    test "valid changeset with all fields" do
      session = Factory.insert(:session)
      attrs = %{
        action: "session_started",
        metadata: %{"browser_type" => "chrome", "cluster" => "production"},
        session_id: session.id
      }

      changeset = Audit.changeset(%Audit{}, attrs)
      assert changeset.valid?
      assert get_field(changeset, :action) == "session_started"
      assert get_field(changeset, :metadata) == %{"browser_type" => "chrome", "cluster" => "production"}
      assert get_field(changeset, :session_id) == session.id
    end

    test "invalid changeset with missing required fields" do
      changeset = Audit.changeset(%Audit{}, %{})
      refute changeset.valid?

      assert "can't be blank" in errors_on(changeset).action
      assert "can't be blank" in errors_on(changeset).session_id
    end

    test "invalid changeset missing action" do
      session = Factory.insert(:session)
      attrs = %{session_id: session.id}

      changeset = Audit.changeset(%Audit{}, attrs)
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).action
    end

    test "invalid changeset missing session_id" do
      attrs = %{action: "session_created"}

      changeset = Audit.changeset(%Audit{}, attrs)
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).session_id
    end

    test "sets default metadata when not provided" do
      session = Factory.insert(:session)
      attrs = %{
        action: "session_stopped",
        session_id: session.id
      }

      changeset = Audit.changeset(%Audit{}, attrs)
      assert changeset.valid?
      assert get_field(changeset, :metadata) == %{}
    end

    test "accepts various action types" do
      session = Factory.insert(:session)
      actions = ["session_created", "session_started", "session_stopped", "session_error", "session_updated"]

      for action <- actions do
        attrs = %{action: action, session_id: session.id}
        changeset = Audit.changeset(%Audit{}, attrs)
        assert changeset.valid?, "Action '#{action}' should be valid"
        assert get_change(changeset, :action) == action
      end
    end

    test "accepts complex metadata" do
      session = Factory.insert(:session)
      metadata = %{
        "browser_type" => "firefox",
        "cluster" => "staging",
        "screen" => %{"width" => 1920, "height" => 1080},
        "limits" => %{"cpu" => 2.0, "memory" => 1024},
        "timestamp" => DateTime.utc_now(),
        "tags" => ["automated", "testing"]
      }

      attrs = %{
        action: "session_configured",
        metadata: metadata,
        session_id: session.id
      }

      changeset = Audit.changeset(%Audit{}, attrs)
      assert changeset.valid?
      assert get_change(changeset, :metadata) == metadata
    end

    test "accepts any session_id format in changeset" do
      attrs = %{
        action: "session_created",
        session_id: "invalid-uuid"
      }

      changeset = Audit.changeset(%Audit{}, attrs)
      assert changeset.valid?
      # Note: UUID validation happens at the database level, not in the changeset
    end
  end

  describe "audit events" do
    test "can be created for different session lifecycle events" do
      session = Factory.insert(:session)

      # Create audit events
      events = [
        {"session_created", %{}},
        {"session_started", %{"browser_type" => "chrome"}},
        {"session_stopped", %{"reason" => "timeout"}},
        {"session_error", %{"error" => "connection_failed"}},
        {"session_updated", %{"field" => "timeout", "old_value" => 30, "new_value" => 60}}
      ]

      for {action, metadata} <- events do
        attrs = %{
          action: action,
          metadata: metadata,
          session_id: session.id
        }

        changeset = Audit.changeset(%Audit{}, attrs)
        assert changeset.valid?

        {:ok, audit} = Repo.insert(changeset)
        assert audit.action == action
        assert audit.metadata == metadata
        assert audit.session_id == session.id
      end
    end

    test "timestamps are set automatically" do
      session = Factory.insert(:session)
      attrs = %{
        action: "session_created",
        session_id: session.id
      }

      changeset = Audit.changeset(%Audit{}, attrs)
      {:ok, audit} = Repo.insert(changeset)

      assert %DateTime{} = audit.inserted_at
      assert %DateTime{} = audit.updated_at
    end
  end
end
