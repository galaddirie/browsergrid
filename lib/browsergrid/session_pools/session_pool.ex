defmodule Browsergrid.SessionPools.SessionPool do
  @moduledoc """
  Schema for session pools that manage prewarmed browser sessions.
  """
  use Browsergrid.Schema

  import Ecto.Changeset

  @derive {Jason.Encoder, except: [:__meta__, :owner, :sessions]}

  schema "session_pools" do
    field :name, :string
    field :description, :string
    field :session_template, :map, default: %{}
    field :target_ready, :integer, default: 0
    field :ttl_seconds, :integer
    field :system, :boolean, default: false

    belongs_to :owner, Browsergrid.Accounts.User, type: :binary_id
    has_many :sessions, Browsergrid.Sessions.Session, foreign_key: :session_pool_id

    timestamps()
  end

  @doc false
  def changeset(pool, attrs) do
    pool
    |> cast(attrs, [:name, :description, :session_template, :target_ready, :ttl_seconds])
    |> validate_required([:name])
    |> validate_number(:target_ready, greater_than_or_equal_to: 0)
    |> validate_ttl()
    |> validate_template()
    |> unique_constraint([:owner_id, :name], name: :session_pools_owner_id_name_index)
  end

  @doc false
  def create_changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:name, :description, :session_template, :target_ready, :ttl_seconds, :system, :owner_id])
    |> validate_required([:name])
    |> validate_number(:target_ready, greater_than_or_equal_to: 0)
    |> validate_ttl()
    |> validate_template()
    |> unique_constraint([:owner_id, :name], name: :session_pools_owner_id_name_index)
  end

  defp validate_ttl(changeset) do
    ttl = get_field(changeset, :ttl_seconds)

    cond do
      is_nil(ttl) ->
        changeset

      is_integer(ttl) and ttl > 0 ->
        changeset

      true ->
        add_error(changeset, :ttl_seconds, "must be a positive integer")
    end
  end

  defp validate_template(changeset) do
    template = get_field(changeset, :session_template)

    if is_map(template) do
      changeset
    else
      add_error(changeset, :session_template, "must be a map")
    end
  end
end
