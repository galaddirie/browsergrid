# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Browsergrid.Repo.insert!(%Browsergrid.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias Browsergrid.Accounts
alias Browsergrid.Accounts.User
alias Browsergrid.Repo
alias Browsergrid.SessionPools

# Import required modules

# Seed a non-admin user
IO.puts("Creating non-admin user...")

case Accounts.get_user_by_email("user@example.com") do
  nil ->
    # User doesn't exist, create them
    {:ok, user} =
      Accounts.register_user(%{
        email: "user@example.com",
        password: "password123456"
      })

    # Confirm the user account
    user
    |> User.confirm_changeset()
    |> Repo.update!()

    IO.puts("Non-admin user created and confirmed: #{user.email}")

  existing_user ->
    # User already exists
    IO.puts("Non-admin user already exists: #{existing_user.email}")
end

IO.puts("Ensuring default system session pool exists...")
SessionPools.ensure_system_pools!()
IO.puts("Default system session pool is ready.")
