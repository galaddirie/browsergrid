defmodule Browsergrid.Auth.PhoenixProvider do
  @moduledoc """
  Phoenix-based authentication provider using phx.gen.auth.

  This provider implements password-based authentication with
  email confirmation, password reset, and session management.
  """

  @behaviour Browsergrid.Auth.Provider

  alias Browsergrid.Accounts
  alias Browsergrid.Accounts.User

  @impl true
  def authenticate(email, password) when is_binary(email) and is_binary(password) do
    case Accounts.get_user_by_email_and_password(email, password) do
      %User{} = user -> {:ok, user}
      nil -> {:error, :invalid_credentials}
    end
  end

  @impl true
  def register(attrs) when is_map(attrs) do
    Accounts.register_user(attrs)
  end

  @impl true
  def verify_session(token) when is_binary(token) do
    case Accounts.get_user_by_session_token(token) do
      %User{} = user -> {:ok, user}
      nil -> {:error, :invalid_token}
    end
  end

  @impl true
  def revoke_session(token) when is_binary(token) do
    Accounts.delete_user_session_token(token)
  end

  @impl true
  def generate_session_token(%User{} = user) do
    Accounts.generate_user_session_token(user)
  end

  @impl true
  def current_user(conn) do
    conn.assigns[:current_user]
  end
end
