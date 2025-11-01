defmodule Browsergrid.SessionRuntime.ProfileLoader do
  @moduledoc """
  Fetches and extracts persistent browser profiles for runtime sessions.

  This module bridges the Profiles context and the runtime so ephemeral
  session hosts always hydrate their working directory from the latest
  stored archive before the browser pod is started.
  """

  alias Browsergrid.Profiles
  alias Browsergrid.Profiles.Profile
  alias Browsergrid.Repo
  alias Browsergrid.Storage

  require Logger

  @type snapshot :: map() | nil

  @spec ensure_profile_loaded(String.t(), String.t() | nil, String.t(), keyword()) ::
          {:ok, %{snapshot: snapshot(), metadata: map()}} | {:error, term()}
  def ensure_profile_loaded(session_id, profile_id, profile_dir, opts \\ [])
      when is_binary(session_id) and is_binary(profile_dir) do
    current_snapshot = Keyword.get(opts, :current_snapshot)

    case profile_id do
      nil ->
        with :ok <- ensure_directory(profile_dir) do
          {:ok, %{snapshot: nil, metadata: %{}}}
        end

      _ ->
        with {:ok, profile} <- fetch_profile(profile_id),
             snapshot_ref = build_snapshot(profile),
             metadata = build_metadata(profile),
             :ok <- maybe_sync_profile(profile, profile_dir, current_snapshot, snapshot_ref),
             :ok <- touch_profile(profile) do
          {:ok, %{snapshot: snapshot_ref, metadata: metadata}}
        end
    end
  end

  defp fetch_profile(profile_id) do
    case Profiles.get_profile(profile_id) do
      nil ->
        Logger.error("Profile #{profile_id} not found while loading session profile")
        {:error, :profile_not_found}

      profile ->
        {:ok, Repo.preload(profile, :media_file)}
    end
  end

  defp maybe_sync_profile(%Profile{} = profile, profile_dir, current_snapshot, snapshot_ref) do
    if same_snapshot?(snapshot_ref, current_snapshot) and directory_ready?(profile_dir) do
      :ok
    else
      with :ok <- ensure_directory(profile_dir) do
        sync_profile_contents(profile, profile_dir)
      end
    end
  end

  defp ensure_directory(profile_dir) do
    with {:ok, _} <- File.rm_rf(profile_dir),
         :ok <- File.mkdir_p(profile_dir) do
      :ok
    else
      {:error, reason} ->
        Logger.error("Failed to prepare profile dir #{profile_dir}: #{inspect(reason)}")
        {:error, {:profile_dir_prepare_failed, reason}}

      {:error, reason, path} ->
        Logger.error("Failed to clean profile dir #{profile_dir} on #{path}: #{inspect(reason)}")
        {:error, {:profile_dir_cleanup_failed, {path, reason}}}
    end
  end

  defp sync_profile_contents(%Profile{media_file: nil}, profile_dir) do
    Logger.debug("Profile #{profile_dir} has no media archive; leaving directory empty")
    :ok
  end

  defp sync_profile_contents(%Profile{media_file: media} = profile, profile_dir) do
    case Storage.get(media.storage_path) do
      {:ok, zip_binary} ->
        extract_archive(zip_binary, profile_dir)

      {:error, reason} ->
        Logger.error(
          "Failed to download profile archive #{media.storage_path} for profile #{profile.id}: #{inspect(reason)}"
        )

        {:error, {:profile_download_failed, reason}}
    end
  end

  defp extract_archive(zip_binary, profile_dir) when is_binary(zip_binary) do
    tmp_dir = Path.join(System.tmp_dir!(), "browsergrid-profile-#{System.unique_integer([:positive])}")
    tmp_zip = Path.join(tmp_dir, "profile.zip")

    with :ok <- File.mkdir_p(tmp_dir),
         :ok <- File.write(tmp_zip, zip_binary),
         {:ok, _files} <- :zip.extract(String.to_charlist(tmp_zip), cwd: String.to_charlist(profile_dir)),
         :ok <- File.rm(tmp_zip),
         :ok <- File.rmdir(tmp_dir) do
      :ok
    else
      {:error, reason} = error ->
        Logger.error("Failed to extract profile archive into #{profile_dir}: #{inspect(reason)}")
        File.rm_rf(tmp_dir)
        error
    end
  end

  defp build_snapshot(%Profile{media_file: nil} = profile) do
    %{
      "profile_id" => profile.id,
      "version" => profile.version,
      "media_path" => nil,
      "updated_at" => profile.updated_at
    }
  end

  defp build_snapshot(%Profile{media_file: media} = profile) do
    %{
      "profile_id" => profile.id,
      "version" => profile.version,
      "media_path" => media.storage_path,
      "media_size" => media.size,
      "updated_at" => profile.updated_at
    }
  end

  defp build_metadata(%Profile{} = profile) do
    base = %{
      "profile_id" => profile.id,
      "profile_version" => profile.version
    }

    maybe_put_media_path(base, profile.media_file)
  end

  defp maybe_put_media_path(metadata, nil), do: metadata

  defp maybe_put_media_path(metadata, media) do
    Map.put(metadata, "profile_media_path", media.storage_path)
  end

  defp same_snapshot?(nil, nil), do: true
  defp same_snapshot?(new, nil), do: is_nil(new)
  defp same_snapshot?(nil, _old), do: false
  defp same_snapshot?(%{} = new, %{} = old), do: new == old
  defp same_snapshot?(new, old), do: new == old

  defp directory_ready?(profile_dir) do
    File.dir?(profile_dir)
  end

  defp touch_profile(%Profile{} = profile) do
    case Profiles.update_profile(profile, %{last_used_at: DateTime.utc_now()}) do
      {:ok, _} ->
        :ok

      {:error, changeset} ->
        Logger.warning("Failed to update last_used_at for profile #{profile.id}: #{inspect(changeset.errors)}")
        :ok
    end
  end
end
