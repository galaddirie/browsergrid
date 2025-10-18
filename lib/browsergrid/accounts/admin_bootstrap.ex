defmodule Browsergrid.Accounts.AdminBootstrap do
  @moduledoc """
  Boots an initial administrator account from environment configuration.

  If no users exist in the database, this module will attempt to create
  one using the `BROWSERGRID_ADMIN_EMAIL` and `BROWSERGRID_ADMIN_PASSWORD`
  environment variables. Subsequent boots are no-ops once at least one user
  exists.
  """

  alias Browsergrid.Accounts
  alias Browsergrid.Accounts.User
  alias Browsergrid.Repo
  alias Ecto.Changeset

  require Logger

  @spec ensure_admin_user!() :: :ok | :skipped | :error
  def ensure_admin_user! do
    case Repo.aggregate(User, :count, :id) do
      0 -> create_admin_from_env()
      _ -> :ok
    end
  rescue
    exception ->
      Logger.error("Failed to query users during admin bootstrap: #{Exception.message(exception)}")
      :error
  end

  defp create_admin_from_env do
    with {:email, {:ok, email}} <- {:email, fetch_env("BROWSERGRID_ADMIN_EMAIL")},
         {:password, {:ok, password}} <- {:password, fetch_env("BROWSERGRID_ADMIN_PASSWORD")},
         {:ok, user} <- Accounts.register_user(%{email: email, password: password}),
         {:ok, _confirmed} <-
           user
           |> User.confirm_changeset()
           |> Changeset.change(is_admin: true)
           |> Repo.update() do
      Logger.info("Created initial administrator account for #{email}.")
      :ok
    else
      {:email, :error} ->
        Logger.warning("""
        Skipping admin bootstrap: BROWSERGRID_ADMIN_EMAIL is not set.
        Provide BROWSERGRID_ADMIN_EMAIL/BROWSERGRID_ADMIN_PASSWORD to automatically create the first user.
        """)

        :skipped

      {:password, :error} ->
        Logger.warning("""
        Skipping admin bootstrap: BROWSERGRID_ADMIN_PASSWORD is not set.
        Provide BROWSERGRID_ADMIN_EMAIL/BROWSERGRID_ADMIN_PASSWORD to automatically create the first user.
        """)

        :skipped

      {:error, %Changeset{} = changeset} ->
        Logger.error("""
        Failed to create the initial administrator account: #{inspect(changeset.errors)}
        """)

        :error

      {:error, reason} ->
        Logger.error("Failed to persist the initial administrator account: #{inspect(reason)}")
        :error
    end
  end

  defp fetch_env(name) do
    name
    |> System.get_env()
    |> case do
      nil ->
        :error

      value ->
        value = String.trim(value)
        if value == "", do: :error, else: {:ok, value}
    end
  end
end
