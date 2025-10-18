defmodule BrowsergridWeb.Inertia.V1.AccountSettingsController do
  use BrowsergridWeb, :controller

  alias Browsergrid.Accounts
  alias BrowsergridWeb.UserAuth

  def edit(conn, _params) do
    render_account(conn)
  end

  def update_email(conn, params) when is_map(params) do
    user = conn.assigns.current_user
    password = Map.get(params, "current_password", "")
    update_attrs = %{"email" => Map.get(params, "email", "")}

    case Accounts.apply_user_email(user, password, update_attrs) do
      {:ok, applied_user} ->
        Accounts.deliver_user_update_email_instructions(
          applied_user,
          user.email,
          &url(~p"/settings/account/confirm-email/#{&1}")
        )

        conn
        |> put_flash(
          :info,
          "A link to confirm your email change has been sent to the new address."
        )
        |> redirect(to: ~p"/settings/account")

      {:error, %Ecto.Changeset{} = changeset} ->
        errors = format_changeset_errors(changeset)

        conn
        |> put_status(:unprocessable_entity)
        |> render_account(
          email_form: %{
            "email" => Map.get(params, "email", user.email)
          },
          email_errors: errors,
          errors: errors
        )
    end
  end

  def update_password(conn, params) when is_map(params) do
    user = conn.assigns.current_user
    password = Map.get(params, "current_password", "")

    update_attrs = %{
      "password" => Map.get(params, "password", ""),
      "password_confirmation" => Map.get(params, "password_confirmation", "")
    }

    case Accounts.update_user_password(user, password, update_attrs) do
      {:ok, user} ->
        conn
        |> put_flash(:info, "Password updated successfully.")
        |> put_session(:user_return_to, ~p"/settings/account")
        |> UserAuth.log_in_user(user)

      {:error, %Ecto.Changeset{} = changeset} ->
        errors = format_changeset_errors(changeset)

        conn
        |> put_status(:unprocessable_entity)
        |> render_account(
          password_errors: errors,
          errors: errors
        )
    end
  end

  def confirm_email(conn, %{"token" => token}) do
    case Accounts.update_user_email(conn.assigns.current_user, token) do
      :ok ->
        conn
        |> put_flash(:info, "Email changed successfully.")
        |> redirect(to: ~p"/settings/account")

      :error ->
        conn
        |> put_flash(:error, "Email change link is invalid or it has expired.")
        |> redirect(to: ~p"/settings/account")
    end
  end

  defp render_account(conn, opts \\ []) do
    user = conn.assigns.current_user

    email_form =
      opts
      |> Keyword.get(:email_form, %{
        "email" => user.email,
        "current_password" => ""
      })
      |> Map.put_new("current_password", "")

    password_form = Keyword.get(opts, :password_form, default_password_form())
    errors = Keyword.get(opts, :errors, %{})

    conn
    |> assign_prop(:errors, errors)
    |> assign_prop(:account, %{
      email: user.email
    })
    |> assign_prop(:email_form, email_form)
    |> assign_prop(:password_form, password_form)
    |> assign_prop(:email_errors, Keyword.get(opts, :email_errors, %{}))
    |> assign_prop(:password_errors, Keyword.get(opts, :password_errors, %{}))
    |> render_inertia("Settings/Account")
  end

  defp default_password_form do
    %{
      "password" => "",
      "password_confirmation" => "",
      "current_password" => ""
    }
  end

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Enum.reduce(opts, message, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
