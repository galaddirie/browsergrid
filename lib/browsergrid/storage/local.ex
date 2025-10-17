# lib/browsergrid/storage/local.ex
defmodule Browsergrid.Storage.Local do
  @moduledoc """
  Local filesystem storage backend.
  Stores files in a configurable directory, works with Docker volumes.
  """

  @behaviour Browsergrid.Storage

  alias Browsergrid.Storage

  require Logger

  @impl true
  def put(path, content, opts \\ []) do
    full_path = full_path(path)
    dir = Path.dirname(full_path)

    with :ok <- File.mkdir_p(dir),
         :ok <- File.write(full_path, content) do
      stat = File.stat!(full_path)

      {:ok,
       %Storage.File{
         path: path,
         size: stat.size,
         content_type: opts[:content_type] || MIME.from_path(path),
         metadata: opts[:metadata] || %{},
         created_at: DateTime.utc_now(),
         backend: :local,
         url: url(path)
       }}
    else
      {:error, reason} ->
        Logger.error("Failed to write file #{path}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @impl true
  def get(path) do
    full_path = full_path(path)
    File.read(full_path)
  end

  @impl true
  def delete(path) do
    full_path = full_path(path)

    case File.rm(full_path) do
      :ok -> :ok
      # File doesn't exist, consider it deleted
      {:error, :enoent} -> :ok
      error -> error
    end
  end

  @impl true
  def exists?(path) do
    full_path = full_path(path)
    File.exists?(full_path)
  end

  @impl true
  def url(path) do
    # Generate URL based on configuration
    base_url = get_base_url()
    "#{base_url}/media/#{path}"
  end

  @impl true
  def list(prefix) do
    base_dir = storage_dir()
    pattern = Path.join([base_dir, prefix, "**"])

    files =
      pattern
      |> Path.wildcard()
      |> Enum.filter(&File.regular?/1)
      |> Enum.map(fn file ->
        Path.relative_to(file, base_dir)
      end)

    {:ok, files}
  end

  defp full_path(path) do
    Path.join(storage_dir(), path)
  end

  defp storage_dir do
    Application.get_env(:browsergrid, :storage)[:local_path] ||
      "/var/lib/browsergrid/media"
  end

  defp get_base_url do
    Application.get_env(:browsergrid, :storage)[:base_url] ||
      Application.get_env(:browsergrid, BrowsergridWeb.Endpoint)[:url][:host] ||
      "http://localhost:4000"
  end
end
