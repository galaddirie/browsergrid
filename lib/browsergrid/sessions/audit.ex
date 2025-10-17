defmodule Browsergrid.Sessions.Audit do
  @moduledoc """
  Audit events for session lifecycle and operations.
  """
  use Browsergrid.Schema

  schema "session_audits" do
    field :action, :string
    field :metadata, :map, default: %{}
    belongs_to :session, Browsergrid.Sessions.Session, type: :binary_id
    timestamps()
  end

  def changeset(audit, attrs) do
    audit
    |> cast(attrs, [:action, :metadata, :session_id])
    |> validate_required([:action, :session_id])
  end
end
