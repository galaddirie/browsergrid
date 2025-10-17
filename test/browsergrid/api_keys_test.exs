defmodule Browsergrid.ApiKeysTest do
  use Browsergrid.DataCase, async: true

  alias Browsergrid.ApiKeys
  alias Browsergrid.ApiKeys.APIKey
  alias Browsergrid.ApiKeys.RateLimiter

  describe "create_api_key/1" do
    test "creates an API key and returns the raw token once" do
      {:ok, %{api_key: api_key, token: token}} = ApiKeys.create_api_key(%{"name" => "Primary"})

      assert String.starts_with?(token, "bg_")
      assert api_key.prefix =~ ~r/^[A-Z0-9]+$/
      assert api_key.last_four == String.slice(token, -4, 4)
      refute api_key.key_hash == token
      assert api_key.usage_count == 0
      assert {:ok, %APIKey{id: ^api_key.id}} = ApiKeys.verify_token(token)
    end

    test "validates presence of name" do
      assert {:error, changeset} = ApiKeys.create_api_key(%{})
      assert "can't be blank" in errors_on(changeset).name
    end
  end

  describe "verify_token/1" do
    test "rejects revoked tokens" do
      {:ok, %{api_key: api_key, token: token}} = ApiKeys.create_api_key(%{"name" => "Revokable"})
      assert {:ok, _} = ApiKeys.verify_token(token)

      {:ok, _} = ApiKeys.revoke_api_key(api_key)

      assert {:error, :revoked} = ApiKeys.verify_token(token)
    end

    test "rejects expired tokens" do
      expires_at = DateTime.add(DateTime.utc_now(), -60, :second)

      {:ok, %{token: token}} =
        ApiKeys.create_api_key(%{name: "Expired", expires_at: expires_at})

      assert {:error, :expired} = ApiKeys.verify_token(token)
    end
  end

  describe "register_usage/1" do
    test "increments usage count and stamps last_used_at" do
      {:ok, %{api_key: api_key, token: token}} = ApiKeys.create_api_key(%{"name" => "Usage"})
      assert {:ok, _} = ApiKeys.verify_token(token)

      assert {:ok, updated} = ApiKeys.register_usage(api_key)
      assert updated.usage_count == 1
      assert %DateTime{} = updated.last_used_at
    end
  end

  describe "regenerate_api_key/2" do
    test "revokes the old key and returns a new token" do
      {:ok, %{api_key: api_key, token: original_token}} = ApiKeys.create_api_key(%{"name" => "Rotate"})

      {:ok, %{api_key: new_key, token: new_token, revoked_key: revoked}} = ApiKeys.regenerate_api_key(api_key)

      assert revoked.id == api_key.id
      refute new_key.id == api_key.id
      assert {:error, :revoked} = ApiKeys.verify_token(original_token)
      assert {:ok, %APIKey{id: ^new_key.id}} = ApiKeys.verify_token(new_token)
    end
  end

  describe "rate limiting" do
    setup do
      {:ok, %{api_key: api_key}} = ApiKeys.create_api_key(%{"name" => "Limiter"})
      on_exit(fn -> RateLimiter.reset(api_key.id) end)
      %{api_key: api_key}
    end

    test "stops requests after the configured threshold", %{api_key: api_key} do
      assert {:ok, _} = ApiKeys.check_rate_limit(api_key, limit: 2, interval_ms: 50)
      assert {:ok, _} = ApiKeys.check_rate_limit(api_key, limit: 2, interval_ms: 50)
      assert {:error, :rate_limited, %{retry_after_ms: retry}} =
               ApiKeys.check_rate_limit(api_key, limit: 2, interval_ms: 50)

      assert retry >= 0
    end
  end
end
