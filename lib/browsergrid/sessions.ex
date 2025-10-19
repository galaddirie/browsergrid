defmodule Browsergrid.Sessions do
  @moduledoc """
  Sessions context with idiomatic Elixir patterns
  """
  import Ecto.Query, warn: false

  alias Browsergrid.Accounts.User
  alias Browsergrid.Authorization
  alias Browsergrid.Repo
  alias Browsergrid.SessionRuntime
  alias Browsergrid.Sessions.Session
  alias Ecto.Changeset

  require Logger

  def list_sessions(opts \\ []) do
    Session
    |> maybe_filter_by_user(opts)
    |> apply_filters(opts)
    |> maybe_preload(opts)
    |> order_by(desc: :inserted_at)
    |> Repo.all()
  end

  @doc """
  Lists sessions owned by the given user. Admin users receive unscoped results.
  """
  @spec list_user_sessions(User.t(), Keyword.t()) :: [Session.t()]
  def list_user_sessions(%User{} = user, opts \\ []) do
    Session
    |> Authorization.scope_owned(user)
    |> apply_filters(opts)
    |> maybe_preload(opts)
    |> order_by(desc: :inserted_at)
    |> Repo.all()
  end

  def list_sessions_for_pool(pool_id, opts \\ []) when is_binary(pool_id) do
    Session
    |> where(session_pool_id: ^pool_id)
    |> maybe_preload(opts)
    |> order_by(desc: :inserted_at)
    |> Repo.all()
  end

  def get_session(id) when is_binary(id) do
    with {:ok, _} <- Ecto.UUID.cast(id),
         %Session{} = session <- Repo.get(Session, id) do
      {:ok, session}
    else
      nil -> {:error, :not_found}
      :error -> {:error, :invalid_id}
    end
  end

  def get_session!(id), do: Repo.get!(Session, id)

  @doc """
  Fetches a session owned by the given user. Returns `{:error, :not_found}` when
  the user does not own the session or it does not exist.
  """
  @spec fetch_user_session(User.t(), Ecto.UUID.t(), Keyword.t()) ::
          {:ok, Session.t()} | {:error, :invalid_id | :not_found}
  def fetch_user_session(user, id, opts \\ [])

  def fetch_user_session(%User{} = user, id, opts) when is_binary(id) do
    with {:ok, _uuid} <- Ecto.UUID.cast(id),
         %Session{} = session <-
           Session
           |> Authorization.scope_owned(user)
           |> where([s], s.id == ^id)
           |> maybe_preload(opts)
           |> Repo.one() do
      {:ok, session}
    else
      :error -> {:error, :invalid_id}
      nil -> {:error, :not_found}
    end
  end

  def fetch_user_session(_user, _id, _opts), do: {:error, :invalid_id}

  @doc """
  Fetches a session for a user but raises on failure.
  """
  @spec fetch_user_session!(User.t(), Ecto.UUID.t(), Keyword.t()) :: Session.t()
  def fetch_user_session!(%User{} = user, id, opts \\ []) do
    Session
    |> Authorization.scope_owned(user)
    |> where([s], s.id == ^id)
    |> maybe_preload(opts)
    |> Repo.one!()
  end

  def get_session_with_profile!(id) do
    Session
    |> preload(:profile)
    |> Repo.get!(id)
  end

  def create_session(attrs \\ %{}) do
    attrs
    |> Session.create_changeset()
    |> Repo.insert()
    |> tap(&broadcast_if_ok(&1, :created))
    |> case do
      {:ok, session} -> start_runtime_for(session)
      error -> error
    end
  end

  def create_session_with_profile(attrs, profile_id) do
    case Browsergrid.Profiles.get_profile(profile_id) do
      nil ->
        {:error, :not_found}

      profile ->
        attrs
        |> Map.put(:profile_id, profile_id)
        |> Map.put_new(:browser_type, profile.browser_type)
        |> create_session()
    end
  end

  def clone_session(%Session{} = session) do
    create_session(%{
      name: "#{session.name} (Clone)",
      browser_type: session.browser_type,
      screen: session.screen,
      limits: session.limits,
      headless: session.headless,
      timeout: session.timeout,
      ttl_seconds: session.ttl_seconds,
      profile_id: session.profile_id
    })
  end

  def update_session(%Session{} = session, attrs) do
    session
    |> Session.changeset(attrs)
    |> Repo.update()
    |> tap(&broadcast_if_ok(&1, :updated))
  end

  def update_status(%Session{} = session, status) when is_atom(status) do
    Logger.info("Session #{session.id} status: #{session.status} → #{status}")

    session
    |> Session.status_changeset(status)
    |> Repo.update()
    |> tap(&broadcast_if_ok(&1, :updated))
  end

  def update_status_by_id(session_id, status) when is_binary(session_id) do
    with {:ok, session} <- get_session(session_id) do
      update_status(session, status)
    end
  end

  def delete_session(%Session{} = session) do
    with :ok <- stop_runtime(session.id),
         {:ok, deleted} <- Repo.delete(session) do
      broadcast({:deleted, session.id})
      {:ok, deleted}
    end
  end

  def start_session(%Session{} = session) do
    Logger.info("Starting session #{session.id}")
    start_runtime_for(session)
  end

  def stop_session(%Session{} = session) do
    Logger.info("Stopping session #{session.id}")

    with {:ok, session} <- update_status(session, :stopping),
         :ok <- stop_runtime(session.id) do
      update_status(session, :stopped)
    end
  end

  def stop_session_with_cleanup(%Session{} = session) do
    Logger.info("Scheduling cleanup for session #{session.id}")
    stop_session(session)
  end

  def get_session_info(session_id) do
    with {:ok, session} <- get_session(session_id),
         {:ok, runtime} <- get_runtime_details(session_id) do
      {:ok, %{session: session, runtime: runtime}}
    end
  end

  def get_connection_info(session_id) do
    with {:ok, session} <- get_session(session_id),
         {:ok, _endpoint} <- SessionRuntime.upstream_endpoint(session.id) do
      edge_config = Application.get_env(:browsergrid, :edge, [])

      connection = %{
        http_proxy: build_proxy_url(edge_config, session.id, :http),
        ws_proxy: build_proxy_url(edge_config, session.id, :ws),
        session: session.id
      }

      {:ok, %{url: connection.http_proxy, connection: connection}}
    end
  end

  def get_sessions_by_profile(profile_id) do
    Session
    |> where(profile_id: ^profile_id)
    |> order_by(desc: :inserted_at)
    |> Repo.all()
  end

  def mark_session_attached(session_id) when is_binary(session_id) do
    with {:ok, session} <- get_session(session_id) do
      session
      |> attachment_ack_changeset()
      |> Repo.update()
      |> tap(&broadcast_if_ok(&1, :updated))
    end
  end

  def get_active_sessions_by_profile(profile_id) do
    Session
    |> where(profile_id: ^profile_id)
    |> where([s], s.status in [:pending, :running, :starting, :ready, :claimed])
    |> Repo.all()
  end

  def profile_in_use?(profile_id) do
    Session
    |> where(profile_id: ^profile_id)
    |> where([s], s.status in [:pending, :running, :starting, :ready, :claimed])
    |> Repo.exists?()
  end

  def get_statistics do
    sessions = list_sessions()
    by_status = Enum.frequencies_by(sessions, & &1.status)

    %{
      total: length(sessions),
      by_status: by_status,
      active:
        [:running, :pending, :starting, :ready, :claimed]
        |> Enum.map(&Map.get(by_status, &1, 0))
        |> Enum.sum(),
      available: Map.get(by_status, :pending, 0) + Map.get(by_status, :ready, 0),
      failed: Map.get(by_status, :error, 0) + Map.get(by_status, :stopped, 0)
    }
  end

  defdelegate change_session(session, attrs \\ %{}), to: Session, as: :changeset

  defp start_runtime_for(session) do
    with {:ok, session} <- update_status(session, :starting),
         {:ok, _pid} <- ensure_runtime_started(session) do
      target_status = if session.session_pool_id, do: :ready, else: :running
      update_status(session, target_status)
    else
      {:error, reason} = error ->
        Logger.error("Runtime start failed for session #{session.id}: #{inspect(reason)}")
        update_status(session, :error)
        error
    end
  end

  defp ensure_runtime_started(session) do
    opts = [
      metadata: Session.to_runtime_metadata(session),
      owner: nil,
      limits: serialize_limits(session.limits)
    ]

    SessionRuntime.ensure_session_started(session.id, opts)
  end

  defp stop_runtime(session_id) do
    SessionRuntime.stop_session(session_id)
  end

  defp get_runtime_details(session_id) do
    case SessionRuntime.describe(session_id) do
      {:ok, details} ->
        {:ok,
         %{
           endpoint: details.endpoint,
           node: details.node,
           metadata: details.metadata
         }}

      {:error, :not_found} ->
        {:ok, nil}

      error ->
        error
    end
  end

  defp build_proxy_url(config, session_id, type) do
    host = Keyword.get(config, :host, "edge.local")
    scheme = Keyword.get(config, :scheme, "https")

    scheme =
      case type do
        :ws -> if scheme == "https", do: "wss", else: "ws"
        :http -> scheme
      end

    protocol = if type == :ws, do: "ws", else: "http"
    "#{scheme}://#{host}/sessions/#{session_id}/#{protocol}"
  end

  defp serialize_limits(nil), do: %{}
  defp serialize_limits(%Ecto.Association.NotLoaded{}), do: %{}

  defp serialize_limits(limits) when is_map(limits) do
    %{
      "cpu" => Map.get(limits, "cpu"),
      "memory" => Map.get(limits, "memory"),
      "timeout_minutes" => Map.get(limits, "timeout_minutes")
    }
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
    |> Map.new()
  end

  defp maybe_preload(query, opts) do
    case Keyword.get(opts, :preload, false) do
      false -> query
      nil -> query
      true -> preload(query, [:profile, :user, session_pool: :owner])
      preloads when is_list(preloads) -> preload(query, ^preloads)
    end
  end

  defp maybe_filter_by_user(query, opts) do
    case Keyword.get(opts, :user) do
      %User{} = user ->
        Authorization.scope_owned(query, user)

      _ ->
        case Keyword.get(opts, :user_id) do
          nil -> query
          user_id -> where(query, [s], s.user_id == ^user_id)
        end
    end
  end

  defp apply_filters(query, opts) do
    Enum.reduce(opts, query, fn
      {:user, _}, q -> q
      {:user_id, _}, q -> q
      {:preload, _}, q -> q
      {:profile_id, profile_id}, q -> where(q, [s], s.profile_id == ^profile_id)
      {:session_pool_id, pool_id}, q -> where(q, [s], s.session_pool_id == ^pool_id)
      {:status, status}, q -> where(q, [s], s.status == ^status)
      _, q -> q
    end)
  end

  defp broadcast_if_ok({:ok, session}, event) do
    broadcast({event, session})
  end

  defp broadcast_if_ok(error, _event), do: error

  defp broadcast({:created, session}) do
    BrowsergridWeb.SessionChannel.broadcast_session_created(session)
  end

  defp broadcast({:updated, session}) do
    BrowsergridWeb.SessionChannel.broadcast_session_update(session)
  end

  defp broadcast({:deleted, session_id}) do
    BrowsergridWeb.SessionChannel.broadcast_session_deleted(session_id)
  end

  defp attachment_ack_changeset(%Session{} = session) do
    base_changeset =
      case session.status do
        status when status in [:claimed, :ready] -> Session.status_changeset(session, :running)
        _ -> Changeset.change(session)
      end

    Changeset.change(base_changeset, attachment_deadline_at: nil)
  end

  @doc """
  Returns `true` when the provided user owns the session (admins always pass).
  """
  @spec user_owns_session?(User.t() | nil, Session.t()) :: boolean()
  def user_owns_session?(user, %Session{} = session) do
    Authorization.owns?(user, session)
  end
end
