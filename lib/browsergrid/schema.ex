defmodule Browsergrid.Schema do
  @moduledoc """
  Custom schema wrapper for Ecto.Schema with sensible defaults.

  Sets up:
  - UUID primary keys (:binary_id)
  - UUID foreign keys (:binary_id)
  - Microsecond timestamps (:utc_datetime_usec)

  Use this instead of `use Ecto.Schema` in your schemas:

      defmodule MyApp.MySchema do
        use Browsergrid.Schema

        # rest of your schema...
      end
  """

  defmacro __using__(_) do
    quote do
      use Ecto.Schema

      import Ecto.Changeset

      @primary_key {:id, :binary_id, autogenerate: true}
      @foreign_key_type :binary_id
      @timestamps_opts [type: :utc_datetime_usec]
    end
  end
end
