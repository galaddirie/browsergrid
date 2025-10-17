# lib/browsergrid/media.ex
defmodule Browsergrid.Media do
  @moduledoc """
  The Media context for handling file uploads and storage.
  """

  import Ecto.Query, warn: false

  alias Browsergrid.Media.MediaFile
  alias Browsergrid.Repo
  alias Browsergrid.Storage

  require Logger

  @doc """
  Upload a file and create a database record
  """
  def upload_file(upload, opts \\ []) do
    with {:ok, content} <- read_upload(upload),
         path = generate_storage_path(upload.filename, opts),
         {:ok, storage_file} <-
           Storage.put(path, content,
             content_type: upload.content_type,
             metadata: opts[:metadata]
           ),
         {:ok, media_file} <- create_media_file(storage_file, upload, opts) do
      {:ok, media_file}
    else
      {:error, reason} = error ->
        Logger.error("Upload failed: #{inspect(reason)}")
        error
    end
  end

  @doc """
  Upload from a Plug.Upload struct (for LiveView)
  """
  def upload_from_plug(%Plug.Upload{} = upload, opts \\ []) do
    upload_file(
      %{
        filename: upload.filename,
        content_type: upload.content_type,
        path: upload.path
      },
      opts
    )
  end

  @doc """
  Upload from binary content
  """
  def upload_from_binary(filename, content, opts \\ []) do
    upload_file(
      %{
        filename: filename,
        content_type: opts[:content_type] || MIME.from_path(filename),
        content: content
      },
      opts
    )
  end

  @doc """
  Get a media file by ID
  """
  def get_media_file!(id), do: Repo.get!(MediaFile, id)
  def get_media_file(id), do: Repo.get(MediaFile, id)

  @doc """
  List media files with optional filters
  """
  def list_media_files(opts \\ []) do
    query = from(m in MediaFile, order_by: [desc: m.inserted_at])

    query =
      Enum.reduce(opts, query, fn
        {:user_id, user_id}, q -> where(q, [m], m.user_id == ^user_id)
        {:session_id, session_id}, q -> where(q, [m], m.session_id == ^session_id)
        {:category, category}, q -> where(q, [m], m.category == ^category)
        {:limit, limit}, q -> limit(q, ^limit)
        _, q -> q
      end)

    Repo.all(query)
  end

  @doc """
  Delete a media file (both from storage and database)
  """
  def delete_media_file(%MediaFile{} = media_file) do
    # Delete from storage first
    case Storage.delete(media_file.storage_path) do
      :ok ->
        Repo.delete(media_file)

      {:error, reason} ->
        Logger.warning("Failed to delete from storage: #{inspect(reason)}")
        # Still delete from database
        Repo.delete(media_file)
    end
  end

  @doc """
  Get the public URL for a media file
  """
  def get_url(%MediaFile{storage_path: path}) do
    Storage.url(path)
  end

  @doc """
  Clean up orphaned files (files in storage without DB records)
  """
  def cleanup_orphaned_files do
    {:ok, storage_files} = Storage.list("")

    db_paths =
      from(m in MediaFile, select: m.storage_path)
      |> Repo.all()
      |> MapSet.new()

    orphaned = Enum.reject(storage_files, &MapSet.member?(db_paths, &1))

    Enum.each(orphaned, fn path ->
      Logger.info("Deleting orphaned file: #{path}")
      Storage.delete(path)
    end)

    {:ok, length(orphaned)}
  end

  # Private functions

  defp read_upload(%{content: content}) when is_binary(content) do
    {:ok, content}
  end

  defp read_upload(%{path: path}) when is_binary(path) do
    File.read(path)
  end

  defp generate_storage_path(filename, opts) do
    category = opts[:category] || "uploads"
    date = Date.utc_today()

    sanitized = Storage.sanitize_filename(filename)
    unique_name = Storage.generate_filename(sanitized)

    Path.join([
      category,
      to_string(date.year),
      String.pad_leading(to_string(date.month), 2, "0"),
      String.pad_leading(to_string(date.day), 2, "0"),
      unique_name
    ])
  end

  defp create_media_file(storage_file, upload, opts) do
    attrs = %{
      filename: Path.basename(storage_file.path),
      original_filename: upload.filename,
      storage_path: storage_file.path,
      content_type: storage_file.content_type,
      size: storage_file.size,
      backend: storage_file.backend,
      metadata: storage_file.metadata,
      user_id: opts[:user_id],
      session_id: opts[:session_id],
      category: opts[:category]
    }

    %MediaFile{}
    |> MediaFile.changeset(attrs)
    |> Repo.insert()
  end
end
