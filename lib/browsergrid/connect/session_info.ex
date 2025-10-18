defmodule Browsergrid.Connect.SessionInfo do
  @moduledoc """
  Represents the lifecycle state of a pooled browser session that can be
  claimed by clients through the Connect surface.
  """

  @enforce_keys [:id, :endpoint, :status, :metadata, :inserted_at]
  defstruct [
    :id,
    :endpoint,
    :metadata,
    :inserted_at,
    :claimed_by,
    :claimed_at,
    :timer_ref,
    :ws_monitor,
    :ws_pid,
    status: :starting
  ]

  @type status :: :starting | :idle | :claimed | :connected

  @type t :: %__MODULE__{
          id: String.t(),
          endpoint: %{host: String.t(), port: non_neg_integer(), scheme: String.t() | nil},
          metadata: map(),
          inserted_at: DateTime.t(),
          claimed_by: String.t() | nil,
          claimed_at: DateTime.t() | nil,
          timer_ref: reference() | nil,
          ws_monitor: reference() | nil,
          ws_pid: pid() | nil,
          status: status()
        }
end
