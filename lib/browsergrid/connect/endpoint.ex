defmodule Browsergrid.Connect.Endpoint do
  @moduledoc """
  Dedicated endpoint for the connect.* surface. Can be deployed independently
  from the main Browsergrid web interface to scale pooled session acquisition.
  """
  use Phoenix.Endpoint, otp_app: :browsergrid

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint, :connect]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug Browsergrid.Connect.Router
end
