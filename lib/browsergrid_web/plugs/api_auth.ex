defmodule BrowsergridWeb.Plugs.ApiAuth do
  @moduledoc """
  Plug for authenticating API requests using bearer tokens.
  """
  import Plug.Conn

  alias Browsergrid.ApiTokens

  def init(opts), do: opts

  def call(conn, _opts) do
    with {:ok, token} <- extract_bearer_token(conn),
         {:ok, user, api_token} <- ApiTokens.verify_token(token) do
      conn
      |> assign(:current_user, user)
      |> assign(:api_token, api_token)
    else
      {:error, :no_token} ->
        send_error(conn, %{error: "unauthorized"})

      {:error, reason} ->
        send_error(conn, %{reason: to_string(reason)})
    end
  end

  defp send_error(conn, body) do
    conn
    |> put_status(:unauthorized)
    |> put_resp_content_type("application/json")
    |> send_resp(401, Jason.encode!(body))
    |> halt()
  end

  defp extract_bearer_token(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] -> {:ok, String.trim(token)}
      [] -> {:error, :no_token}
      _ -> {:error, :malformed_header}
    end
  end
end
