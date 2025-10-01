defmodule Browsergrid.Sessions do
  @moduledoc """
  The Sessions context - manages browser session lifecycle.
  """

  import Ecto.Query, warn: false

  alias Browsergrid.Repo
  alias Browsergrid.SessionRuntime
  alias Browsergrid.Sessions.Session

  require Logger

  @doc """
  Returns the list of sessions.
  """
  def list_sessions do
    Session
    |> order_by([s], desc: s.inserted_at)
    |> Repo.all()
  end

  @doc """
  Gets a single session.
  Returns {:ok, session} or {:error, :not_found}
  """
  def get_session(id) do
    # Validate UUID format
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

  @doc """
  Gets a single session.
  Raises if not found or invalid UUID.
  """
  def get_session!(id) do
    Repo.get!(Session, id)
  end

  @doc """
  Creates a session.
  """
  def create_session(attrs \\ %{}) do
    with {:ok, session} <- attrs |> Session.create_changeset() |> Repo.insert(),
         {:ok, session} <- update_session(session, %{}) do
      broadcast_session_created(session)

      case ensure_actor_started(session) do
        {:ok, running_session} ->
          {:ok, running_session}

        {:error, reason} = error ->
          Logger.error("failed to start session actor #{session.id}: #{inspect(reason)}")
          error
      end
    end
  end

  @doc """
  Updates a session.
  """
  def update_session(%Session{} = session, attrs) do
    with {:ok, updated_session} <- session |> Session.changeset(attrs) |> Repo.update() do
      # Broadcast the session update
      broadcast_session_updated(updated_session)
      {:ok, updated_session}
    end
  end

  @doc """
  Deletes a session.
  """
  def delete_session(%Session{} = session) do
    with {:ok, deleted_session} <- Repo.delete(session) do
      # Broadcast the session deletion
      broadcast_session_deleted(session.id)
      {:ok, deleted_session}
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking session changes.
  """
  def change_session(%Session{} = session, attrs \\ %{}) do
    Session.changeset(session, attrs)
  end

  @doc """
  Gets statistics about sessions.
  """
  def get_statistics do
    sessions = list_sessions()

    by_status =
      sessions
      |> Enum.group_by(& &1.status)
      |> Map.new(fn {status, sessions} -> {status, length(sessions)} end)

    %{
      total: length(sessions),
      by_status: by_status,
      total_sessions: length(sessions),
      active_sessions: Enum.count(sessions, &(&1.status in [:running, :pending])),
      available_sessions: Enum.count(sessions, &(&1.status == :pending)),
      failed_sessions: Enum.count(sessions, &(&1.status in [:error, :stopped]))
    }
  end

  @doc """
  Starts a session using the distributed supervisor
  """
  def start_session(%Session{} = session) do
    Logger.info("Starting session #{session.id}")
    ensure_actor_started(session)
  end

  @doc """
  Stops a session across the cluster
  """
  def stop_session(%Session{} = session) do
    Logger.info("Stopping session #{session.id}")

    with {:ok, session} <- update_status(session, :stopping) do
      :ok = SessionRuntime.stop_session(session.id)
      update_status(session, :stopped)
    end
  end

  @doc """
  Get session info including which node it's running on
  """
  def get_session_info(session_id) do
    with {:ok, session} <- get_session(session_id) do
      runtime =
        case SessionRuntime.describe(session_id) do
          {:ok, details} ->
            %{
              endpoint: details.endpoint,
              node: details.node,
              metadata: details.metadata
            }

          {:error, _} ->
            nil
        end

      {:ok, %{session: session, runtime: runtime}}
    end
  end

  @doc """
  Updates session status with detailed logging.
  """
  def update_status(%Session{} = session, status) when is_atom(status) do
    Logger.info("Updating session #{session.id} status from #{session.status} to #{status}")
    Logger.debug("Session before update: #{inspect(session, pretty: true)}")

    result =
      session
      |> Session.status_changeset(status)
      |> Repo.update()

    Logger.debug("Repo.update result: #{inspect(result)}")

    case result do
      {:ok, updated_session} ->
        Logger.info("Successfully updated session #{session.id} to status #{updated_session.status}")
        Logger.debug("Session after update: #{inspect(updated_session, pretty: true)}")

        # Broadcast the status update
        broadcast_session_updated(updated_session)

        {:ok, updated_session}

      {:error, changeset} = error ->
        Logger.error("Failed to update session #{session.id} status: #{inspect(changeset.errors)}")
        Logger.error("Changeset details: #{inspect(changeset)}")
        Logger.error("Session that failed to update: #{inspect(session, pretty: true)}")
        error
    end
  end

  @doc """
  Returns the connection info for a session (edge URL only).
  """
  def get_connection_info(session_id) do
    with {:ok, %Session{id: id}} <- get_session(session_id),
         {:ok, _endpoint} <- SessionRuntime.upstream_endpoint(id) do
      edge_cfg = Application.get_env(:browsergrid, :edge, [])
      host = Keyword.get(edge_cfg, :host, "edge.local")
      scheme = Keyword.get(edge_cfg, :scheme, "https")
      ws_scheme = websocket_scheme(scheme)

      {:ok,
       %{
         http_proxy: "#{scheme}://#{host}/sessions/#{id}/http",
         ws_proxy: "#{ws_scheme}://#{host}/sessions/#{id}/ws",
         session: id
       }}
    else
      {:error, :not_found} -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Creates a session with a profile.
  """
  def create_session_with_profile(attrs, profile_id) do
    attrs = Map.put(attrs, :profile_id, profile_id)

    # Validate profile exists and matches browser type
    with {:ok, profile} <- validate_profile_for_session(attrs, profile_id),
         {:ok, session} <- create_session(attrs) do
      # Update profile last used timestamp
      Browsergrid.Profiles.update_profile(profile, %{last_used_at: DateTime.utc_now()})
      {:ok, session}
    end
  end

  @doc """
  Stops a session and triggers profile extraction if needed.
  """
  def stop_session_with_cleanup(%Session{} = session) do
    Logger.info("Scheduling cleanup for session #{session.id}")
    stop_session(session)
  end

  @doc """
  Gets all sessions using a specific profile.
  """
  def get_sessions_by_profile(profile_id) do
    Session
    |> where([s], s.profile_id == ^profile_id)
    |> order_by([s], desc: s.inserted_at)
    |> Repo.all()
  end

  @doc """
  Gets active sessions using a specific profile.
  """
  def get_active_sessions_by_profile(profile_id) do
    Session
    |> where([s], s.profile_id == ^profile_id)
    |> where([s], s.status in [:pending, :running, :starting])
    |> Repo.all()
  end

  @doc """
  Checks if a profile is currently in use by any active session.
  """
  def profile_in_use?(profile_id) do
    Session
    |> where([s], s.profile_id == ^profile_id)
    |> where([s], s.status in [:pending, :running, :starting])
    |> Repo.exists?()
  end

  @doc """
  Clones a session with its profile settings.
  """
  def clone_session(%Session{} = session) do
    attrs = %{
      name: "#{session.name} (Clone)",
      browser_type: session.browser_type,
      options: session.options,
      profile_id: session.profile_id
    }

    create_session(attrs)
  end

  @doc """
  Gets session with profile preloaded.
  """
  def get_session_with_profile!(id) do
    Session
    |> preload(:profile)
    |> Repo.get!(id)
  end

  @doc """
  Updates session to mark profile snapshot as created.
  """
  def mark_profile_snapshot_created(%Session{} = session) do
    update_session(session, %{profile_snapshot_created: true})
  end

  @doc """
  Updates session status by ID (for watcher)
  """
  def update_status_by_id(session_id, status) when is_binary(session_id) and is_atom(status) do
    case get_session(session_id) do
      {:ok, session} -> update_status(session, status)
      error -> error
    end
  end

  # Private helper functions

  defp validate_profile_for_session(attrs, profile_id) do
    browser_type = Map.get(attrs, :browser_type, :chrome)

    case Browsergrid.Profiles.get_profile(profile_id) do
      nil ->
        {:error, :profile_not_found}

      profile ->
        if profile.browser_type == browser_type do
          {:ok, profile}
        else
          {:error, :browser_type_mismatch}
        end
    end
  end

  defp ensure_actor_started(%Session{} = session) do
    with {:ok, session_starting} <- update_status(session, :starting),
         {:ok, _pid} <-
           SessionRuntime.ensure_session_started(session_starting.id, runtime_init_options(session_starting)),
         {:ok, running_session} <- update_status(session_starting, :running) do
      {:ok, running_session}
    else
      {:error, _reason} = error ->
        _ = update_status(session, :error)
        error
    end
  end

  defp runtime_init_options(%Session{} = session) do
    options =
      session.options
      |> Kernel.||(%{})
      |> Map.put("browser_type", session.browser_type)

    metadata =
      %{
        "options" => options,
        "profile_id" => session.profile_id,
        "cluster" => session.cluster
      }
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Map.new()
      |> Map.put("browser_type", session.browser_type)

    limits = Map.get(options, "limits", %{})

    init_opts = [metadata: metadata, owner: nil, limits: limits]

    init_opts =
      case build_cdp_opts(options) do
        [] -> init_opts
        cdp_opts -> Keyword.put(init_opts, :cdp, cdp_opts)
      end

    init_opts =
      case build_browser_opts(options) do
        [] -> init_opts
        browser_opts -> Keyword.put(init_opts, :browser, browser_opts)
      end

    Keyword.put(init_opts, :browser_type, session.browser_type)
  end

  defp build_cdp_opts(options) when is_map(options) do
    options
    |> Map.get("browser_mux", %{})
    |> Enum.reduce([], fn
      {"browser_url", value}, acc -> [{:browser_url, value} | acc]
      {"frontend_url", value}, acc -> [{:frontend_url, value} | acc]
      {"max_message_size", value}, acc -> [{:max_message_size, value} | acc]
      {"connection_timeout_seconds", value}, acc -> [{:connection_timeout_seconds, value} | acc]
      {"env", value}, acc -> [{:env, value} | acc]
      {"args", value}, acc -> [{:args, value} | acc]
      {"cd", value}, acc -> [{:cd, value} | acc]
      {_other, _value}, acc -> acc
    end)
    |> Enum.reverse()
  end

  defp build_cdp_opts(_options), do: []

  defp build_browser_opts(options) when is_map(options) do
    options
    |> Map.get("browser", %{})
    |> Enum.reduce([], fn
      {"command", value}, acc -> [{:command, value} | acc]
      {"args", value}, acc -> [{:args, value} | acc]
      {"env", value}, acc -> [{:env, value} | acc]
      {"cd", value}, acc -> [{:cd, value} | acc]
      {"type", value}, acc -> [{:type, value} | acc]
      {"command_candidates", value}, acc -> [{:command_candidates, value} | acc]
      {"mode", value}, acc -> [{:mode, value} | acc]
      {"ready_timeout_ms", value}, acc -> [{:ready_timeout_ms, value} | acc]
      {"ready_poll_interval_ms", value}, acc -> [{:ready_poll_interval_ms, value} | acc]
      {"ready_path", value}, acc -> [{:ready_path, value} | acc]
      {_other, _value}, acc -> acc
    end)
    |> Enum.reverse()
  end

  defp build_browser_opts(_options), do: []

  defp websocket_scheme("https"), do: "wss"
  defp websocket_scheme("http"), do: "ws"
  defp websocket_scheme("wss"), do: "wss"
  defp websocket_scheme("ws"), do: "ws"
  defp websocket_scheme(other) when is_binary(other), do: other

  defp broadcast_session_created(session) do
    BrowsergridWeb.SessionChannel.broadcast_session_created(session)
  end

  defp broadcast_session_updated(session) do
    BrowsergridWeb.SessionChannel.broadcast_session_update(session)
  end

  defp broadcast_session_deleted(session_id) do
    BrowsergridWeb.SessionChannel.broadcast_session_deleted(session_id)
  end
end
