defmodule BrowsergridWeb.UserSocket do
  @moduledoc """
  Phoenix Socket for real-time communication.
  """

  use Phoenix.Socket

  # A Socket handler
  #
  # It's possible to control the websocket connection and
  # assign values that can be accessed by your channel topics
  # from `BrowsergridWeb.UserSocket.connect/3` and assign it to
  # `BrowsergridWeb.UserSocket.id/1`.
  #
  # The `connect/3` function receives the parameters from the URL,
  # which we can use to authenticate a user. This function must
  # return one of:
  #
  #   - `{:ok, socket}` to assign each socket to a specific user
  #   - `{:ok, socket, %{key: value}}` to assign metadata to the socket
  #   - `:error` to deny the connection
  #
  # To deny connection, return `:error`.
  #
  # See `Phoenix.Token` docs for examples of authentication.

  channel "sessions", BrowsergridWeb.SessionChannel

  @impl true
  def connect(_params, socket, _connect_info) do
    # For now, allow all connections
    # In production, you might want to add authentication
    {:ok, socket}
  end

  @impl true
  def id(_socket), do: nil
end




