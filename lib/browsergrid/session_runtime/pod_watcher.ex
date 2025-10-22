defmodule Browsergrid.SessionRuntime.PodWatcher do
  @moduledoc """
  Watches Kubernetes pod events for browser sessions and coordinates failure
  handling when pods disappear or crash. Ensures session records, routing
  entries, and runtime processes stay in sync with the actual pod lifecycle.
  """
  use GenServer

  alias Browsergrid.Kubernetes
  alias Browsergrid.Routing
  alias Browsergrid.SessionRuntime
  alias Browsergrid.Sessions

  require Logger

  @label_selector "app=browsergrid-session"
  @max_restarts 5
  @base_backoff_ms 1_000

  @type state :: %{
          namespace: String.t(),
          label_selector: String.t(),
          restarts: non_neg_integer(),
          watch_pid: pid() | nil
        }

  @spec process_event(map()) :: :ok
  def process_event(event) when is_map(event) do
    handle_stream_event(event)
  end

  def process_event(_), do: :ok

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @impl true
  def init(opts) do
    Process.flag(:trap_exit, true)

    config = SessionRuntime.kubernetes_config()

    if Keyword.get(config, :enabled, true) do
      namespace = Keyword.get(config, :namespace, "browsergrid")
      label_selector = Keyword.get(opts, :label_selector, @label_selector)

      case start_watch(namespace, label_selector) do
        {:ok, watch_pid} ->
          state = %{
            namespace: namespace,
            label_selector: label_selector,
            restarts: 0,
            watch_pid: watch_pid
          }

          {:ok, state}

        {:error, reason} ->
          Logger.error("failed to start pod watcher: #{inspect(reason)}")
          {:stop, reason}
      end
    else
      Logger.debug("pod watcher disabled because kubernetes runtime is disabled")
      :ignore
    end
  end

  @impl true
  def handle_info({:EXIT, pid, reason}, %{watch_pid: pid} = state) do
    Logger.warning("pod watch stream exited: #{inspect(reason)}")

    if state.restarts < @max_restarts do
      delay = backoff_for(state.restarts)
      Process.send_after(self(), :restart_watch, delay)
      {:noreply, %{state | watch_pid: nil, restarts: state.restarts + 1}}
    else
      Logger.error("pod watcher exceeded restart limit")
      {:stop, {:too_many_restarts, reason}, state}
    end
  end

  def handle_info({:EXIT, _pid, reason}, state) do
    Logger.debug("ignoring exit from unrelated process: #{inspect(reason)}")
    {:noreply, state}
  end

  def handle_info(:restart_watch, state) do
    case start_watch(state.namespace, state.label_selector) do
      {:ok, watch_pid} ->
        {:noreply, %{state | watch_pid: watch_pid, restarts: 0}}

      {:error, reason} ->
        Logger.error("failed to restart pod watch stream: #{inspect(reason)}")
        {:stop, reason, state}
    end
  end

  defp start_watch(namespace, label_selector) do
    with {:ok, conn} <- Kubernetes.client() do
      Task.start_link(fn -> consume_watch_stream(conn, namespace, label_selector) end)
    end
  end

  defp consume_watch_stream(conn, namespace, label_selector) do
    operation =
      K8s.Client.watch("v1", :pod, namespace: namespace, labelSelector: label_selector)

    case K8s.Client.stream(conn, operation) do
      {:ok, stream} ->
        Enum.each(stream, &handle_stream_event/1)

      {:error, reason} ->
        Logger.error("pod watch stream failed: #{inspect(reason)}")
        exit({:watch_stream_error, reason})
    end
  catch
    kind, reason ->
      Logger.error("pod watch stream crashed: #{inspect({kind, reason})}")
      :erlang.raise(kind, reason, __STACKTRACE__)
  end

  defp handle_stream_event(%{"object" => pod} = event) do
    case extract_session_id(pod) do
      nil ->
        :ok

      session_id ->
        type = Map.get(event, "type")
        dispatch_event(type, session_id, pod)
    end
  end

  defp handle_stream_event(_event), do: :ok

  defp dispatch_event("DELETED", session_id, pod) do
    phase = get_in(pod, ["status", "phase"])

    Logger.warning("session pod deleted", session: session_id, phase: phase)

    mark_session_failed(session_id, :pod_deleted, pod)
  end

  defp dispatch_event("MODIFIED", session_id, pod) do
    phase = get_in(pod, ["status", "phase"])
    reason = get_in(pod, ["status", "reason"])
    container_statuses = get_in(pod, ["status", "containerStatuses"]) || []

    cond do
      phase == "Failed" ->
        Logger.error("session pod failed", session: session_id, reason: reason)
        mark_session_failed(session_id, normalize_reason(reason || phase), pod)

      eviction_reason?(reason) ->
        Logger.error("session pod evicted", session: session_id, reason: reason)
        mark_session_failed(session_id, normalize_reason(reason), pod)

      crashloop?(container_statuses) ->
        Logger.error("session pod in CrashLoopBackOff", session: session_id)
        mark_session_failed(session_id, :crash_loop_backoff, pod)

      terminated_with_error?(container_statuses) ->
        Logger.error("session pod container terminated with error", session: session_id)
        mark_session_failed(session_id, :container_terminated, pod)

      phase == "Unknown" ->
        Logger.warning("session pod reported unknown phase", session: session_id)
        :ok

      true ->
        :ok
    end
  end

  defp dispatch_event(_other, _session_id, _pod), do: :ok

  defp crashloop?(statuses) do
    Enum.any?(statuses, fn status ->
      waiting = get_in(status, ["state", "waiting"])
      waiting && waiting["reason"] == "CrashLoopBackOff"
    end)
  end

  defp terminated_with_error?(statuses) do
    Enum.any?(statuses, fn status ->
      terminated = get_in(status, ["state", "terminated"])
      terminated && terminated["exitCode"] not in [nil, 0]
    end)
  end

  defp eviction_reason?(reason) do
    reason in ["Evicted", "Preempted", "NodeShutdown", "Shutdown"]
  end

  defp mark_session_failed(session_id, reason, pod) do
    phase = get_in(pod, ["status", "phase"])

    case session_status(session_id) do
      {:ok, status} when status in [:stopping, :stopped] ->
        Logger.info(
          "session pod deleted during shutdown; keeping session status",
          session: session_id,
          reason: reason,
          phase: phase
        )

        stop_runtime_session(session_id)
        Routing.delete_route(session_id)
        :ok

      _ ->
        case Sessions.update_status_by_id(session_id, :error) do
          {:ok, _session} ->
            :ok

          {:error, :not_found} ->
            Logger.debug("session #{session_id} not found when marking failure")
            :ok

          {:error, other} ->
            Logger.error("unable to update session #{session_id} status: #{inspect(other)}")
            :ok
        end

        stop_runtime_session(session_id)
        Routing.delete_route(session_id)

        :telemetry.execute(
          [:browsergrid, :pod, :failure],
          %{count: 1},
          %{
            session_id: session_id,
            reason: telemetry_reason(reason),
            phase: phase,
            namespace: pod |> Map.get("metadata", %{}) |> Map.get("namespace")
          }
        )

        :ok
    end
  end

  defp extract_session_id(pod) do
    pod
    |> Map.get("metadata", %{})
    |> Map.get("labels", %{})
    |> Map.get("browsergrid/session-id")
  end

  defp normalize_reason(reason) when is_binary(reason) do
    reason
    |> String.downcase()
    |> String.replace("-", "_")
  end

  defp normalize_reason(reason) when is_atom(reason) do
    reason
    |> Atom.to_string()
    |> normalize_reason()
  end

  defp normalize_reason(_reason), do: "unknown"

  defp backoff_for(retries) do
    trunc(:math.pow(2, retries) * @base_backoff_ms)
  end

  defp stop_runtime_session(session_id) do
    if Process.whereis(Browsergrid.SessionRuntime.SessionRegistry) do
      SessionRuntime.stop_session(session_id)
    else
      :ok
    end
  end

  defp telemetry_reason(reason) when is_atom(reason), do: Atom.to_string(reason)
  defp telemetry_reason(reason) when is_binary(reason), do: reason
  defp telemetry_reason(_reason), do: "unknown"

  defp session_status(session_id) do
    case Sessions.get_session(session_id) do
      {:ok, session} -> {:ok, session.status}
      other -> other
    end
  end
end
