defmodule Browsergrid.ApiTokens.ApiToken do
  @moduledoc """
  Schema for API access tokens.
  """
  use Browsergrid.Schema

  alias Browsergrid.Accounts.User

  schema "api_tokens" do
    field :name, :string
    field :token_hash, :binary
    field :token_prefix, :string
    field :expires_at, :utc_datetime_usec
    field :last_used_at, :utc_datetime_usec
    field :revoked_at, :utc_datetime_usec

    belongs_to :user, User

    timestamps()
  end

  @doc """
  Changeset used to persist new API tokens. Expects the hashed token and prefix
  to already be present in the attrs.
  """
  def create_changeset(%__MODULE__{} = token, attrs) do
    token
    |> cast(attrs, [:name, :token_hash, :token_prefix, :expires_at])
    |> validate_required([:name, :token_hash, :token_prefix])
    |> validate_length(:name, max: 160)
    |> validate_length(:token_prefix, is: 8)
    |> validate_future_datetime(:expires_at)
    |> validate_token_hash_size()
  end

  @doc """
  Changeset used when revoking a token.
  """
  def revoke_changeset(%__MODULE__{} = token, revoked_at) do
    change(token, revoked_at: revoked_at)
  end

  @doc """
  Changeset used to mark the last time a token was used.
  """
  def touch_changeset(%__MODULE__{} = token, timestamp) do
    change(token, last_used_at: timestamp)
  end

  def active?(%__MODULE__{} = token, now \\ DateTime.utc_now()) do
    is_nil(token.revoked_at) and (is_nil(token.expires_at) or DateTime.compare(token.expires_at, now) in [:gt, :eq])
  end

  defp validate_future_datetime(changeset, field) do
    validate_change(changeset, field, fn
      ^field, nil ->
        []

      ^field, %DateTime{} = datetime ->
        if DateTime.compare(datetime, DateTime.utc_now()) in [:gt, :eq] do
          []
        else
          [{field, "must be in the future"}]
        end
    end)
  end

  defp validate_token_hash_size(changeset) do
    validate_change(changeset, :token_hash, fn
      :token_hash, nil ->
        []

      :token_hash, value when is_binary(value) ->
        if byte_size(value) == 32 do
          []
        else
          [token_hash: "is invalid"]
        end
    end)
  end
end
