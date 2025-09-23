defmodule BrowsergridWeb.API.V1.ChangesetJSON do
  @moduledoc """
  JSON view for changeset errors.
  """

  def error(%{changeset: changeset}) do
    %{
      success: false,
      errors: Ecto.Changeset.traverse_errors(changeset, &translate_error/1)
    }
  end

  defp translate_error({msg, opts}) do
    Enum.reduce(opts, msg, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", fn _ -> to_string(value) end)
    end)
  end
end
