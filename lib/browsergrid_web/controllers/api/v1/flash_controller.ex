defmodule BrowsergridWeb.API.V1.FlashController do
  use BrowsergridWeb, :controller

  @doc """
  Clear a specific flash message type.

  ## Examples

      DELETE /api/v1/flash/info
      DELETE /api/v1/flash/error
      DELETE /api/v1/flash/warning
      DELETE /api/v1/flash/notice
  """
  def clear(conn, %{"type" => type}) do
    # Convert string to atom for flash type
    flash_type = String.to_atom(type)

    # Clear the specific flash message
    conn = Phoenix.Controller.put_flash(conn, flash_type, nil)

    json(conn, %{
      success: true,
      type: type,
      message: "Flash message cleared"
    })
  end

  @doc """
  Clear all flash messages at once.

  ## Examples

      DELETE /api/v1/flash
  """
  def clear_all(conn, _params) do
    conn =
      conn
      |> Phoenix.Controller.put_flash(:info, nil)
      |> Phoenix.Controller.put_flash(:error, nil)
      |> Phoenix.Controller.put_flash(:warning, nil)
      |> Phoenix.Controller.put_flash(:notice, nil)

    json(conn, %{
      success: true,
      message: "All flash messages cleared"
    })
  end
end
