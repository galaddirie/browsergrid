defmodule Browsergrid.Routing.Route do
  @moduledoc """
  Authoritative routing table entry: session_id -> ip:port, versioned for snapshots.
  """
  use Browsergrid.Schema

  @type t :: %__MODULE__{
          id: Ecto.UUID.t(),
          ip: String.t(),
          port: non_neg_integer(),
          version: non_neg_integer(),
          inserted_at: NaiveDateTime.t(),
          updated_at: NaiveDateTime.t()
        }

  @primary_key {:id, :binary_id, autogenerate: false}
  schema "routes" do
    field :ip, :string
    field :port, :integer
    field :version, :integer

    timestamps()
  end

  def changeset(route, attrs) do
    route
    |> cast(attrs, [:ip, :port])
    |> validate_required([:ip, :port])
    |> put_version()
  end

  defp put_version(changeset) do
    # TODO: monotonic version based on DB sequence? should this change?
    current = get_field(changeset, :version)

    if current do
      changeset
    else
      put_change(changeset, :version, System.system_time(:nanosecond))
    end
  end
end
