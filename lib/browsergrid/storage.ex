# lib/browsergrid/storage.ex
defmodule Browsergrid.Storage do
  @moduledoc """
  Storage behavior and utilities for file storage.
  Provides a common interface for different storage backends.
  """

  alias Browsergrid.Storage.File

  @type path :: String.t()
  @type content :: binary()
  @type opts :: Keyword.t()

  @callback put(path, content, opts) :: {:ok, File.t()} | {:error, term()}
  @callback get(path) :: {:ok, content} | {:error, term()}
  @callback delete(path) :: :ok | {:error, term()}
  @callback exists?(path) :: boolean()
  @callback url(path) :: String.t()
  @callback list(prefix :: String.t()) :: {:ok, [path]} | {:error, term()}

  @doc """
  Get the configured storage backend module
  """
  def backend do
    Application.get_env(:browsergrid, :storage)[:backend] || Browsergrid.Storage.Local
  end

  @doc """
  Store content at the given path
  """
  def put(path, content, opts \\ []) do
    backend().put(path, content, opts)
  end

  @doc """
  Retrieve content from the given path
  """
  def get(path) do
    backend().get(path)
  end

  @doc """
  Delete the file at the given path
  """
  def delete(path) do
    backend().delete(path)
  end

  @doc """
  Check if a file exists at the given path
  """
  def exists?(path) do
    backend().exists?(path)
  end

  @doc """
  Get the public URL for the given path
  """
  def url(path) do
    backend().url(path)
  end

  @doc """
  List all files with the given prefix
  """
  def list(prefix) do
    backend().list(prefix)
  end

  @doc """
  Sanitize a filename to be safe for storage
  """
  def sanitize_filename(filename) when is_binary(filename) do
    filename
    |> String.replace(~r/[^\w\-_\.]/, "_")  # Replace non-word chars with underscore
    |> String.replace(~r/_+/, "_")          # Collapse multiple underscores
    |> String.trim("_")                     # Remove leading/trailing underscores
    |> ensure_extension(filename)
  end

  @doc """
  Generate a unique filename with timestamp and random suffix
  """
  def generate_filename(base_filename) when is_binary(base_filename) do
    timestamp = DateTime.utc_now() |> DateTime.to_unix()
    random = :crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower)

    case Path.extname(base_filename) do
      "" ->
        "#{Path.basename(base_filename, "")}_#{timestamp}_#{random}"
      ext ->
        base = Path.basename(base_filename, ext)
        "#{base}_#{timestamp}_#{random}#{ext}"
    end
  end

  # Private helpers

  defp ensure_extension(sanitized, original) do
    sanitized_ext = Path.extname(sanitized)
    original_ext = Path.extname(original)

    if sanitized_ext == "" and original_ext != "" do
      sanitized <> original_ext
    else
      sanitized
    end
  end
end
