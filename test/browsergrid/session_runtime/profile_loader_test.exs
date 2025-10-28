defmodule Browsergrid.SessionRuntime.ProfileLoaderTest do
  use Browsergrid.DataCase

  import Browsergrid.Factory

  alias Browsergrid.Profiles
  alias Browsergrid.SessionRuntime.ProfileLoader

  @default_entries %{
    "Default/Preferences" => ~s({"homepage":"https://example.com"}),
    "Default/Cookies/cookie.txt" => "cookie=1"
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

  test "loads profile archive into the target directory" do
    profile = insert(:profile)
    {:ok, profile} = Profiles.upload_profile_data(profile, build_archive(@default_entries))

    session_id = Ecto.UUID.generate()
    profile_dir = Path.join(System.tmp_dir!(), "browsergrid-profile-test-#{session_id}")
    on_exit(fn -> File.rm_rf(profile_dir) end)

    assert {:ok, %{snapshot: snapshot, metadata: metadata}} =
             ProfileLoader.ensure_profile_loaded(session_id, profile.id, profile_dir)

    assert snapshot["profile_id"] == profile.id
    assert snapshot["version"] == profile.version
    assert metadata["profile_id"] == profile.id
    assert metadata["profile_version"] == profile.version

    preferences_path = Path.join(profile_dir, "Default/Preferences")
    assert File.read!(preferences_path) == @default_entries["Default/Preferences"]

    profile = Profiles.get_profile!(profile.id)
    refute is_nil(profile.last_used_at)
  end

  test "rehydrates profile directory when snapshot exists but files are missing" do
    profile = insert(:profile)
    {:ok, profile} = Profiles.upload_profile_data(profile, build_archive(@default_entries))

    session_id = Ecto.UUID.generate()
    profile_dir = Path.join(System.tmp_dir!(), "browsergrid-profile-test-#{session_id}")
    on_exit(fn -> File.rm_rf(profile_dir) end)

    {:ok, %{snapshot: snapshot}} = ProfileLoader.ensure_profile_loaded(session_id, profile.id, profile_dir)

    File.rm_rf(profile_dir)

    assert {:ok, %{snapshot: new_snapshot}} =
             ProfileLoader.ensure_profile_loaded(session_id, profile.id, profile_dir, current_snapshot: snapshot)

    assert new_snapshot["profile_id"] == snapshot["profile_id"]
    assert new_snapshot["media_path"] == snapshot["media_path"]
    assert new_snapshot["version"] == snapshot["version"]

    preferences_path = Path.join(profile_dir, "Default/Preferences")
    assert File.read!(preferences_path) == @default_entries["Default/Preferences"]
  end

  test "returns error when profile is missing" do
    session_id = Ecto.UUID.generate()
    missing_profile_id = Ecto.UUID.generate()
    profile_dir = Path.join(System.tmp_dir!(), "browsergrid-profile-test-#{session_id}")

    assert {:error, :profile_not_found} =
             ProfileLoader.ensure_profile_loaded(session_id, missing_profile_id, profile_dir)
  end

  defp build_archive(entries) when is_map(entries) do
    files =
      entries
      |> Enum.map(fn {path, content} ->
        {String.to_charlist(path), content}
      end)

    {:ok, {_name, zip_binary}} = :zip.create(~c"profile.zip", files, [:memory])
    IO.iodata_to_binary(zip_binary)
  end
end
