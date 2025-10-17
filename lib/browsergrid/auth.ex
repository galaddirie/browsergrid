defmodule Browsergrid.Auth do
  @moduledoc """
  Authentication interface for Browsergrid.

  This module provides a provider-agnostic API for authentication.
  The actual implementation is delegated to the configured provider
  (Phoenix, Clerk, etc.).

  ## Configuration

      # config/config.exs
      config :browsergrid,
        auth_provider: Browsergrid.Auth.PhoenixProvider

  ## Usage

      # Authenticate a user
      {:ok, user} = Auth.authenticate("user@example.com", "password")

      # Register a new user
      {:ok, user} = Auth.register(%{email: "user@example.com", password: "password"})

      # Generate session token
      token = Auth.generate_session_token(user)

      # Verify session
      {:ok, user} = Auth.verify_session(token)
  """

  @provider Application.compile_env(
              :browsergrid,
              :auth_provider,
              Browsergrid.Auth.PhoenixProvider
            )

  @doc """
  Authenticates a user with email and password.
  """
  defdelegate authenticate(email, password), to: @provider

  @doc """
  Registers a new user.
  """
  defdelegate register(attrs), to: @provider

  @doc """
  Verifies a session token and returns the user.
  """
  defdelegate verify_session(token), to: @provider

  @doc """
  Revokes a session token.
  """
  defdelegate revoke_session(token), to: @provider

  @doc """
  Generates a session token for a user.
  """
  defdelegate generate_session_token(user), to: @provider

  @doc """
  Gets the current user from the connection.
  """
  defdelegate current_user(conn), to: @provider
end
