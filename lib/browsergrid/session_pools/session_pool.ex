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
    field :min_ready, :integer, default: 0
    field :max_ready, :integer, default: 0
    field :idle_shutdown_after_ms, :integer, default: 600_000
    field :system, :boolean, default: false

    belongs_to :owner, Browsergrid.Accounts.User, type: :binary_id
    has_many :sessions, Browsergrid.Sessions.Session, foreign_key: :session_pool_id

    timestamps()
  end

  @doc false
  def changeset(pool, attrs) do
    pool
    |> cast(attrs, [:name, :description, :session_template, :min_ready, :max_ready, :idle_shutdown_after_ms])
    |> validate_required([:name])
    |> ensure_defaults()
    |> validate_number(:min_ready, greater_than_or_equal_to: 0)
    |> validate_number(:max_ready, greater_than_or_equal_to: 0)
    |> validate_number(:idle_shutdown_after_ms, greater_than_or_equal_to: 0)
    |> validate_capacity_bounds()
    |> validate_template()
    |> unique_constraint([:owner_id, :name], name: :session_pools_owner_id_name_index)
  end

  @doc false
  def create_changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [
      :name,
      :description,
      :session_template,
      :min_ready,
      :max_ready,
      :idle_shutdown_after_ms,
      :system,
      :owner_id
    ])
    |> validate_required([:name])
    |> ensure_defaults()
    |> validate_number(:min_ready, greater_than_or_equal_to: 0)
    |> validate_number(:max_ready, greater_than_or_equal_to: 0)
    |> validate_number(:idle_shutdown_after_ms, greater_than_or_equal_to: 0)
    |> validate_capacity_bounds()
    |> validate_template()
    |> unique_constraint([:owner_id, :name], name: :session_pools_owner_id_name_index)
  end

  defp validate_capacity_bounds(changeset) do
    min_ready = get_field(changeset, :min_ready, 0)
    max_ready = get_field(changeset, :max_ready, 0)

    cond do
      max_ready in [nil, 0] ->
        changeset

      min_ready <= max_ready ->
        changeset

      true ->
        add_error(changeset, :max_ready, "must be zero (unlimited) or greater than or equal to min")
    end
  end

  defp ensure_defaults(changeset) do
    changeset
    |> put_default(:min_ready, 0)
    |> put_default(:max_ready, 0)
    |> put_default(:idle_shutdown_after_ms, 600_000)
  end

  defp put_default(changeset, field, default) do
    case get_field(changeset, field) do
      nil -> put_change(changeset, field, default)
      _ -> changeset
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
