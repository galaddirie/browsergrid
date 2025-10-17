defmodule Browsergrid.ApiKeys.APIKey do
  @moduledoc """
  Schema representing an opaque API key credential.
  """

  use Browsergrid.Schema

  @prefix_length 4
  @last_four_length 4

  schema "api_keys" do
    field :name, :string
    field :key_hash, :string
    field :prefix, :string
    field :last_four, :string
    field :created_by, :string
    field :revoked_at, :utc_datetime_usec
    field :expires_at, :utc_datetime_usec
    field :last_used_at, :utc_datetime_usec
    field :usage_count, :integer, default: 0
    field :metadata, :map, default: %{}

    timestamps()
  end

  def create_changeset(api_key, attrs) do
    api_key
    |> cast(attrs, [:name, :key_hash, :prefix, :last_four, :created_by, :expires_at, :metadata])
    |> ensure_metadata()
    |> validate_required([:name, :key_hash, :prefix, :last_four])
    |> validate_length(:prefix, min: @prefix_length, max: 12)
    |> validate_length(:last_four, is: @last_four_length)
    |> validate_format(:prefix, ~r/^[A-Z0-9]+$/)
    |> validate_format(:last_four, ~r/^[A-Za-z0-9\-_]{4}$/)
    |> unique_constraint(:prefix)
  end

  def update_changeset(api_key, attrs) do
    api_key
    |> cast(attrs, [:name, :key_hash, :prefix, :last_four, :created_by, :revoked_at, :expires_at, :last_used_at, :usage_count, :metadata])
    |> ensure_metadata()
    |> validate_required([:name, :prefix, :last_four])
    |> validate_length(:prefix, min: @prefix_length, max: 12)
    |> validate_length(:last_four, is: @last_four_length)
    |> validate_format(:prefix, ~r/^[A-Z0-9]+$/)
    |> validate_format(:last_four, ~r/^[A-Za-z0-9\-_]{4}$/)
    |> unique_constraint(:prefix)
  end

  def active?(%__MODULE__{revoked_at: nil, expires_at: nil}), do: true

  def active?(%__MODULE__{revoked_at: nil, expires_at: expires_at}) do
    case expires_at do
      nil -> true
      %DateTime{} = dt -> DateTime.compare(dt, DateTime.utc_now()) == :gt
      _ -> false
    end
  end

  def active?(_), do: false

  defp ensure_metadata(changeset) do
    update_change(changeset, :metadata, fn
      nil -> %{}
      value when is_map(value) -> value
      _ -> %{}
    end)
  end
end
