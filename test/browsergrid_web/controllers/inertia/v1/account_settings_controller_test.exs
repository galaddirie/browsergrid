defmodule BrowsergridWeb.Inertia.V1.AccountSettingsControllerTest do
  use BrowsergridWeb.ConnCase, async: true

  import Browsergrid.AccountsFixtures

  alias Browsergrid.Accounts

  setup :register_and_log_in_user

  describe "GET /settings/account" do
    test "renders the inertia component", %{conn: conn} do
      conn = get(conn, ~p"/settings/account")
      response = html_response(conn, 200)

      [encoded] = Regex.run(~r/data-page="([^"]+)"/, response, capture: :all_but_first)

      json =
        encoded
        |> String.replace("&quot;", "\"")
        |> String.replace("&#39;", "'")
        |> String.replace("&amp;", "&")

      page = Jason.decode!(json)

      assert page["component"] == "Settings/Account"
    end

    test "redirects if user is not authenticated" do
      conn = build_conn()
      conn = get(conn, ~p"/settings/account")
      assert redirected_to(conn) == ~p"/users/log_in"
    end
  end

  describe "PUT /settings/account/password" do
    test "updates the user password and rotates tokens", %{conn: conn, user: user} do
      response_conn =
        put(conn, ~p"/settings/account/password", %{
          "current_password" => valid_user_password(),
          "password" => "new valid password",
          "password_confirmation" => "new valid password"
        })

      assert redirected_to(response_conn) == ~p"/settings/account"
      assert get_session(response_conn, :user_token) != get_session(conn, :user_token)

      assert Phoenix.Flash.get(response_conn.assigns.flash, :info) =~
               "Password updated successfully"

      assert Accounts.get_user_by_email_and_password(user.email, "new valid password")
    end

    test "returns validation errors on invalid params", %{conn: conn} do
      conn =
        conn
        |> put_req_header("x-inertia", "true")
        |> put_req_header("accept", "text/html, application/json")
        |> put(~p"/settings/account/password", %{
          "current_password" => "invalid",
          "password" => "short",
          "password_confirmation" => "mismatch"
        })

      data = json_response(conn, 200)

      password_errors =
        data
        |> get_in(["props", "password_errors", "password"])
        |> List.wrap()

      assert Enum.any?(password_errors, &String.contains?(&1, "at least 12"))
    end
  end

  describe "PUT /settings/account/email" do
    @tag :capture_log
    test "sends confirmation instructions on success", %{conn: conn, user: user} do
      conn =
        put(conn, ~p"/settings/account/email", %{
          "current_password" => valid_user_password(),
          "email" => unique_user_email()
        })

      assert redirected_to(conn) == ~p"/settings/account"

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "A link to confirm your email"

      assert Accounts.get_user_by_email(user.email)
    end

    test "returns validation errors when params invalid", %{conn: conn} do
      conn =
        conn
        |> put_req_header("x-inertia", "true")
        |> put_req_header("accept", "text/html, application/json")
        |> put(~p"/settings/account/email", %{
          "current_password" => "invalid",
          "email" => "bad email"
        })

      data = json_response(conn, 200)

      email_errors =
        data
        |> get_in(["props", "email_errors", "email"])
        |> List.wrap()

      assert Enum.any?(email_errors, &String.contains?(&1, "must have the @ sign"))
    end
  end

  describe "GET /settings/account/confirm-email/:token" do
    setup %{user: user} do
      email = unique_user_email()

      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_update_email_instructions(%{user | email: email}, user.email, url)
        end)

      %{token: token, email: email}
    end

    test "updates the user email once", %{conn: conn, user: user, token: token, email: email} do
      conn = get(conn, ~p"/settings/account/confirm-email/#{token}")
      assert redirected_to(conn) == ~p"/settings/account"

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Email changed successfully"

      refute Accounts.get_user_by_email(user.email)
      assert Accounts.get_user_by_email(email)

      conn = get(conn, ~p"/settings/account/confirm-email/#{token}")
      assert redirected_to(conn) == ~p"/settings/account"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Email change link is invalid or it has expired"
    end

    test "does not update email with invalid token", %{conn: conn, user: user} do
      conn = get(conn, ~p"/settings/account/confirm-email/oops")
      assert redirected_to(conn) == ~p"/settings/account"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Email change link is invalid or it has expired"

      assert Accounts.get_user_by_email(user.email)
    end

    test "redirects unauthenticated users to log in", %{token: token} do
      conn = build_conn()
      conn = get(conn, ~p"/settings/account/confirm-email/#{token}")
      assert redirected_to(conn) == ~p"/users/log_in"
    end
  end
end
