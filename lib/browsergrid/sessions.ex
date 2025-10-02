defmodule Browsergrid.Sessions do
  @moduledoc """
  Sessions context - simplified CRUD and lifecycle management
  """
  import Ecto.Query, warn: false

  alias Browsergrid.Repo
  alias Browsergrid.SessionRuntime
  alias Browsergrid.Sessions.Session

  require Logger

  # ===== CRUD Operations =====

  @doc "List all sessions"
  def list_sessions do
    Session
    |> order_by([s], desc: s.inserted_at)
    |> Repo.all()
  end

  @doc "Get a single session"
  def get_session(id) do
    case Ecto.UUID.cast(id) do
      {:ok, _uuid} ->
        case Repo.get(Session, id) do
          nil -> {:error, :not_found}
          session -> {:ok, session}
        end
      :error ->
        {:error, :not_found}
    end
  end

  @doc "Get a single session, raises if not found"
  def get_session!(id), do: Repo.get!(Session, id)

  @doc "Create a session and start its runtime"
  def create_session(attrs \\ %{}) do
    with {:ok, session} <- create_session_record(attrs),
         {:ok, session} <- start_session_runtime(session) do
      broadcast_created(session)
      {:ok, session}
    end
  end

  @doc "Update a session"
  def update_session(%Session{} = session, attrs) do
    with {:ok, updated} <- do_update(session, attrs) do
      broadcast_updated(updated)
      {:ok, updated}
    end
  end

  @doc "Delete a session and stop its runtime"
  def delete_session(%Session{} = session) do
    with :ok <- stop_session_runtime(session),
         {:ok, deleted} <- Repo.delete(session) do
      broadcast_deleted(session.id)
      {:ok, deleted}
    end
  end

  # ===== Status Management =====

  @doc "Update session status"
  def update_status(%Session{} = session, status) when is_atom(status) do
    Logger.info("Updating session #{session.id} status: #{session.status} → #{status}")

    with {:ok, updated} <- do_status_update(session, status) do
      broadcast_updated(updated)
      {:ok, updated}
    end
  end

  @doc "Update session status by ID"
  def update_status_by_id(session_id, status) when is_binary(session_id) and is_atom(status) do
    case get_session(session_id) do
      {:ok, session} -> update_status(session, status)
      error -> error
    end
  end

  # ===== Runtime Operations =====

  @doc "Start a session's runtime actor"
  def start_session(%Session{} = session) do
    Logger.info("Starting session #{session.id}")
    start_session_runtime(session)
  end

  @doc "Stop a session's runtime actor"
  def stop_session(%Session{} = session) do
    Logger.info("Stopping session #{session.id}")

    with {:ok, session} <- update_status(session, :stopping) do
      :ok = SessionRuntime.stop_session(session.id)
      update_status(session, :stopped)
    end
  end

  @doc "Get session runtime info including node and endpoint"
  def get_session_info(session_id) do
    with {:ok, session} <- get_session(session_id),
         {:ok, runtime} <- get_runtime_info(session_id) do
      {:ok, %{session: session, runtime: runtime}}
    end
  end

  @doc "Get connection information (proxy URLs)"
  def get_connection_info(session_id) do
    with {:ok, %Session{id: id}} <- get_session(session_id),
         {:ok, _endpoint} <- SessionRuntime.upstream_endpoint(id) do

      edge_cfg = Application.get_env(:browsergrid, :edge, [])
      host = Keyword.get(edge_cfg, :host, "edge.local")
      scheme = Keyword.get(edge_cfg, :scheme, "https")
      ws_scheme = if scheme == "https", do: "wss", else: "ws"

      {:ok, %{
        http_proxy: "#{scheme}://#{host}/sessions/#{id}/http",
        ws_proxy: "#{ws_scheme}://#{host}/sessions/#{id}/ws",
        session: id
      }}
    end
  end

  # ===== Profile Integration =====

  @doc "Create session with a profile"
  def create_session_with_profile(attrs, profile_id) do
    attrs
    |> Map.put("profile_id", profile_id)
    |> create_session()
  end

  @doc "Get all sessions using a profile"
  def get_sessions_by_profile(profile_id) do
    Session
    |> where([s], s.profile_id == ^profile_id)
    |> order_by([s], desc: s.inserted_at)
    |> Repo.all()
  end

  @doc "Get active sessions using a profile"
  def get_active_sessions_by_profile(profile_id) do
    Session
    |> where([s], s.profile_id == ^profile_id)
    |> where([s], s.status in [:pending, :running, :starting])
    |> Repo.all()
  end

  @doc "Check if profile is in use"
  def profile_in_use?(profile_id) do
    Session
    |> where([s], s.profile_id == ^profile_id)
    |> where([s], s.status in [:pending, :running, :starting])
    |> Repo.exists?()
  end

  # ===== Statistics =====

  @doc "Get session statistics"
  def get_statistics do
    sessions = list_sessions()

    by_status =
      sessions
      |> Enum.group_by(& &1.status)
      |> Map.new(fn {status, sessions} -> {status, length(sessions)} end)

    %{
      total: length(sessions),
      by_status: by_status,
      active: Enum.count(sessions, &(&1.status in [:running, :pending])),
      available: Enum.count(sessions, &(&1.status == :pending)),
      failed: Enum.count(sessions, &(&1.status in [:error, :stopped]))
    }
  end

  # ===== Backwards Compatibility (if needed) =====

  def get_session_with_profile!(id) do
    Session
    |> preload(:profile)
    |> Repo.get!(id)
  end

  def clone_session(%Session{} = session) do
    attrs = %{
      name: "#{session.name} (Clone)",
      browser_type: session.browser_type,
      options: session.options,
      profile_id: session.profile_id
    }
    create_session(attrs)
  end

  def change_session(%Session{} = session, attrs \\ %{}) do
    Session.changeset(session, attrs)
  end

  def stop_session_with_cleanup(%Session{} = session) do
    Logger.info("Scheduling cleanup for session #{session.id}")
    stop_session(session)
  end

  # ===== Private Functions =====

  defp create_session_record(attrs) do
    attrs
    |> Session.create_changeset()
    |> Repo.insert()
  end

  defp do_update(session, attrs) do
    session
    |> Session.changeset(attrs)
    |> Repo.update()
  end

  defp do_status_update(session, status) do
    session
    |> Session.status_changeset(status)
    |> Repo.update()
  end

  defp start_session_runtime(session) do
    with {:ok, session} <- update_status(session, :starting),
         {:ok, _pid} <- ensure_runtime_started(session),
         {:ok, session} <- update_status(session, :running) do
      {:ok, session}
    else
      {:error, reason} = error ->
        Logger.error("Failed to start runtime for session #{session.id}: #{inspect(reason)}")
        update_status(session, :error)
        error
    end
  end

  defp stop_session_runtime(session) do
    SessionRuntime.stop_session(session.id)
  end

  defp ensure_runtime_started(session) do
    opts = build_runtime_options(session)
    SessionRuntime.ensure_session_started(session.id, opts)
  end

  defp build_runtime_options(session) do
    options = session.options || %{}

    metadata = %{
      "options" => options,
      "profile_id" => session.profile_id,
      "cluster" => session.cluster,
      "browser_type" => session.browser_type
    }
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
    |> Map.new()

    [
      metadata: metadata,
      owner: nil,
      limits: Map.get(options, "limits", %{})
    ]
  end

  defp get_runtime_info(session_id) do
    case SessionRuntime.describe(session_id) do
      {:ok, details} ->
        {:ok, %{
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

  # ===== Broadcasting =====

  defp broadcast_created(session) do
    BrowsergridWeb.SessionChannel.broadcast_session_created(session)
  end

  defp broadcast_updated(session) do
    BrowsergridWeb.SessionChannel.broadcast_session_update(session)
  end

  defp broadcast_deleted(session_id) do
    BrowsergridWeb.SessionChannel.broadcast_session_deleted(session_id)
  end
end
