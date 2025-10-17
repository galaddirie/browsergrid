# lib/browsergrid/storage/file.ex
defmodule Browsergrid.Storage.File do
  @moduledoc """
  Represents a file in storage with metadata
  """

  defstruct [
    :path,
    :size,
    :content_type,
    :metadata,
    :created_at,
    :backend,
    :url
  ]

  @type t :: %__MODULE__{
          path: String.t(),
          size: non_neg_integer(),
          content_type: String.t(),
          metadata: map(),
          created_at: DateTime.t(),
          backend: atom(),
          url: String.t() | nil
        }
end
