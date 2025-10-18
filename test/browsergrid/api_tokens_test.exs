defmodule Browsergrid.ApiTokensTest do
  use Browsergrid.DataCase, async: true

  alias Browsergrid.AccountsFixtures
  alias Browsergrid.ApiTokens
  alias Browsergrid.ApiTokens.ApiToken

  describe "create_token/2" do
    test "persists a hashed token and returns the plaintext once" do
      user = AccountsFixtures.user_fixture()

      {:ok, token, plaintext} =
        ApiTokens.create_token(user, %{"name" => "CI Deploy Key"})

      assert token.name == "CI Deploy Key"
      assert byte_size(token.token_hash) == 32
      assert String.starts_with?(plaintext, "bg_")
      assert token.token_prefix == String.slice(plaintext, 0, 8)
      assert token.user_id == user.id

      # Ensure the token cannot be recovered from the database
      refute to_string(token.token_hash) =~ plaintext
    end

    test "rejects tokens with past expirations" do
      user = AccountsFixtures.user_fixture()
      yesterday = DateTime.add(DateTime.utc_now(), -3600, :second)

      {:error, changeset} =
        ApiTokens.create_token(user, %{
          "name" => "Staging Token",
          "expires_at" => yesterday
        })

      assert "must be in the future" in errors_on(changeset).expires_at
    end
  end

  describe "list_user_tokens/1" do
    test "returns only active tokens for the given user" do
      user = AccountsFixtures.user_fixture()
      other_user = AccountsFixtures.user_fixture()

      {:ok, active_token, _} =
        ApiTokens.create_token(user, %{"name" => "Active"})

      {:ok, revoked_token, _} =
        ApiTokens.create_token(user, %{"name" => "Revoked"})

      {:ok, stale_token, _} =
        ApiTokens.create_token(user, %{"name" => "Expired Soon"})

      {:ok, _, _} =
        ApiTokens.create_token(other_user, %{"name" => "Foreign"})

      _ = ApiTokens.revoke_token(revoked_token.id, user)

      stale_token
      |> Ecto.Changeset.change(expires_at: DateTime.add(DateTime.utc_now(), -60, :second))
      |> Browsergrid.Repo.update!()

      tokens = ApiTokens.list_user_tokens(user)

      assert Enum.map(tokens, & &1.id) == [active_token.id]
    end
  end

  describe "revoke_token/2" do
    test "marks the token as revoked when owned by the user" do
      user = AccountsFixtures.user_fixture()
      {:ok, token, _} = ApiTokens.create_token(user, %{"name" => "Revoke Me"})

      {:ok, revoked} = ApiTokens.revoke_token(token.id, user)

      assert revoked.revoked_at
      assert {:error, :already_revoked} = ApiTokens.revoke_token(token.id, user)
    end

    test "returns not_found when token does not belong to user" do
      user = AccountsFixtures.user_fixture()
      other_user = AccountsFixtures.user_fixture()
      {:ok, token, _} = ApiTokens.create_token(other_user, %{"name" => "Foreign"})

      assert {:error, :not_found} = ApiTokens.revoke_token(token.id, user)
    end
  end

  describe "verify_token/1" do
    test "returns the associated user and updates last_used_at" do
      user = AccountsFixtures.user_fixture()
      {:ok, token, plaintext} = ApiTokens.create_token(user, %{"name" => "CLI"})

      assert {:ok, verified_user, verified_token} = ApiTokens.verify_token(plaintext)
      assert verified_user.id == user.id

      assert verified_token.last_used_at

      persisted = Browsergrid.Repo.get!(ApiToken, token.id)
      assert persisted.last_used_at
    end

    test "rejects revoked tokens" do
      user = AccountsFixtures.user_fixture()
      {:ok, token, plaintext} = ApiTokens.create_token(user, %{"name" => "Temporary"})
      {:ok, _} = ApiTokens.revoke_token(token.id, user)

      assert {:error, :revoked} = ApiTokens.verify_token(plaintext)
    end

    test "rejects expired tokens" do
      user = AccountsFixtures.user_fixture()
      {:ok, token, plaintext} =
        ApiTokens.create_token(user, %{
          "name" => "Expiring Soon",
          "expires_at" => DateTime.add(DateTime.utc_now(), 60, :second)
        })

      token
      |> Ecto.Changeset.change(expires_at: DateTime.add(DateTime.utc_now(), -60, :second))
      |> Browsergrid.Repo.update!()

      assert {:error, :expired} = ApiTokens.verify_token(plaintext)
    end

    test "rejects unknown tokens" do
      assert {:error, :invalid} = ApiTokens.verify_token("bg_invalid")
    end
  end
end
