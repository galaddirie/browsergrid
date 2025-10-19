defmodule Browsergrid.SessionPoolsTest do
  use Browsergrid.DataCase, async: true

  import Mock

  alias Browsergrid.AccountsFixtures
  alias Browsergrid.Factory
  alias Browsergrid.SessionPools
  alias Browsergrid.Sessions

  describe "create_pool/2" do
    test "creates pool owned by the user and normalizes attributes" do
      owner = AccountsFixtures.user_fixture()

      attrs = %{
        name: "Team Chrome",
        description: "Prewarmed chrome sessions",
        pool_size: 0,
        ttl: 120
      }

      assert {:ok, pool} = SessionPools.create_pool(attrs, owner)
      assert pool.owner_id == owner.id
      refute pool.system
      assert pool.target_ready == 0
      assert pool.ttl_seconds == 120
    end
  end

  describe "claim_session/2" do
    test "transitions a ready session to claimed and sets attachment deadline" do
      owner = AccountsFixtures.user_fixture()
      {:ok, pool} = SessionPools.create_pool(%{name: "Pool", pool_size: 0}, owner)

      session =
        Factory.insert(:session,
          status: :ready,
          session_pool_id: pool.id,
          user_id: owner.id
        )

      assert {:ok, claimed} = SessionPools.claim_session(pool, owner)
      assert claimed.id == session.id
      assert claimed.status == :claimed
      assert claimed.user_id == owner.id
      assert claimed.attachment_deadline_at
      assert claimed.claimed_at
    end
  end

  describe "reap_expired_claims/1" do
    test "deletes sessions whose attachment deadline expired" do
      owner = AccountsFixtures.user_fixture()
      pool = Factory.insert(:session_pool, owner_id: owner.id, target_ready: 0)

      expired_session =
        Factory.insert(:session,
          status: :claimed,
          session_pool_id: pool.id,
          attachment_deadline_at: DateTime.add(DateTime.utc_now(), -20, :second),
          user_id: owner.id
        )

      with_mock Sessions, [:passthrough],
        delete_session: fn %{id: id} = session when id == expired_session.id ->
          {:ok, session}
        end do
        assert 1 == SessionPools.reap_expired_claims(pool)
        assert called(Sessions.delete_session(:_))
      end
    end
  end

  describe "reconcile_pool/1" do
    test "starts new sessions when ready capacity is below target" do
      owner = AccountsFixtures.user_fixture()
      pool = Factory.insert(:session_pool, owner_id: owner.id, target_ready: 2)

      with_mock Sessions, [:passthrough],
        create_session: fn attrs ->
          # Only intercept and assert for sessions created by pool reconciliation
          if Map.has_key?(attrs, :session_pool_id) do
            assert attrs[:session_pool_id] == pool.id
            assert attrs[:user_id] == owner.id
            {:ok, Factory.insert(:session, Map.put(attrs, :status, :pending))}
          else
            # For other sessions, call the real implementation
            Sessions.create_session(attrs)
          end
        end do
        assert :ok = SessionPools.reconcile_pool(pool)
        assert called(Sessions.create_session(:_))
      end
    end
  end
end
