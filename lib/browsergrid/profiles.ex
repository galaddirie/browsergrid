defmodule Browsergrid.Profiles do
  @moduledoc """
  The Profiles context - manages browser profile lifecycle and persistence.
  """

  import Ecto.Changeset
  import Ecto.Query, warn: false

  alias Browsergrid.Accounts.User
  alias Browsergrid.Authorization
  alias Browsergrid.Media
  alias Browsergrid.Profiles.Profile
  alias Browsergrid.Profiles.ProfileSnapshot
  alias Browsergrid.Repo
  alias Browsergrid.Storage

  require Logger

  @doc """
  Returns the list of profiles.
  """
  def list_profiles(opts \\ []) do
    base_query = from(p in Profile, order_by: [desc: p.last_used_at, desc: p.inserted_at])

    query =
      base_query
      |> maybe_scope_user(opts)
      |> Enum.reduce(opts, fn
        {:user, _user}, q -> q
        {:user_id, user_id}, q -> where(q, [p], p.user_id == ^user_id)
        {:browser_type, type}, q -> where(q, [p], p.browser_type == ^type)
        {:status, status}, q -> where(q, [p], p.status == ^status)
        {:limit, limit}, q -> limit(q, ^limit)
        _, q -> q
      end)

    query
    |> maybe_preload(opts)
    |> Repo.all()
  end

  @doc """
  Lists profiles owned by the given user.
  """
  @spec list_user_profiles(User.t(), Keyword.t()) :: [Profile.t()]
  def list_user_profiles(%User{} = user, opts \\ []) do
    Profile
    |> Authorization.scope_owned(user)
    |> apply_filters(opts)
    |> maybe_preload(opts)
    |> Repo.all()
  end

  @doc """
  Gets a single profile.
  """
  def get_profile!(id), do: Repo.get!(Profile, id)
  def get_profile(id), do: Repo.get(Profile, id)

  @doc """
  Fetches a profile belonging to the given user.
  """
  @spec fetch_user_profile(User.t(), Ecto.UUID.t(), Keyword.t()) ::
          {:ok, Profile.t()} | {:error, :not_found}
  def fetch_user_profile(user, id, opts \\ [])

  def fetch_user_profile(%User{} = user, id, opts) when is_binary(id) do
    query =
      Profile
      |> Authorization.scope_owned(user)
      |> where([p], p.id == ^id)
      |> apply_filters(opts)
      |> maybe_preload(opts)

    case Repo.one(query) do
      %Profile{} = profile -> {:ok, profile}
      nil -> {:error, :not_found}
    end
  end

  def fetch_user_profile(_user, _id, _opts), do: {:error, :not_found}

  @doc """
  Fetches a profile for a user and raises if not found.
  """
  @spec fetch_user_profile!(User.t(), Ecto.UUID.t(), Keyword.t()) :: Profile.t()
  def fetch_user_profile!(%User{} = user, id, opts \\ []) do
    Profile
    |> Authorization.scope_owned(user)
    |> where([p], p.id == ^id)
    |> apply_filters(opts)
    |> maybe_preload(opts)
    |> Repo.one!()
  end

  @doc """
  Gets a profile with its media file and user preloaded.
  """
  def get_profile_with_media!(id) do
    Profile
    |> preload([:media_file, :user])
    |> Repo.get!(id)
  end

  @doc """
  Creates a profile.
  """
  def create_profile(attrs \\ %{}) do
    attrs
    |> Profile.create_changeset()
    |> Repo.insert()
  end

  @doc """
  Updates a profile.
  """
  def update_profile(%Profile{} = profile, attrs) do
    profile
    |> Profile.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a profile and its associated media files.
  """
  def delete_profile(%Profile{} = profile) do
    Repo.transaction(fn ->
      delete_profile_snapshots(profile)

      if profile.media_file_id do
        case Media.get_media_file(profile.media_file_id) do
          nil -> :ok
          media_file -> Media.delete_media_file(media_file)
        end
      end

      Repo.delete!(profile)
    end)
  end

  @doc """
  Archives a profile (soft delete).
  """
  def archive_profile(%Profile{} = profile) do
    update_profile(profile, %{status: :archived})
  end

  @doc """
  Downloads profile data from storage as a zip file.
  Returns the binary content of the zip file.
  """
  def download_profile_data(%Profile{media_file_id: nil}), do: {:error, :no_profile_data}

  def download_profile_data(%Profile{} = profile) do
    profile = Repo.preload(profile, :media_file)

    case profile.media_file do
      nil -> {:error, :no_profile_data}
      media_file -> Storage.get(media_file.storage_path)
    end
  end

  @doc """
  Uploads new profile data from a zip file.
  Creates a new snapshot and updates the profile.
  """
  def upload_profile_data(%Profile{} = profile, zip_content, session_id \\ nil) when is_binary(zip_content) do
    Repo.transaction(fn ->
      filename = "profile_#{profile.id}_v#{profile.version + 1}.zip"

      media_file =
        case Media.upload_from_binary(filename, zip_content,
               category: "profiles",
               metadata: %{
                 "profile_id" => profile.id,
                 "version" => profile.version + 1,
                 "session_id" => session_id
               }
             ) do
          {:ok, file} ->
            file

          {:error, reason} ->
            Logger.error("Failed to upload profile data: #{inspect(reason)}")
            Repo.rollback(reason)
        end

      if profile.media_file_id do
        create_snapshot(profile, session_id)
      end

      updated_profile =
        profile
        |> Profile.update_version()
        |> change(%{
          media_file_id: media_file.id,
          storage_size_bytes: media_file.size,
          last_used_at: DateTime.utc_now()
        })
        |> Repo.update!()

      updated_profile
    end)
  end

  @doc """
  Creates an empty profile with initial browser data structure.
  """
  def initialize_profile(%Profile{} = profile) do
    empty_data = create_empty_profile_data(profile.browser_type)

    upload_profile_data(profile, empty_data)
  end

  @doc """
  Gets profile statistics.
  """
  def get_statistics(user_id \\ nil) do
    base_query = Profile

    query =
      if user_id do
        where(base_query, [p], p.user_id == ^user_id)
      else
        base_query
      end

    profiles = Repo.all(query)

    %{
      total: length(profiles),
      by_browser: profiles |> Enum.group_by(& &1.browser_type) |> Map.new(fn {k, v} -> {k, length(v)} end),
      by_status: profiles |> Enum.group_by(& &1.status) |> Map.new(fn {k, v} -> {k, length(v)} end),
      active: Enum.count(profiles, &(&1.status == :active)),
      total_storage_bytes: Enum.reduce(profiles, 0, fn p, acc -> (p.storage_size_bytes || 0) + acc end)
    }
  end

  @doc """
  Restores a profile from a specific snapshot.
  """
  def restore_from_snapshot(%Profile{} = profile, %ProfileSnapshot{} = snapshot) do
    snapshot = Repo.preload(snapshot, :media_file)

    Repo.transaction(fn ->
      create_snapshot(profile, nil)

      profile
      |> Profile.update_version()
      |> change(%{
        media_file_id: snapshot.media_file_id,
        storage_size_bytes: snapshot.storage_size_bytes,
        metadata: Map.put(profile.metadata, "restored_from_version", snapshot.version)
      })
      |> Repo.update!()
    end)
  end

  @doc """
  Lists snapshots for a profile.
  """
  def list_profile_snapshots(%Profile{} = profile, opts \\ []) do
    query =
      from(s in ProfileSnapshot,
        where: s.profile_id == ^profile.id,
        order_by: [desc: s.version],
        preload: :media_file
      )

    query =
      case Keyword.get(opts, :limit) do
        nil -> query
        limit -> limit(query, ^limit)
      end

    Repo.all(query)
  end

  @doc """
  Cleans up old snapshots, keeping only the N most recent.
  """
  def cleanup_old_snapshots(%Profile{} = profile, keep_count \\ 5) do
    snapshots = list_profile_snapshots(profile)

    if length(snapshots) > keep_count do
      snapshots_to_delete = Enum.drop(snapshots, keep_count)

      Enum.each(snapshots_to_delete, fn snapshot ->
        delete_snapshot(snapshot)
      end)

      {:ok, length(snapshots_to_delete)}
    else
      {:ok, 0}
    end
  end

  defp create_snapshot(%Profile{} = profile, session_id) do
    if profile.media_file_id do
      %ProfileSnapshot{}
      |> ProfileSnapshot.changeset(%{
        profile_id: profile.id,
        media_file_id: profile.media_file_id,
        version: profile.version,
        created_by_session_id: session_id,
        storage_size_bytes: profile.storage_size_bytes || 0,
        metadata: %{
          "created_at" => DateTime.utc_now(),
          "profile_status" => to_string(profile.status)
        }
      })
      |> Repo.insert!()
    end
  end

  defp delete_snapshot(%ProfileSnapshot{} = snapshot) do
    if snapshot.media_file_id do
      case Media.get_media_file(snapshot.media_file_id) do
        nil -> :ok
        media_file -> Media.delete_media_file(media_file)
      end
    end

    Repo.delete!(snapshot)
  end

  defp delete_profile_snapshots(%Profile{} = profile) do
    snapshots = list_profile_snapshots(profile)
    Enum.each(snapshots, &delete_snapshot/1)
  end

  defp maybe_scope_user(query, opts) do
    case Keyword.get(opts, :user) do
      %User{} = user -> Authorization.scope_owned(query, user)
      _ -> query
    end
  end

  defp apply_filters(query, opts) do
    Enum.reduce(opts, query, fn
      {:user, _}, q -> q
      {:user_id, user_id}, q -> where(q, [p], p.user_id == ^user_id)
      {:browser_type, type}, q -> where(q, [p], p.browser_type == ^type)
      {:status, status}, q -> where(q, [p], p.status == ^status)
      {:limit, limit}, q -> limit(q, ^limit)
      {:preload, _}, q -> q
      _, q -> q
    end)
  end

  defp maybe_preload(query, opts) do
    case Keyword.get(opts, :preload, false) do
      false -> query
      nil -> query
      true -> preload(query, [:media_file, :user])
      preloads when is_list(preloads) -> preload(query, ^preloads)
    end
  end

  @doc """
  Returns `true` when the user owns the profile (admins always pass).
  """
  @spec user_owns_profile?(User.t() | nil, Profile.t()) :: boolean()
  def user_owns_profile?(user, %Profile{} = profile) do
    Authorization.owns?(user, profile)
  end

  defp create_empty_profile_data(_browser_type) do
    empty_zip = <<80, 75, 5, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>
    empty_zip
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking profile changes.
  """
  def change_profile(%Profile{} = profile, attrs \\ %{}) do
    Profile.changeset(profile, attrs)
  end
end
