defmodule Browsergrid.SessionRuntime.SessionProfileIntegrationTest do
  use Browsergrid.DataCase

  import Browsergrid.Factory

  alias Browsergrid.Profiles
  alias Browsergrid.SessionRuntime.Session
  alias Browsergrid.SessionRuntime.StateStore

  @entries %{
    "Default/Preferences" => ~s({"theme":"dark"}),
    "Default/Bookmarks" => ~s({"urls":["https://example.com"]})
  }

  setup_all do
    original = Application.get_env(:browsergrid, :storage, [])
    base_path = Path.join(System.tmp_dir!(), "browsergrid-test-media/#{System.unique_integer([:positive])}")
    File.mkdir_p!(base_path)

    updated = Keyword.put(original, :local_path, base_path)
    Application.put_env(:browsergrid, :storage, updated)

    on_exit(fn ->
      Application.put_env(:browsergrid, :storage, original)
      File.rm_rf(base_path)
    end)

    :ok
  end

  test "session hydrates profile data before starting browser runtime" do
    profile = insert(:profile)
    {:ok, profile} = Profiles.upload_profile_data(profile, build_archive(@entries))

    session_id = unique_session_id()
    metadata = %{"profile_id" => profile.id}

    pid = start_supervised!({Session, session_id: session_id, metadata: metadata})

    on_exit(fn ->
      cleanup_session(session_id)
      if Process.alive?(pid), do: GenServer.stop(pid, :normal)
    end)

    state = :sys.get_state(pid)

    profile_dir = state.profile_dir
    on_exit(fn -> File.rm_rf(profile_dir) end)

    preferences_path = Path.join(profile_dir, "Default/Preferences")
    assert File.read!(preferences_path) == @entries["Default/Preferences"]

    assert %{"profile_id" => snapshot_profile_id, "version" => snapshot_version} = state.profile_snapshot
    assert snapshot_profile_id == profile.id
    assert snapshot_version == profile.version
    assert state.metadata["profile_version"] == profile.version

    profile = Profiles.get_profile!(profile.id)
    assert profile.last_used_at
  end

  defp unique_session_id do
    "session-#{System.unique_integer([:positive])}"
  end

  defp cleanup_session(session_id) do
    StateStore.delete(session_id)
    :ok
  end

  defp build_archive(entries) do
    files =
      Enum.map(entries, fn {path, content} ->
        {String.to_charlist(path), content}
      end)

    {:ok, {_name, zip_binary}} = :zip.create(~c"profile.zip", files, [:memory])
    IO.iodata_to_binary(zip_binary)
  end
end
