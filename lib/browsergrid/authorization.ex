defmodule Browsergrid.Authorization do
  @moduledoc """
  Centralised helpers for applying per-user authorization rules across contexts.

  These helpers favour database-level scoping (so we never load data the user
  should not see) and explicit ownership checks with admin bypass.
  """

  import Ecto.Query, only: [where: 3]

  alias Browsergrid.Accounts.User

  @type scope_field :: atom()

  @doc """
  Restricts a queryable to records owned by the given user.

  Admin users bypass the scope, while anonymous users receive an empty scope.
  """
  @spec scope_owned(Ecto.Queryable.t(), User.t() | nil, Keyword.t()) :: Ecto.Query.t()
  def scope_owned(queryable, user, opts \\ [])
  def scope_owned(queryable, %User{is_admin: true}, _opts), do: queryable

  def scope_owned(queryable, %User{id: user_id}, opts) do
    field = Keyword.get(opts, :field, :user_id)
    where(queryable, [row], field(row, ^field) == ^user_id)
  end

  def scope_owned(queryable, nil, _opts) do
    where(queryable, [_row], false)
  end

  @doc """
  Answers whether the given user owns the supplied resource.

  Ownership defaults to the `:user_id` field but can be customised.
  Admin users always return `true`.
  """
  @spec owns?(User.t() | nil, map(), Keyword.t()) :: boolean()
  def owns?(user, resource, opts \\ [])
  def owns?(%User{is_admin: true}, _resource, _opts), do: true

  def owns?(%User{id: user_id}, resource, opts) when is_map(resource) do
    field = Keyword.get(opts, :field, :user_id)
    Map.get(resource, field) == user_id
  end

  def owns?(_, _resource, _opts), do: false
end
