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

  alias Browsergrid.Accounts.User
  alias Browsergrid.ApiKeys

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

  @doc """
  Creates an API key for the given user.

  This ensures API keys are owned by users and can be managed
  via the dashboard.
  """
  def create_api_key_for_user(%User{} = user, attrs \\ %{}) do
    attrs
    |> Map.put(:user_id, user.id)
    |> Map.put(:created_by, "#{user.email} (#{user.id})")
    |> ApiKeys.create_api_key()
  end

  @doc """
  Lists all API keys belonging to a user.
  """
  def list_user_api_keys(%User{} = user, opts \\ []) do
    opts
    |> Keyword.put(:user_id, user.id)
    |> ApiKeys.list_api_keys()
  end

  @doc """
  Gets an API key if it belongs to the user.
  """
  def get_user_api_key(%User{} = user, api_key_id) do
    case ApiKeys.get_api_key(api_key_id) do
      nil -> {:error, :not_found}
      api_key -> verify_ownership(api_key, user)
    end
  end

  @doc """
  Revokes an API key if it belongs to the user.
  """
  def revoke_user_api_key(%User{} = user, api_key_id, opts \\ []) do
    with {:ok, api_key} <- get_user_api_key(user, api_key_id) do
      ApiKeys.revoke_api_key(api_key, opts)
    end
  end

  @doc """
  Regenerates an API key if it belongs to the user.
  """
  def regenerate_user_api_key(%User{} = user, api_key_id, attrs \\ %{}) do
    attrs = Map.put(attrs, :user_id, user.id)

    with {:ok, api_key} <- get_user_api_key(user, api_key_id) do
      ApiKeys.regenerate_api_key(api_key, attrs)
    end
  end

  defp verify_ownership(%{user_id: user_id} = api_key, %User{id: user_id}), do: {:ok, api_key}
  defp verify_ownership(_api_key, _user), do: {:error, :forbidden}
end
