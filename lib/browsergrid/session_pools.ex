defmodule Browsergrid.SessionPools do
  @moduledoc """
  Context for managing session pools that keep prewarmed browser sessions ready
  for instant allocation.
  """
  import Ecto.Query, warn: false

  alias Browsergrid.Accounts.User
  alias Browsergrid.Repo
  alias Browsergrid.SessionPools.SessionPool
  alias Browsergrid.Sessions
  alias Browsergrid.Sessions.Session

  require Logger

  @attachment_wait_seconds 10

  @type pool_id :: Ecto.UUID.t()
  @type claim_result :: {:ok, Session.t()} | {:error, :not_found | :no_available_sessions}

  @doc """
  Return pools visible to the given user (system pools + user-owned pools).
  """
  @spec list_visible_pools(User.t()) :: [SessionPool.t()]
  def list_visible_pools(%User{id: user_id}) do
    SessionPool
    |> where([p], p.system == true or p.owner_id == ^user_id)
    |> order_by([p], asc: p.system, asc: p.name)
    |> Repo.all()
  end

  @doc """
  Retrieve a pool by id. The atom `:default` resolves to the default system pool.
  """
  @spec fetch_pool(pool_id() | :default) :: {:ok, SessionPool.t()} | {:error, :not_found}
  def fetch_pool(:default) do
    case Repo.one(from p in SessionPool, where: p.system == true, order_by: [asc: p.inserted_at], limit: 1) do
      nil -> {:error, :not_found}
      pool -> {:ok, pool}
    end
  end

  def fetch_pool(id) when is_binary(id) do
    case Repo.get(SessionPool, id) do
      nil -> {:error, :not_found}
      pool -> {:ok, pool}
    end
  end

  @doc """
  List all session pools.
  """
  @spec list_pools() :: [SessionPool.t()]
  def list_pools do
    SessionPool
    |> order_by([p], asc: p.system, asc: p.inserted_at)
    |> Repo.all()
  end

  @doc """
  Ensure all system pools defined in configuration exist and are up to date.
  """
  @spec ensure_system_pools!() :: :ok
  def ensure_system_pools! do
    Enum.each(system_pools_config(), &ensure_system_pool_config/1)
    :ok
  end

  @doc """
  Create a custom session pool for the given owner.
  """
  @spec create_pool(map(), User.t()) :: {:ok, SessionPool.t()} | {:error, Ecto.Changeset.t()}
  def create_pool(attrs, %User{} = owner) when is_map(attrs) do
    attrs
    |> normalize_custom_attrs(owner)
    |> SessionPool.create_changeset()
    |> Repo.insert()
    |> tap(fn
      {:ok, pool} ->
        Logger.info("Created session pool #{pool.name} for user #{pool.owner_id}")
        reconcile_pool(pool)

      {:error, changeset} ->
        Logger.warning("Failed to create session pool: #{inspect(changeset.errors)}")
    end)
  end

  @doc """
  Update a pool. System pools ignore attempts to toggle system flag or change owner.
  """
  @spec update_pool(SessionPool.t(), map()) :: {:ok, SessionPool.t()} | {:error, Ecto.Changeset.t()}
  def update_pool(%SessionPool{} = pool, attrs) when is_map(attrs) do
    attrs =
      attrs
      |> stringify_keys()
      |> alias_key("pool_size", "min_ready")
      |> alias_key("target_ready", "min_ready")
      |> alias_key("min", "min_ready")
      |> alias_key("max", "max_ready")
      |> alias_key("idle_shutdown_after", "idle_shutdown_after_ms")
      |> Map.drop(if pool.system, do: ["owner_id", "system"], else: [])
      |> Map.update("idle_shutdown_after_ms", nil, &normalize_idle_shutdown/1)
      |> Map.update("session_template", nil, &normalize_template/1)

    pool
    |> SessionPool.changeset(attrs)
    |> Repo.update()
    |> tap(fn
      {:ok, updated} ->
        reconcile_pool(updated)

      {:error, changeset} ->
        Logger.warning("Failed to update session pool #{pool.id}: #{inspect(changeset.errors)}")
    end)
  end

  @doc """
  Delete a custom pool. System pools cannot be deleted.
  """
  @spec delete_pool(SessionPool.t()) :: {:ok, SessionPool.t()} | {:error, :system_pool | :active_sessions}
  def delete_pool(%SessionPool{system: true}), do: {:error, :system_pool}

  def delete_pool(%SessionPool{} = pool) do
    case Repo.aggregate(pool_session_scope(pool.id), :count, :id) do
      0 ->
        Repo.delete(pool)

      _ ->
        {:error, :active_sessions}
    end
  end

  @doc """
  Claim a ready session from the pool for the given user.
  """
  @spec claim_session(SessionPool.t(), User.t()) :: claim_result()
  def claim_session(%SessionPool{} = pool, %User{} = user) do
    fn ->
      case next_ready_session(pool.id) do
        nil ->
          Repo.rollback(:no_available_sessions)

        %Session{} = session ->
          now = DateTime.utc_now()
          deadline = DateTime.add(now, @attachment_wait_seconds, :second)
          session_user_id = target_user_id_for_claim(pool, user)

          session
          |> Session.status_changeset(:claimed)
          |> Ecto.Changeset.change(
            claimed_at: now,
            attachment_deadline_at: deadline,
            user_id: session_user_id
          )
          |> Repo.update()
          |> case do
            {:ok, claimed} ->
              {:ok, claimed}

            {:error, changeset} ->
              Repo.rollback({:error, changeset})
          end
      end
    end
    |> Repo.transaction()
    |> case do
      {:ok, {:ok, session}} ->
        Logger.debug("Claimed session #{session.id} from pool #{pool.id}")
        reconcile_pool(pool)
        {:ok, session}

      {:error, :no_available_sessions} ->
        {:error, :no_available_sessions}

      {:error, {:error, changeset}} ->
        Logger.error("Failed to claim session from pool #{pool.id}: #{inspect(changeset.errors)}")
        {:error, :no_available_sessions}
    end
  end

  @doc """
  Resolve a pool identifier for claiming and ensure the user is allowed to claim from it.
  """
  @spec fetch_pool_for_claim(String.t() | atom() | nil, User.t()) ::
          {:ok, SessionPool.t()} | {:error, term()}
  def fetch_pool_for_claim(identifier, %User{} = user) do
    with {:ok, pool} <- resolve_pool_identifier(identifier),
         :ok <- authorize_claim(pool, user) do
      {:ok, pool}
    end
  end

  @doc """
  Resolve a session pool identifier, treating nil or \"default\" as the default system pool.
  """
  @spec resolve_pool_identifier(String.t() | atom() | nil) ::
          {:ok, SessionPool.t()} | {:error, :not_found}
  def resolve_pool_identifier(identifier)

  def resolve_pool_identifier(nil), do: fetch_pool(:default)
  def resolve_pool_identifier(""), do: fetch_pool(:default)
  def resolve_pool_identifier(:default), do: fetch_pool(:default)
  def resolve_pool_identifier("default"), do: fetch_pool(:default)
  def resolve_pool_identifier(identifier) when is_binary(identifier), do: fetch_pool(identifier)

  @doc """
  Authorize a user to claim sessions from the given pool.
  """
  @spec authorize_claim(SessionPool.t(), User.t()) :: :ok | {:error, :forbidden}
  def authorize_claim(%SessionPool{system: true}, _user), do: :ok

  def authorize_claim(%SessionPool{owner_id: owner_id}, %User{id: user_id}) when owner_id == user_id, do: :ok

  def authorize_claim(_pool, _user), do: {:error, :forbidden}

  @doc """
  Reconcile a pool ensuring the desired number of ready sessions.
  """
  @spec reconcile_pool(SessionPool.t()) :: :ok
  def reconcile_pool(%SessionPool{id: pool_id} = pool) do
    prune_idle_sessions(pool)

    {ready, warming} = ready_and_warming_counts(pool_id)
    min_ready = pool.min_ready || 0
    current_total = ready + warming
    missing = max(min_ready - current_total, 0)

    missing =
      case pool.max_ready do
        max when is_integer(max) and max > 0 ->
          allowed = max - current_total
          if allowed < 0, do: 0, else: min(missing, allowed)

        _ ->
          missing
      end

    started =
      if missing > 0 do
        Enum.reduce(1..missing, 0, fn _idx, acc ->
          case start_prewarmed_session(pool) do
            {:ok, _session} ->
              acc + 1

            {:error, reason} ->
              Logger.error("Failed to prewarm session for pool #{pool.id}: #{inspect(reason)}")
              acc
          end
        end)
      else
        0
      end

    prune_excess_ready(pool, ready)

    if started > 0 do
      Logger.debug("Queued #{started} prewarm sessions for pool #{pool.id}")
    end

    :ok
  end

  @doc """
  Delete claimed sessions that failed to establish a WebSocket connection before their deadline.
  """
  @spec reap_expired_claims(SessionPool.t()) :: non_neg_integer()
  def reap_expired_claims(%SessionPool{id: pool_id}) do
    now = DateTime.utc_now()

    pool_id
    |> pool_session_scope()
    |> where([s], s.status == :claimed)
    |> where([s], not is_nil(s.attachment_deadline_at) and s.attachment_deadline_at < ^now)
    |> Repo.all()
    |> Enum.reduce(0, fn session, acc ->
      Logger.warning("Reaping expired claimed session #{session.id}", pool_id: pool_id)

      case Sessions.delete_session(session) do
        {:ok, _deleted} -> acc + 1
        {:error, _reason} -> acc
      end
    end)
  end

  @doc """
  Return aggregate counts for a pool.
  """
  @spec pool_statistics(SessionPool.t()) :: map()
  def pool_statistics(%SessionPool{id: pool_id}) do
    base = pool_session_scope(pool_id)

    %{
      ready: count_status(base, [:ready]),
      warming: count_status(base, [:pending, :starting]),
      claimed: count_status(base, [:claimed]),
      running: count_status(base, [:running]),
      errored: count_status(base, [:error, :stopped])
    }
  end

  @doc """
  Return the pool configuration used by the runtime when creating sessions.
  """
  @spec session_template(SessionPool.t()) :: map()
  def session_template(%SessionPool{session_template: template}) when is_map(template) do
    template
  end

  def session_template(_pool), do: %{}

  defp start_prewarmed_session(%SessionPool{} = pool) do
    attrs = build_session_attrs(pool)
    Sessions.create_session(attrs)
  end

  defp target_user_id_for_claim(%SessionPool{system: true}, %User{id: user_id}), do: user_id
  defp target_user_id_for_claim(%SessionPool{owner_id: owner_id}, _user), do: owner_id

  defp ready_and_warming_counts(pool_id) do
    base = pool_session_scope(pool_id)
    ready = count_status(base, [:ready])
    warming = count_status(base, [:pending, :starting])
    {ready, warming}
  end

  defp prune_idle_sessions(%SessionPool{id: pool_id, idle_shutdown_after_ms: idle_ms}) do
    if is_integer(idle_ms) and idle_ms > 0 do
      cutoff = DateTime.add(DateTime.utc_now(), -idle_ms, :millisecond)

      pool_id
      |> pool_session_scope()
      |> where([s], s.status == :ready)
      |> where([s], s.updated_at < ^cutoff)
      |> Repo.all()
      |> Enum.each(fn session ->
        Logger.debug("Pruning idle ready session #{session.id} from pool #{pool_id}")
        Sessions.delete_session(session)
      end)
    else
      :ok
    end
  end

  defp prune_excess_ready(%SessionPool{} = pool, ready_count) do
    cond do
      prune_to_max?(pool, ready_count) ->
        prune_ready_sessions(pool, ready_count - pool.max_ready)

      ready_count > (pool.min_ready || 0) ->
        prune_ready_sessions(pool, ready_count - (pool.min_ready || 0))

      true ->
        :ok
    end
  end

  defp prune_to_max?(%SessionPool{max_ready: max}, ready_count) when is_integer(max) and max > 0 do
    ready_count > max
  end

  defp prune_to_max?(_, _), do: false

  defp prune_ready_sessions(_pool, excess) when excess <= 0, do: :ok

  defp prune_ready_sessions(%SessionPool{id: pool_id}, excess) do
    pool_id
    |> pool_session_scope()
    |> where([s], s.status == :ready)
    |> order_by([s], asc: s.inserted_at)
    |> limit(^excess)
    |> Repo.all()
    |> Enum.each(fn session ->
      Logger.debug("Pruning excess ready session #{session.id} from pool #{pool_id}")
      Sessions.delete_session(session)
    end)
  end

  defp pool_session_scope(pool_id) do
    from s in Session, where: s.session_pool_id == ^pool_id
  end

  defp count_status(query, statuses) when is_list(statuses) do
    query
    |> where([s], s.status in ^statuses)
    |> Repo.aggregate(:count, :id)
  end

  defp next_ready_session(pool_id) do
    pool_id
    |> pool_session_scope()
    |> where([s], s.status == :ready)
    |> order_by([s], asc: s.inserted_at)
    |> lock("FOR UPDATE SKIP LOCKED")
    |> limit(1)
    |> Repo.one()
  end

  defp build_session_attrs(%SessionPool{} = pool) do
    template = normalize_template(pool.session_template)

    %{
      name: Map.get(template, "name") || pool_session_name(pool),
      browser_type: Map.get(template, "browser_type", "chrome"),
      headless: Map.get(template, "headless", false),
      screen: Map.get(template, "screen"),
      limits: Map.get(template, "limits"),
      timeout: Map.get(template, "timeout"),
      ttl_seconds: Map.get(template, "ttl_seconds"),
      profile_id: Map.get(template, "profile_id"),
      cluster: Map.get(template, "cluster"),
      session_pool_id: pool.id,
      user_id: pool_user_id(pool)
    }
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end

  defp pool_session_name(%SessionPool{name: name}) do
    suffix = :millisecond |> System.system_time() |> Integer.to_string() |> String.slice(-6, 6)
    "#{name} pool session #{suffix}"
  end

  defp pool_user_id(%SessionPool{system: true}), do: nil
  defp pool_user_id(%SessionPool{owner_id: owner_id}), do: owner_id

  defp system_pools_config do
    :browsergrid
    |> Application.get_env(:session_pools, [])
    |> Keyword.get(:system_pools, [
      %{
        name: "default",
        min_ready: 0,
        max_ready: 0,
        idle_shutdown_after_ms: 600_000,
        session_template: %{}
      }
    ])
  end

  defp ensure_system_pool_config(config) when is_map(config) do
    attrs = normalize_system_attrs(config)
    name = Map.fetch!(attrs, "name")

    case Repo.get_by(SessionPool, name: name, system: true) do
      nil ->
        Logger.info("Creating system session pool #{name}")

        attrs
        |> SessionPool.create_changeset()
        |> Repo.insert!()

      %SessionPool{} = pool ->
        update_attrs = Map.drop(attrs, ["name", "system"])

        pool
        |> SessionPool.changeset(update_attrs)
        |> Repo.update!()
    end
  end

  defp normalize_custom_attrs(attrs, owner) do
    attrs
    |> stringify_keys()
    |> alias_key("pool_size", "min_ready")
    |> alias_key("target_ready", "min_ready")
    |> alias_key("min", "min_ready")
    |> alias_key("max", "max_ready")
    |> alias_key("idle_shutdown_after", "idle_shutdown_after_ms")
    |> Map.put("owner_id", owner.id)
    |> Map.put("system", false)
    |> Map.put_new("idle_shutdown_after_ms", 600_000)
    |> Map.update("idle_shutdown_after_ms", nil, &normalize_idle_shutdown/1)
    |> Map.update("session_template", %{}, &normalize_template/1)
  end

  defp normalize_system_attrs(attrs) do
    attrs
    |> stringify_keys()
    |> alias_key("pool_size", "min_ready")
    |> alias_key("target_ready", "min_ready")
    |> alias_key("min", "min_ready")
    |> alias_key("max", "max_ready")
    |> alias_key("idle_shutdown_after", "idle_shutdown_after_ms")
    |> Map.put_new("min_ready", 0)
    |> Map.put_new("max_ready", 0)
    |> Map.put_new("idle_shutdown_after_ms", 600_000)
    |> Map.update("idle_shutdown_after_ms", nil, &normalize_idle_shutdown/1)
    |> Map.put_new("session_template", %{})
    |> Map.put("system", true)
    |> Map.update("session_template", %{}, &normalize_template/1)
  end

  defp normalize_template(nil), do: %{}
  defp normalize_template(%Ecto.Association.NotLoaded{}), do: %{}

  defp normalize_template(template) when is_map(template) do
    template
    |> stringify_keys()
    |> alias_key("ttl", "ttl_seconds")
    |> Map.take([
      "browser_type",
      "headless",
      "screen",
      "limits",
      "timeout",
      "ttl_seconds",
      "profile_id",
      "cluster",
      "name"
    ])
    |> Map.update("screen", nil, &normalize_screen/1)
    |> Map.update("limits", nil, &normalize_limits/1)
    |> Map.update("ttl_seconds", nil, &normalize_ttl/1)
  end

  defp normalize_template(_other), do: %{}

  defp normalize_screen(nil), do: nil
  defp normalize_screen(%{} = screen), do: stringify_keys(screen)
  defp normalize_screen(_), do: nil

  defp normalize_limits(nil), do: nil
  defp normalize_limits(%{} = limits), do: stringify_keys(limits)
  defp normalize_limits(_), do: nil

  defp normalize_ttl(nil), do: nil

  defp normalize_ttl(value) when is_binary(value) do
    case Integer.parse(value) do
      {parsed, _} -> normalize_ttl(parsed)
      :error -> nil
    end
  end

  defp normalize_ttl(value) when is_float(value) do
    value |> Float.round() |> trunc() |> normalize_ttl()
  end

  defp normalize_ttl(value) when is_integer(value) and value > 0, do: value
  defp normalize_ttl(_), do: nil

  defp normalize_idle_shutdown(nil), do: nil

  defp normalize_idle_shutdown(value) when is_binary(value) do
    case Integer.parse(value) do
      {parsed, _} -> normalize_idle_shutdown(parsed)
      :error -> nil
    end
  end

  defp normalize_idle_shutdown(value) when is_float(value) do
    value |> Float.round() |> trunc() |> normalize_idle_shutdown()
  end

  defp normalize_idle_shutdown(value) when is_integer(value) and value >= 0, do: value
  defp normalize_idle_shutdown(_), do: nil

  defp stringify_keys(map) when is_map(map) do
    Map.new(map, fn
      {key, value} when is_atom(key) -> {Atom.to_string(key), value}
      {key, value} -> {key, value}
    end)
  end

  defp alias_key(map, from, to) when from == to, do: map

  defp alias_key(map, from, to) do
    if Map.has_key?(map, from) do
      value = Map.get(map, from)

      map
      |> Map.delete(from)
      |> Map.put(to, value)
    else
      map
    end
  end
end
