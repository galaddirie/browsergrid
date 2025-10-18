defmodule BrowsergridWeb.Inertia.V1.ConnectControllerTest do
  use BrowsergridWeb.ConnCase, async: true

  setup :register_and_log_in_user

  test "renders the connect pool snapshot", %{conn: conn} do
    conn = get(conn, ~p"/connect/pool")
    response = html_response(conn, 200)

    data = decode_inertia_payload(response)

    assert data["component"] == "Connect/Pool"
    assert get_in(data, ["props", "pool", "pool_size"])
  end

  test "redirects unauthenticated users to log in" do
    conn = build_conn()
    conn = get(conn, ~p"/connect/pool")
    assert redirected_to(conn) == ~p"/users/log_in"
  end

  defp decode_inertia_payload(response) do
    [encoded] = Regex.run(~r/data-page="([^"]+)"/, response, capture: :all_but_first)

    encoded
    |> String.replace("&quot;", "\"")
    |> String.replace("&#39;", "'")
    |> String.replace("&amp;", "&")
    |> Jason.decode!()
  end
end
