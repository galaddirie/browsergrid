defmodule Browsergrid.ApiTokens do
  @moduledoc """
  Context responsible for creating and managing API access tokens.
  """
  import Ecto.Query, warn: false

  alias Browsergrid.Accounts.User
  alias Browsergrid.ApiTokens.ApiToken
  alias Browsergrid.Repo

  @token_prefix "bg_"
  @token_length 32

  @doc """
  Creates a new API token for the given user. Returns the persisted token struct
  alongside the plaintext token, which should only be shown once to the user.
  """
  @spec create_token(User.t(), map()) ::
          {:ok, ApiToken.t(), String.t()} | {:error, Ecto.Changeset.t()}
  def create_token(%User{} = user, attrs \\ %{}) when is_map(attrs) do
    plaintext = generate_token()
    hash = hash_token(plaintext)
    prefix = String.slice(plaintext, 0, 8)

    params =
      attrs
      |> extract_attrs([:name, :expires_at])
      |> Map.put(:token_hash, hash)
      |> Map.put(:token_prefix, prefix)

    user
    |> Ecto.build_assoc(:api_tokens)
    |> ApiToken.create_changeset(params)
    |> Repo.insert()
    |> case do
      {:ok, token} -> {:ok, token, plaintext}
      {:error, changeset} -> {:error, changeset}
    end
  end

  @doc """
  Returns all active (non-revoked and non-expired) tokens for the given user.
  """
  @spec list_user_tokens(User.t()) :: [ApiToken.t()]
  def list_user_tokens(%User{} = user) do
    now = DateTime.utc_now()

    ApiToken
    |> where(user_id: ^user.id)
    |> where([t], is_nil(t.revoked_at))
    |> where([t], is_nil(t.expires_at) or t.expires_at > ^now)
    |> order_by(desc: :inserted_at)
    |> Repo.all()
  end

  @doc """
  Marks the given token as revoked for the provided user.
  """
  @spec revoke_token(Ecto.UUID.t(), User.t()) ::
          {:ok, ApiToken.t()} | {:error, :not_found | :already_revoked}
  def revoke_token(token_id, %User{} = user) when is_binary(token_id) do
    with {:ok, _uuid} <- cast_uuid(token_id),
         %ApiToken{} = token <- Repo.get_by(ApiToken, id: token_id, user_id: user.id) do
      if token.revoked_at do
        {:error, :already_revoked}
      else
        timestamp = current_timestamp()

        token
        |> ApiToken.revoke_changeset(timestamp)
        |> Repo.update()
      end
    else
      :error -> {:error, :not_found}
      nil -> {:error, :not_found}
    end
  end

  @doc """
  Verifies a plaintext token string and returns the associated user and token.
  """
  @spec verify_token(String.t()) ::
          {:ok, User.t(), ApiToken.t()} | {:error, :invalid | :revoked | :expired}
  def verify_token(token) when is_binary(token) do
    hashed = hash_token(token)

    case Repo.get_by(ApiToken, token_hash: hashed) do
      nil ->
        {:error, :invalid}

      %ApiToken{} = api_token ->
        api_token = Repo.preload(api_token, :user)

        cond do
          api_token.revoked_at ->
            {:error, :revoked}

          token_expired?(api_token) ->
            {:error, :expired}

          true ->
            case touch_token(api_token) do
              {:ok, updated} ->
                {:ok, updated.user, updated}

              {:error, _changeset} ->
                {:error, :invalid}
            end
        end
    end
  end

  def verify_token(_), do: {:error, :invalid}

  @doc """
  Updates the `last_used_at` timestamp for a token.
  """
  @spec touch_token(ApiToken.t()) :: {:ok, ApiToken.t()} | {:error, Ecto.Changeset.t()}
  def touch_token(%ApiToken{} = token) do
    timestamp = current_timestamp()

    case Repo.update(ApiToken.touch_changeset(token, timestamp)) do
      {:ok, updated} ->
        updated_with_user =
          if loaded_user?(updated) do
            updated
          else
            Repo.preload(updated, :user)
          end

        {:ok, updated_with_user}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  defp generate_token do
    random = :crypto.strong_rand_bytes(@token_length)
    encoded = Base.url_encode64(random, padding: false)
    @token_prefix <> encoded
  end

  defp hash_token(token) do
    :crypto.hash(:sha256, token)
  end

  defp extract_attrs(attrs, keys) do
    Enum.reduce(keys, %{}, fn key, acc ->
      case fetch_key(attrs, key) do
        nil -> acc
        value -> Map.put(acc, key, normalize_value(key, value))
      end
    end)
  end

  defp fetch_key(attrs, key) do
    Map.get(attrs, key) ||
      Map.get(attrs, Atom.to_string(key))
  end

  defp normalize_value(:expires_at, "" = _value), do: nil
  defp normalize_value(_key, value), do: value

  defp cast_uuid(id) do
    Ecto.UUID.cast(id)
  end

  defp token_expired?(%ApiToken{expires_at: nil}), do: false

  defp token_expired?(%ApiToken{expires_at: expires_at}) do
    DateTime.before?(expires_at, DateTime.utc_now())
  end

  defp current_timestamp do
    DateTime.truncate(DateTime.utc_now(), :microsecond)
  end

  defp loaded_user?(%ApiToken{user: %Ecto.Association.NotLoaded{}}), do: false
  defp loaded_user?(%ApiToken{user: nil}), do: false
  defp loaded_user?(%ApiToken{}), do: true
end
