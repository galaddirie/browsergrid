defmodule Browsergrid.Auth.Provider do
  @moduledoc """
  Behaviour defining the authentication provider interface.

  This allows Browsergrid to support multiple authentication backends
  (Phoenix.Auth, Clerk, Auth0, etc.) by implementing this contract.
  """

  alias Browsergrid.Accounts.User

  @doc """
  Authenticates a user with email and password.
  Returns {:ok, user} on success, {:error, reason} on failure.
  """
  @callback authenticate(email :: String.t(), password :: String.t()) ::
              {:ok, User.t()} | {:error, atom()}

  @doc """
  Registers a new user with the given attributes.
  Returns {:ok, user} on success, {:error, changeset} on failure.
  """
  @callback register(attrs :: map()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}

  @doc """
  Verifies a session token and returns the associated user.
  Returns {:ok, user} on success, {:error, reason} on failure.
  """
  @callback verify_session(token :: String.t()) :: {:ok, User.t()} | {:error, atom()}

  @doc """
  Revokes/deletes a session token.
  Always returns :ok.
  """
  @callback revoke_session(token :: String.t()) :: :ok

  @doc """
  Generates a new session token for the given user.
  Returns the token string.
  """
  @callback generate_session_token(user :: User.t()) :: String.t()

  @doc """
  Extracts the current user from a Plug.Conn.
  Returns the user struct or nil if not authenticated.
  """
  @callback current_user(conn :: Plug.Conn.t()) :: User.t() | nil
end
