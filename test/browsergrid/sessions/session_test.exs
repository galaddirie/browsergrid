defmodule Browsergrid.Sessions.SessionTest do
  use Browsergrid.DataCase, async: true

  alias Browsergrid.Factory
  alias Browsergrid.Sessions.Session

  describe "changeset/2" do
    test "valid changeset with required fields" do
      attrs = %{
        browser_type: :chrome,
        status: :pending
      }

      changeset = Session.changeset(%Session{}, attrs)
      assert changeset.valid?
      assert get_field(changeset, :browser_type) == :chrome
      assert get_field(changeset, :status) == :pending
    end

    test "valid changeset with all fields" do
      profile = Factory.insert(:profile, browser_type: :firefox)

      attrs = %{
        name: "Test Session",
        browser_type: :firefox,
        status: :running,
        cluster: "test-cluster",
        profile_id: profile.id,
        headless: true,
        timeout: 60,
        screen: %{"width" => 1280, "height" => 720, "dpi" => 72, "scale" => 1.5},
        limits: %{"cpu" => 2.0, "memory" => 1024, "timeout_minutes" => 45}
      }

      changeset = Session.changeset(%Session{}, attrs)
      assert changeset.valid?
      assert get_field(changeset, :name) == "Test Session"
      assert get_field(changeset, :browser_type) == :firefox
      assert get_field(changeset, :status) == :running
      assert get_field(changeset, :cluster) == "test-cluster"
      assert get_field(changeset, :profile_id) == profile.id
      assert get_field(changeset, :headless) == true
      assert get_field(changeset, :timeout) == 60
      assert get_field(changeset, :screen) == %{"width" => 1280, "height" => 720, "dpi" => 72, "scale" => 1.5}
      assert get_field(changeset, :limits) == %{"cpu" => 2.0, "memory" => 1024, "timeout_minutes" => 45}
    end

    test "requires browser_type and status to be present" do
      # When updating an existing session, trying to set required fields to nil should fail
      session = Factory.build(:session)
      changeset = Session.changeset(session, %{browser_type: nil, status: nil})
      refute changeset.valid?

      errors = errors_on(changeset)
      assert Map.has_key?(errors, :browser_type)
      assert Map.has_key?(errors, :status)
    end

    test "validates browser_type inclusion" do
      attrs = %{browser_type: :invalid_browser, status: :pending}
      changeset = Session.changeset(%Session{}, attrs)
      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).browser_type
    end

    test "validates status inclusion" do
      attrs = %{browser_type: :chrome, status: :invalid_status}
      changeset = Session.changeset(%Session{}, attrs)
      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).status
    end

    test "validates timeout greater than 0" do
      attrs = %{browser_type: :chrome, status: :pending, timeout: 0}
      changeset = Session.changeset(%Session{}, attrs)
      refute changeset.valid?
      assert "must be greater than 0" in errors_on(changeset).timeout

      attrs = %{browser_type: :chrome, status: :pending, timeout: -1}
      changeset = Session.changeset(%Session{}, attrs)
      refute changeset.valid?
      assert "must be greater than 0" in errors_on(changeset).timeout
    end

    test "validates screen dimensions" do
      # Valid screen
      attrs = %{
        browser_type: :chrome,
        status: :pending,
        screen: %{"width" => 1920, "height" => 1080, "dpi" => 96, "scale" => 1.0}
      }

      changeset = Session.changeset(%Session{}, attrs)
      assert changeset.valid?

      # Invalid width
      attrs = %{browser_type: :chrome, status: :pending, screen: %{"width" => 0, "height" => 1080}}
      changeset = Session.changeset(%Session{}, attrs)
      refute changeset.valid?
      assert "invalid screen dimensions" in errors_on(changeset).screen

      # Invalid height
      attrs = %{browser_type: :chrome, status: :pending, screen: %{"width" => 1920, "height" => 0}}
      changeset = Session.changeset(%Session{}, attrs)
      refute changeset.valid?
      assert "invalid screen dimensions" in errors_on(changeset).screen

      # Invalid dpi
      attrs = %{browser_type: :chrome, status: :pending, screen: %{"width" => 1920, "height" => 1080, "dpi" => 0}}
      changeset = Session.changeset(%Session{}, attrs)
      refute changeset.valid?
      assert "invalid screen dimensions" in errors_on(changeset).screen

      # Invalid scale
      attrs = %{browser_type: :chrome, status: :pending, screen: %{"width" => 1920, "height" => 1080, "scale" => 0}}
      changeset = Session.changeset(%Session{}, attrs)
      refute changeset.valid?
      assert "invalid screen dimensions" in errors_on(changeset).screen

      # Invalid screen type
      attrs = %{browser_type: :chrome, status: :pending, screen: "invalid"}
      changeset = Session.changeset(%Session{}, attrs)
      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).screen
    end

    test "validates limits" do
      # Valid limits
      attrs = %{
        browser_type: :chrome,
        status: :pending,
        limits: %{"cpu" => 2.0, "memory" => 1024}
      }

      changeset = Session.changeset(%Session{}, attrs)
      assert changeset.valid?

      # Invalid limits type
      attrs = %{browser_type: :chrome, status: :pending, limits: "invalid"}
      changeset = Session.changeset(%Session{}, attrs)
      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).limits
    end

    test "validates profile compatibility" do
      chrome_profile = Factory.insert(:profile, browser_type: :chrome)

      # Compatible profile
      attrs = %{browser_type: :chrome, status: :pending, profile_id: chrome_profile.id}
      changeset = Session.changeset(%Session{}, attrs)
      assert changeset.valid?

      # Incompatible profile
      attrs = %{browser_type: :firefox, status: :pending, profile_id: chrome_profile.id}
      changeset = Session.changeset(%Session{}, attrs)
      refute changeset.valid?
      assert "browser type mismatch: profile is chrome, session is firefox" in errors_on(changeset).profile_id
    end

    test "sets default name when empty" do
      attrs = %{browser_type: :chrome, status: :pending, name: ""}
      changeset = Session.changeset(%Session{}, attrs)
      assert changeset.valid?
      assert get_change(changeset, :name) =~ ~r/Session \d+/

      attrs = %{browser_type: :chrome, status: :pending, name: nil}
      changeset = Session.changeset(%Session{}, attrs)
      assert changeset.valid?
      assert get_change(changeset, :name) =~ ~r/Session \d+/
    end

    test "preserves custom name when provided" do
      attrs = %{browser_type: :chrome, status: :pending, name: "Custom Name"}
      changeset = Session.changeset(%Session{}, attrs)
      assert changeset.valid?
      assert get_change(changeset, :name) == "Custom Name"
    end
  end

  describe "create_changeset/1" do
    test "creates changeset with pending status" do
      attrs = %{browser_type: :chrome}
      changeset = Session.create_changeset(attrs)
      assert changeset.valid?
      assert get_field(changeset, :status) == :pending
      assert get_field(changeset, :browser_type) == :chrome
    end

    test "validates browser_type for create changeset" do
      attrs = %{browser_type: :invalid}
      changeset = Session.create_changeset(attrs)
      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).browser_type
    end
  end

  describe "status_changeset/2" do
    test "updates status correctly" do
      session = Factory.build(:session, status: :pending)
      changeset = Session.status_changeset(session, :running)
      assert changeset.valid?
      assert get_field(changeset, :status) == :running
    end

    test "accepts valid statuses" do
      session = Factory.build(:session)
      valid_statuses = [:pending, :running, :stopped, :error, :starting, :stopping]

      for status <- valid_statuses do
        changeset = Session.status_changeset(session, status)
        assert changeset.valid?, "Status #{status} should be valid"
        assert get_field(changeset, :status) == status
      end
    end
  end

  describe "to_runtime_context/1" do
    test "converts session to runtime context" do
      session =
        Factory.build(:session,
          id: "test-session-id",
          browser_type: :firefox,
          screen: %{"width" => 1280, "height" => 720, "dpi" => 72, "scale" => 1.5},
          headless: true
        )

      context = Session.to_runtime_context(session)

      assert context.session_id == "test-session-id"
      assert context.browser_type == :firefox
      assert context.screen_width == 1280
      assert context.screen_height == 720
      assert context.device_scale_factor == 1.5
      assert context.screen_dpi == 72
      assert context.headless == true
    end

    test "uses default screen values when screen is nil" do
      session = Factory.build(:session, screen: nil)
      context = Session.to_runtime_context(session)

      assert context.screen_width == 1920
      assert context.screen_height == 1080
      assert context.device_scale_factor == 1.0
      assert context.screen_dpi == 96
    end
  end

  describe "to_runtime_metadata/1" do
    test "converts session to runtime metadata" do
      session =
        Factory.build(:session,
          browser_type: :chromium,
          profile_id: "profile-123",
          cluster: "test-cluster",
          screen: %{"width" => 1280, "height" => 720},
          headless: true
        )

      metadata = Session.to_runtime_metadata(session)

      assert metadata["browser_type"] == :chromium
      assert metadata["profile_id"] == "profile-123"
      assert metadata["cluster"] == "test-cluster"
      assert metadata["screen"]["width"] == 1280
      assert metadata["screen"]["height"] == 720
      assert metadata["headless"] == true
    end

    test "excludes nil values from metadata" do
      session =
        Factory.build(:session,
          browser_type: :chrome,
          profile_id: nil,
          cluster: nil,
          screen: nil
        )

      metadata = Session.to_runtime_metadata(session)

      assert metadata["browser_type"] == :chrome
      refute Map.has_key?(metadata, "profile_id")
      refute Map.has_key?(metadata, "cluster")
      refute Map.has_key?(metadata, "screen")
    end
  end
end
