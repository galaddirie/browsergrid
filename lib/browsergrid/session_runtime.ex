defmodule Browsergrid.SessionRuntime do
  @moduledoc """
  Cluster-aware session runtime built on Horde.

  Provides helpers to start/lookup session actors and exposes
  runtime configuration (state store adapter, Kubernetes settings, etc.).
  """

  alias Browsergrid.SessionRuntime.Session
  alias Browsergrid.SessionRuntime.SessionRegistry
  alias Browsergrid.SessionRuntime.SessionSupervisor
  alias Browsergrid.SessionRuntime.StateStore

  require Logger

  @default_config [
    checkpoint_interval_ms: 2_000,
    state_store: [
      adapter: Browsergrid.SessionRuntime.StateStore.DeltaCrdt,
      sync_interval_ms: 3_000,
      ttl_ms: to_timeout(minute: 30)
    ],
    browser: [
      mode: :kubernetes,
      http_port: 80,
      vnc_port: 6080,
      ready_path: "/health",
      ready_timeout_ms: 120_000,
      ready_poll_interval_ms: 1_000
    ],
    kubernetes: [
      enabled: true,
      namespace: "browsergrid",
      cluster_name: "default",
      service_account: nil,
      conn: :auto,
      image_repository: "browsergrid",
      image_tag: "latest",
      image_overrides: %{},
      request_cpu: "200m",
      request_memory: "512Mi",
      limit_cpu: "1",
      limit_memory: "2Gi",
      profile_volume_claim: nil,
      profile_volume_sub_path_prefix: "sessions",
      profile_volume_mount_path: "/home/user/data-dir",
      extra_env: []
    ]
  ]

  @type session_id :: String.t()

  @spec config() :: keyword()
  def config do
    :browsergrid
    |> Application.get_env(__MODULE__, [])
    |> deep_merge(@default_config)
  end

  @spec state_store_config() :: keyword()
  def state_store_config do
    Keyword.get(config(), :state_store, [])
  end

  @spec browser_config() :: keyword()
  def browser_config do
    Keyword.get(config(), :browser, [])
  end

  @spec kubernetes_config() :: keyword()
  def kubernetes_config do
    Keyword.get(config(), :kubernetes, [])
  end

  @spec checkpoint_interval_ms() :: non_neg_integer()
  def checkpoint_interval_ms do
    Keyword.get(config(), :checkpoint_interval_ms, 2_000)
  end

  @doc """
  Return Horde member list for a given component.
  """
  @spec horde_members(:registry | :supervisor) :: [{module(), node()}]
  def horde_members(component) when component in [:registry, :supervisor] do
    nodes = Enum.uniq([Node.self() | Node.list()])
    Enum.map(nodes, &{component_module(component), &1})
  end

  @doc """
  Start (or lookup) the session actor for the given id.
  """
  @spec ensure_session_started(session_id(), keyword()) :: {:ok, pid()} | {:error, term()}
  def ensure_session_started(session_id, opts \\ []) when is_binary(session_id) do
    case lookup(session_id) do
      {:ok, pid} ->
        {:ok, pid}

      :error ->
        spec = Session.child_spec(Keyword.put(opts, :session_id, session_id))

        case Horde.DynamicSupervisor.start_child(SessionSupervisor, spec) do
          {:ok, pid} -> {:ok, pid}
          {:error, {:already_started, pid}} -> {:ok, pid}
          {:error, :already_present} -> lookup(session_id)
          other -> other
        end
    end
  end

  @doc """
  Lookup the pid of an active session actor.
  """
  @spec lookup(session_id()) :: {:ok, pid()} | :error
  def lookup(session_id) when is_binary(session_id) do
    case Horde.Registry.lookup(SessionRegistry, session_id) do
      [{pid, _meta}] -> {:ok, pid}
      [] -> :error
    end
  end

  @doc """
  Retrieve the upstream connection details for an active session.
  """
  @spec upstream_endpoint(session_id()) :: {:ok, map()} | {:error, term()}
  def upstream_endpoint(session_id) when is_binary(session_id) do
    with {:ok, pid} <- lookup(session_id),
         {:ok, endpoint} <- GenServer.call(pid, :endpoint) do
      {:ok, endpoint}
    else
      :error -> {:error, :not_found}
      {:error, _} = error -> error
    end
  end

  @doc """
  Return the session actor's current metadata snapshot without starting it.
  """
  @spec describe(session_id()) :: {:ok, map()} | {:error, term()}
  def describe(session_id) when is_binary(session_id) do
    with {:ok, pid} <- lookup(session_id),
         {:ok, description} <- GenServer.call(pid, :describe) do
      {:ok, description}
    else
      :error -> {:error, :not_found}
      {:error, _} = error -> error
    end
  end

  @doc """
  Stop a session actor across the cluster.
  """
  @spec stop_session(session_id()) :: :ok | {:error, term()}
  def stop_session(session_id) when is_binary(session_id) do
    case lookup(session_id) do
      {:ok, pid} ->
        case Horde.DynamicSupervisor.terminate_child(SessionSupervisor, pid) do
          :ok -> :ok
          {:error, :not_found} -> :ok
          other -> other
        end

      :error ->
        :ok
    end
  end

  @doc """
  Return the `{:via, Horde.Registry, ...}` tuple for a session id.
  """
  @spec via_tuple(session_id()) :: {:via, Horde.Registry, {SessionRegistry, session_id()}}
  def via_tuple(session_id) when is_binary(session_id) do
    {:via, Horde.Registry, {SessionRegistry, session_id}}
  end

  @doc """
  Persist a snapshot for a session.
  """
  @spec persist_snapshot(session_id(), map()) :: :ok | {:error, term()}
  def persist_snapshot(session_id, snapshot) do
    StateStore.put(session_id, snapshot)
  end

  @doc """
  Fetch a session snapshot from the state store.
  """
  @spec fetch_snapshot(session_id()) :: {:ok, map()} | :error
  def fetch_snapshot(session_id) do
    StateStore.get(session_id)
  end

  @doc """
  Remove snapshot from state store.
  """
  @spec delete_snapshot(session_id()) :: :ok
  def delete_snapshot(session_id) do
    StateStore.delete(session_id)
  end

  @doc """
  Called by `NodeListener` whenever cluster membership changes.
  """
  @spec sync_horde_membership() :: :ok
  def sync_horde_membership do
    if not Node.alive?() do
      # When the Erlang node is running without distribution (e.g. MIX_ENV=dev in a
      # single container) there are no remote members to synchronise and Horde
      # will block attempting to contact the pseudo-node :nonode@nohost. Skip
      # the membership update in that case so callers don't hit GenServer timeouts.
      :ok
    else
      members_supervisor = horde_members(:supervisor)
      members_registry = horde_members(:registry)

      Horde.Cluster.set_members(SessionSupervisor, members_supervisor)
      Horde.Cluster.set_members(SessionRegistry, members_registry)
      :ok
    end
  end

  defp component_module(:registry), do: SessionRegistry
  defp component_module(:supervisor), do: SessionSupervisor

  defp deep_merge(cfg, defaults) do
    Enum.reduce(defaults, cfg, fn {key, default_value}, acc ->
      current_value = Keyword.get(acc, key)

      merged_value =
        case {default_value, current_value} do
          {dv, nil} ->
            dv

          {dv, cv} when is_list(dv) and is_list(cv) ->
            Keyword.merge(dv, cv, fn _k, v1, v2 ->
              case {v1, v2} do
                {list1, list2} when is_list(list1) and is_list(list2) -> Keyword.merge(list1, list2)
                _ -> v2
              end
            end)

          {_dv, cv} ->
            cv
        end

      Keyword.put(acc, key, merged_value)
    end)
  end
end
