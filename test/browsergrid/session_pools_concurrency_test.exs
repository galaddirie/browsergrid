defmodule Browsergrid.SessionPoolsConcurrencyTest do
  use Browsergrid.DataCase, async: false

  import Ecto.Query
  import Mock

  alias Browsergrid.AccountsFixtures
  alias Browsergrid.Factory
  alias Browsergrid.Repo
  alias Browsergrid.SessionPools
  alias Browsergrid.Sessions
  alias Browsergrid.Sessions.Session

  @active_statuses [:pending, :starting, :ready, :claimed, :running]

  describe "claim_or_provision_session/2 concurrency" do
    test "does not exceed max_ready capacity under contention" do
      owner = AccountsFixtures.user_fixture()

      pool =
        Factory.insert(:session_pool,
          owner_id: owner.id,
          min_ready: 0,
          max_ready: 5
        )

      with_mock Sessions, [:passthrough],
        create_session: fn attrs ->
          session =
            Factory.insert(:session,
              session_pool_id: attrs.session_pool_id,
              user_id: attrs.user_id,
              status: :ready
            )

          {:ok, session}
        end do
        results =
          1..20
          |> Task.async_stream(fn _ ->
            SessionPools.claim_or_provision_session(pool, owner)
          end,
            max_concurrency: 20,
            timeout: 30_000
          )
          |> Enum.map(fn {:ok, result} -> result end)

        success_count = Enum.count(results, &match?({:ok, _}, &1))
        assert success_count == 5

        failure_reasons =
          results
          |> Enum.filter(&match?({:error, _}, &1))
          |> Enum.map(fn {:error, reason} -> reason end)

        assert length(failure_reasons) == 15
        assert Enum.all?(failure_reasons, &(&1 == :pool_at_capacity))

        active_count =
          Session
          |> where([s], s.session_pool_id == ^pool.id)
          |> where([s], s.status in ^@active_statuses)
          |> Repo.aggregate(:count, :id)

        assert active_count == 5
      end
    end
  end
end
