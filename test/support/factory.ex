defmodule Browsergrid.Factory do
  use ExMachina.Ecto, repo: Browsergrid.Repo

  def session_factory do
    %Browsergrid.Sessions.Session{
      id: Ecto.UUID.generate(),
      name: sequence(:name, &"Session #{&1}"),
      browser_type: :chrome,
      status: :pending,
      cluster: "default",
      screen: %{"width" => 1920, "height" => 1080, "dpi" => 96, "scale" => 1.0},
      limits: %{"cpu" => nil, "memory" => nil, "timeout_minutes" => 30},
      headless: false,
      timeout: 30
    }
  end

  def profile_factory do
    %Browsergrid.Profiles.Profile{
      id: Ecto.UUID.generate(),
      name: sequence(:name, &"Profile #{&1}"),
      browser_type: :chrome,
      status: :active,
      version: 1,
      metadata: %{},
      storage_size_bytes: 0
    }
  end

  def route_factory do
    session_id = Ecto.UUID.generate()

    %Browsergrid.Routing.Route{
      id: session_id,  # Routes use session_id as primary key
      ip: sequence(:ip, &"10.0.0.#{rem(&1, 254) + 1}"),  # Ensure valid IP range
      port: 80,
      version: System.system_time(:nanosecond)
    }
  end

  def media_file_factory do
    %Browsergrid.Media.MediaFile{
      id: Ecto.UUID.generate(),
      filename: sequence(:filename, &"file_#{&1}.zip"),
      original_filename: sequence(:original_filename, &"original_file_#{&1}.zip"),
      storage_path: sequence(:storage_path, &"uploads/2024/01/01/file_#{&1}.zip"),
      content_type: "application/zip",
      size: :rand.uniform(1000000),
      backend: :local,
      metadata: %{},
      category: "profiles"
    }
  end

  def profile_snapshot_factory do
    profile = insert(:profile)
    media_file = insert(:media_file)

    %Browsergrid.Profiles.ProfileSnapshot{
      id: Ecto.UUID.generate(),
      profile_id: profile.id,
      media_file_id: media_file.id,
      version: sequence(:version, & &1),
      storage_size_bytes: :rand.uniform(1000000),
      metadata: %{
        "created_at" => DateTime.utc_now(),
        "test" => true
      }
    }
  end

  def deployment_factory do
    %Browsergrid.Deployments.Deployment{
      id: Ecto.UUID.generate(),
      name: sequence(:deployment_name, &"Deployment #{&1}"),
      description: "Test deployment",
      archive_path: sequence(:archive_path, &"/tmp/test_archive_#{&1}.zip"),
      root_directory: "./",
      start_command: "npm start",
      install_command: "npm install",
      environment_variables: [],
      parameters: [],
      tags: ["test"],
      is_public: false,
      status: :pending
    }
  end

  # Helper to create a session with a profile
  def session_with_profile_factory do
    profile = insert(:profile)

    build(:session,
      profile_id: profile.id,
      browser_type: profile.browser_type
    )
  end

  # Helper to create a running session with route
  def running_session_with_route_factory do
    session = insert(:session, status: :running)
    insert(:route, id: session.id)

    session
  end

  def session_audit_factory do
    session = insert(:session)

    %Browsergrid.Sessions.Audit{
      id: Ecto.UUID.generate(),
      action: "session_started",
      metadata: %{"browser_type" => "chrome", "cluster" => "default"},
      session_id: session.id
    }
  end
end
