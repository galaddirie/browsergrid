defmodule Browsergrid.SessionRuntime.Browser do
  @moduledoc """
  Launches and monitors browser sessions. In the Kubernetes-native architecture
  each session runs inside its own pod. For test environments the module still
  supports a lightweight stub mode that mimics the previous per-process
  behaviour without contacting Kubernetes.
  """

  alias Browsergrid.Kubernetes
  alias Browsergrid.SessionRuntime
  alias K8s.Client.APIError

  require Logger

  @type mode :: :stub | :kubernetes

  @type t :: %{
          mode: mode(),
          session_id: String.t(),
          profile_dir: String.t(),
          browser_type: atom(),
          pod_name: String.t() | nil,
          namespace: String.t() | nil,
          pod_ip: String.t() | nil,
          http_port: non_neg_integer(),
          profile_mount_path: String.t() | nil,
          stub: map() | nil
        }

  @supported_browser_types [:chrome, :chromium, :firefox]

  @spec start(String.t(), term(), String.t(), keyword(), map(), atom()) ::
          {:ok, t()} | {:error, term()}
  def start(session_id, _unused_port, profile_dir, opts, context, browser_type \\ :chrome) do
    config = Keyword.merge(SessionRuntime.browser_config(), opts)
    mode = Keyword.get(config, :mode, :kubernetes)
    browser_type = normalize_browser_type(browser_type || Map.get(context, :browser_type))

    case mode do
      :stub ->
        start_stub(session_id, profile_dir, browser_type)

      :kubernetes ->
        start_kubernetes(session_id, profile_dir, config, context, browser_type)

      other ->
        {:error, {:unsupported_browser_mode, other}}
    end
  end

  @spec wait_until_ready(t(), keyword()) :: {:ok, t()} | {:error, term()}
  def wait_until_ready(%{mode: :stub} = state, _config), do: {:ok, state}

  def wait_until_ready(%{mode: :kubernetes} = state, config) do
    poll_ms = Keyword.get(config, :ready_poll_interval_ms, 1_000)
    timeout_ms = Keyword.get(config, :ready_timeout_ms, 120_000)
    ready_path = Keyword.get(config, :ready_path, "/health")
    started_at = System.monotonic_time(:millisecond)

    with {:ok, conn} <- Kubernetes.client(),
         {:ok, pod} <- wait_for_pod_ready(conn, state, poll_ms, timeout_ms, started_at),
         {:ok, pod_ip} <- extract_pod_ip(pod),
         :ok <- wait_for_http_ready(pod_ip, state.http_port, ready_path, poll_ms, timeout_ms, started_at) do
      {:ok, %{state | pod_ip: pod_ip}}
    end
  end

  @spec stop(t()) :: :ok | {:error, term()}
  def stop(%{mode: :stub, stub: %{pid: pid, ref: ref}}) do
    if Process.alive?(pid), do: Process.exit(pid, :normal)
    if ref, do: Process.demonitor(ref, [:flush])
    :ok
  end

  def stop(%{mode: :kubernetes, pod_name: pod_name, namespace: namespace}) do
    case Kubernetes.client() do
      {:ok, conn} ->
        op =
          "v1"
          |> K8s.Client.delete(:pod, namespace: namespace, name: pod_name)
          |> K8s.Operation.put_query_param(:gracePeriodSeconds, 0)

        case Kubernetes.run(conn, op) do
          {:ok, _} ->
            :ok

          {:error, %APIError{reason: reason}} when reason in [:not_found, "NotFound"] ->
            :ok

          {:error, reason} ->
            Logger.error("failed to delete pod #{pod_name} in namespace #{namespace}: #{inspect(reason)}")
            {:error, reason}
        end

      {:error, reason} ->
        Logger.error("unable to obtain kubernetes client for pod deletion: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp start_stub(session_id, profile_dir, browser_type) do
    pid = spawn_link(fn -> stub_loop() end)
    ref = Process.monitor(pid)

    {:ok,
     %{
       mode: :stub,
       session_id: session_id,
       profile_dir: profile_dir,
       browser_type: browser_type,
       pod_name: nil,
       namespace: nil,
       pod_ip: "127.0.0.1",
       http_port: 0,
       profile_mount_path: profile_dir,
       stub: %{pid: pid, ref: ref}
     }}
  end

  defp start_kubernetes(session_id, profile_dir, config, context, browser_type) do
    kube_config = SessionRuntime.kubernetes_config()

    if Keyword.get(kube_config, :enabled, true) do
      http_port = Keyword.get(config, :http_port)

      if is_nil(http_port) do
        {:error, :missing_http_port_configuration}
      else
        with {:ok, conn} <- Kubernetes.client(),
             namespace = Keyword.get(kube_config, :namespace, "browsergrid"),
             pod_name = pod_name(session_id),
             spec =
               build_pod_spec(
                 session_id,
                 profile_dir,
                 context,
                 browser_type,
                 config,
                 kube_config,
                 pod_name
               ),
             :ok <- ensure_pod_absent(conn, namespace, pod_name),
             {:ok, _pod} <- create_pod(conn, namespace, spec) do
          {:ok,
           %{
             mode: :kubernetes,
             session_id: session_id,
             profile_dir: profile_dir,
             browser_type: browser_type,
             pod_name: pod_name,
             namespace: namespace,
             pod_ip: nil,
             http_port: http_port,
             profile_mount_path: Keyword.get(kube_config, :profile_volume_mount_path),
             stub: nil
           }}
        end
      end
    else
      Logger.error("kubernetes runtime disabled via configuration")
      {:error, :kubernetes_disabled}
    end
  end

  defp create_pod(conn, namespace, spec) do
    op = K8s.Client.create("v1", :pod, [namespace: namespace], spec)

    case Kubernetes.run(conn, op) do
      {:ok, pod} ->
        {:ok, pod}

      {:error, %APIError{reason: :already_exists}} ->
        {:error, :pod_already_exists}

      {:error, reason} ->
        Logger.error("failed to create pod #{spec["metadata"]["name"]}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp ensure_pod_absent(conn, namespace, pod_name) do
    op =
      "v1"
      |> K8s.Client.delete(:pod, namespace: namespace, name: pod_name)
      |> K8s.Operation.put_query_param(:gracePeriodSeconds, 0)

    case Kubernetes.run(conn, op) do
      {:ok, _} ->
        wait_for_deletion(conn, namespace, pod_name, 30, 500)

      {:error, %APIError{reason: reason}} when reason in [:not_found, "NotFound"] ->
        :ok

      {:error, reason} ->
        Logger.warning("unable to pre-delete existing pod #{pod_name}: #{inspect(reason)}")
        :ok
    end
  end

  defp wait_for_deletion(_client, _namespace, _pod_name, 0, _poll), do: :ok

  defp wait_for_deletion(conn, namespace, pod_name, attempts, poll) do
    op = K8s.Client.get("v1", :pod, namespace: namespace, name: pod_name)

    case Kubernetes.run(conn, op) do
      {:ok, _pod} ->
        Process.sleep(poll)
        wait_for_deletion(conn, namespace, pod_name, attempts - 1, poll)

      {:error, %APIError{reason: reason}} when reason in [:not_found, "NotFound"] ->
        :ok

      {:error, _} ->
        :ok
    end
  end

  defp wait_for_pod_ready(conn, state, poll_ms, timeout_ms, started_at) do
    now = System.monotonic_time(:millisecond)

    if now - started_at > timeout_ms do
      {:error, :timeout}
    else
      case fetch_pod(conn, state) do
        {:ok, pod} ->
          case {pod_phase(pod), containers_ready?(pod)} do
            {"Running", true} ->
              {:ok, pod}

            {phase, _} when phase in ["Failed", "Unknown"] ->
              {:error, {:pod_failed, phase, pod}}

            _ ->
              Process.sleep(poll_ms)
              wait_for_pod_ready(conn, state, poll_ms, timeout_ms, started_at)
          end

        {:error, %APIError{reason: reason}} when reason in [:not_found, "NotFound"] ->
          Process.sleep(poll_ms)
          wait_for_pod_ready(conn, state, poll_ms, timeout_ms, started_at)

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp wait_for_http_ready(_host, _port, _path, _poll_ms, timeout_ms, _started_at) when timeout_ms <= 0 do
    {:error, :timeout}
  end

  defp wait_for_http_ready(host, port, path, poll_ms, timeout_ms, started_at) do
    now = System.monotonic_time(:millisecond)

    if now - started_at > timeout_ms do
      {:error, :timeout}
    else
      if http_ready?(host, port, path) do
        :ok
      else
        Process.sleep(poll_ms)
        wait_for_http_ready(host, port, path, poll_ms, timeout_ms, started_at)
      end
    end
  end

  defp http_ready?(host, port, path) do
    url = "http://#{host}:#{port}#{path}"
    request = Finch.build(:get, url)

    case Finch.request(request, Browsergrid.Finch, receive_timeout: 1_000) do
      {:ok, %Finch.Response{status: status}} when status in 200..299 -> true
      {:ok, %Finch.Response{status: status}} when status in 300..399 -> true
      {:ok, _} -> false
      {:error, _reason} -> false
    end
  end

  defp fetch_pod(conn, %{pod_name: pod_name, namespace: namespace}) do
    op = K8s.Client.get("v1", :pod, namespace: namespace, name: pod_name)
    Kubernetes.run(conn, op)
  end

  defp pod_phase(pod) do
    get_in(pod, ["status", "phase"]) || "Unknown"
  end

  defp containers_ready?(pod) do
    statuses = get_in(pod, ["status", "containerStatuses"]) || []

    Enum.all?(statuses, fn
      %{"ready" => ready} -> ready
      _ -> false
    end)
  end

  defp extract_pod_ip(pod) do
    case get_in(pod, ["status", "podIP"]) do
      ip when is_binary(ip) and ip != "" -> {:ok, ip}
      _ -> {:error, :pod_ip_unavailable}
    end
  end

  defp build_pod_spec(session_id, profile_dir, context, browser_type, config, kube_config, pod_name) do
    image = image_for(kube_config, browser_type)
    http_port = Keyword.fetch!(config, :http_port)
    profile_mount_path = Keyword.get(kube_config, :profile_volume_mount_path, "/home/user/data-dir")

    {volumes, mounts} = volume_config(kube_config, session_id, profile_dir, profile_mount_path)

    env =
      session_id
      |> base_env(profile_mount_path, context)
      |> Enum.concat(extra_env(kube_config))
      |> Enum.reject(fn {_k, v} -> is_nil(v) or v == "" end)
      |> Enum.map(fn {k, v} -> %{"name" => k, "value" => to_string(v)} end)

    ports = [
      %{"containerPort" => http_port, "name" => "http"}
    ]

    resources = %{
      "requests" => %{
        "cpu" => Keyword.get(kube_config, :request_cpu, "200m"),
        "memory" => Keyword.get(kube_config, :request_memory, "512Mi")
      },
      "limits" => %{
        "cpu" => Keyword.get(kube_config, :limit_cpu, "1"),
        "memory" => Keyword.get(kube_config, :limit_memory, "2Gi")
      }
    }

    %{
      "apiVersion" => "v1",
      "kind" => "Pod",
      "metadata" => %{
        "name" => pod_name,
        "labels" => %{
          "app" => "browsergrid-session",
          "browsergrid/session-id" => session_id,
          "browsergrid/browser-type" => to_string(browser_type)
        },
        "annotations" => %{
          "browsergrid/profile-dir" => profile_dir
        }
      },
      "spec" => %{
        "restartPolicy" => "Never",
        "serviceAccountName" => Keyword.get(kube_config, :service_account),
        "terminationGracePeriodSeconds" => 15,
        "containers" => [
          %{
            "name" => "browser",
            "image" => image,
            "imagePullPolicy" => Keyword.get(kube_config, :image_pull_policy, "IfNotPresent"),
            "env" => env,
            "ports" => ports,
            "volumeMounts" => mounts,
            "resources" => resources
          }
        ],
        "volumes" => volumes
      }
    }
    |> maybe_put_node_selector(kube_config)
    |> maybe_put_tolerations(kube_config)
    |> maybe_put_affinity(kube_config)
  end

  defp volume_config(kube_config, session_id, _profile_dir, profile_mount_path) do
    claim = Keyword.get(kube_config, :profile_volume_claim)

    if is_binary(claim) and claim != "" do
      subprefix = Keyword.get(kube_config, :profile_volume_sub_path_prefix, "sessions")
      sub_path = Path.join(subprefix, session_id)

      volumes = [
        %{
          "name" => "profile-data",
          "persistentVolumeClaim" => %{"claimName" => claim}
        }
      ]

      mounts = [
        %{
          "name" => "profile-data",
          "mountPath" => profile_mount_path,
          "subPath" => sub_path
        }
      ]

      {volumes, mounts}
    else
      volumes = [
        %{
          "name" => "profile-data",
          "emptyDir" => %{}
        }
      ]

      mounts = [
        %{
          "name" => "profile-data",
          "mountPath" => profile_mount_path
        }
      ]

      {volumes, mounts}
    end
  end

  defp base_env(session_id, profile_mount_path, context) do
    screen_width = context[:screen_width]
    screen_height = context[:screen_height]
    scale = context[:device_scale_factor] || context[:scale]

    [
      {"SESSION_ID", session_id},
      {"BROWSERGRID_SESSION_ID", session_id},
      {"PROFILE_DIR", profile_mount_path},
      {"RESOLUTION_WIDTH", if(screen_width, do: to_string(screen_width))},
      {"RESOLUTION_HEIGHT", if(screen_height, do: to_string(screen_height))},
      {"DEVICE_SCALE_FACTOR", if(scale, do: to_string(scale))}
    ]
  end

  defp extra_env(kube_config) do
    kube_config
    |> Keyword.get(:extra_env, [])
    |> Enum.map(fn
      {key, value} ->
        {to_string(key), value}

      other when is_binary(other) ->
        case String.split(other, "=", parts: 2) do
          [k, v] -> {k, v}
          _ -> {other, nil}
        end
    end)
  end

  defp maybe_put_node_selector(spec, kube_config) do
    case Keyword.get(kube_config, :node_selector) do
      nil -> spec
      selector when is_map(selector) -> put_in(spec, ["spec", "nodeSelector"], selector)
      _ -> spec
    end
  end

  defp maybe_put_tolerations(spec, kube_config) do
    case Keyword.get(kube_config, :tolerations) do
      nil -> spec
      tolerations when is_list(tolerations) -> put_in(spec, ["spec", "tolerations"], tolerations)
      _ -> spec
    end
  end

  defp maybe_put_affinity(spec, kube_config) do
    case Keyword.get(kube_config, :affinity) do
      nil -> spec
      affinity when is_map(affinity) -> put_in(spec, ["spec", "affinity"], affinity)
      _ -> spec
    end
  end

  defp normalize_browser_type(type) when type in @supported_browser_types, do: type

  defp normalize_browser_type(type) when is_binary(type) do
    case String.downcase(type) do
      "chrome" -> :chrome
      "chromium" -> :chromium
      "firefox" -> :firefox
      _ -> :chrome
    end
  end

  defp normalize_browser_type(_), do: :chrome

  defp image_for(kube_config, browser_type) do
    overrides = Keyword.get(kube_config, :image_overrides, %{})

    case Map.get(overrides, browser_type) || Map.get(overrides, to_string(browser_type)) do
      nil ->
        repo = Keyword.get(kube_config, :image_repository, "browsergrid")
        tag = Keyword.get(kube_config, :image_tag, "latest")
        "#{repo}/#{browser_type}:#{tag}"

      image ->
        image
    end
  end

  defp pod_name(session_id) do
    slug =
      session_id
      |> String.downcase()
      |> String.replace(~r/[^a-z0-9-]/, "-")
      |> String.trim("-")

    hash =
      :sha256
      |> :crypto.hash(session_id)
      |> Base.encode16(case: :lower)
      |> binary_part(0, 6)

    base = "session-#{slug}"

    if byte_size(base) > 54 do
      trimmed = binary_part(base, 0, 54)
      String.trim_trailing(trimmed, "-") <> "-" <> hash
    else
      base <> "-" <> hash
    end
  end

  defp stub_loop do
    receive do
      :stop -> :ok
    after
      60_000 -> stub_loop()
    end
  end
end
