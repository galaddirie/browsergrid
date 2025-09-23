# lib/browsergrid_web/controllers/media_controller.ex
defmodule BrowsergridWeb.MediaController do
  use BrowsergridWeb, :controller

  alias Browsergrid.Storage

  # Serve files from local storage
  def serve(conn, %{"path" => path}) do
    # Reconstruct the full path
    full_path = Enum.join(path, "/")

    # Check if using local storage
    if Storage.backend() == Browsergrid.Storage.Local do
      case Storage.get(full_path) do
        {:ok, content} ->
          conn
          |> put_resp_content_type(MIME.from_path(full_path))
          |> send_resp(200, content)

        {:error, :enoent} ->
          conn
          |> put_status(:not_found)
          |> text("File not found")
      end
    else
      # For remote storage, redirect to the actual URL
      url = Storage.url(full_path)
      redirect(conn, external: url)
    end
  end
end
