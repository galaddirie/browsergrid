defmodule Browsergrid.Accounts.AdminBootstrapTest do
  use Browsergrid.DataCase, async: true

  alias Browsergrid.Accounts
  alias Browsergrid.Accounts.AdminBootstrap
  alias Browsergrid.Accounts.User

  setup do
    original_email = System.get_env("BROWSERGRID_ADMIN_EMAIL")
    original_password = System.get_env("BROWSERGRID_ADMIN_PASSWORD")

    on_exit(fn ->
      restore_env("BROWSERGRID_ADMIN_EMAIL", original_email)
      restore_env("BROWSERGRID_ADMIN_PASSWORD", original_password)
    end)

    Repo.delete_all(User)

    :ok
  end

  test "creates an admin user when none exist and env vars are present" do
    System.put_env("BROWSERGRID_ADMIN_EMAIL", "bootstrap@example.com")
    System.put_env("BROWSERGRID_ADMIN_PASSWORD", "supersecurepass")

    assert :ok = AdminBootstrap.ensure_admin_user!()

    user = Accounts.get_user_by_email("bootstrap@example.com")
    assert user
    assert user.confirmed_at
    assert user.is_admin
  end

  test "does not create a user when one already exists" do
    {:ok, existing_user} =
      Accounts.register_user(%{email: "existing@example.com", password: "supersecurepass"})

    System.put_env("BROWSERGRID_ADMIN_EMAIL", "bootstrap@example.com")
    System.put_env("BROWSERGRID_ADMIN_PASSWORD", "anothersecurepass")

    assert :ok = AdminBootstrap.ensure_admin_user!()

    assert Repo.aggregate(User, :count, :id) == 1
    refute Accounts.get_user_by_email(existing_user.email).is_admin
    refute Accounts.get_user_by_email("bootstrap@example.com")
  end

  test "skips creation when env configuration is missing" do
    System.delete_env("BROWSERGRID_ADMIN_EMAIL")
    System.put_env("BROWSERGRID_ADMIN_PASSWORD", "supersecurepass")

    assert :skipped = AdminBootstrap.ensure_admin_user!()
    assert Repo.aggregate(User, :count, :id) == 0
  end

  defp restore_env(name, nil), do: System.delete_env(name)
  defp restore_env(name, value), do: System.put_env(name, value)
end
