defmodule Browsergrid.Kubernetes do
  @moduledoc """
  Thin wrapper around the `k8s` client that centralises connection handling for
  Browsergrid. The runtime primarily uses service account credentials when
  running inside the cluster but gracefully falls back to a local kubeconfig
  when developing outside Kubernetes.
  """

  alias Browsergrid.SessionRuntime

  require Logger

  @spec client() :: {:ok, K8s.Conn.t()} | {:error, term()}
  def client do
    config = SessionRuntime.kubernetes_config()

    case build_conn(config) do
      {:ok, conn} -> {:ok, conn}
      {:error, reason} ->
        Logger.error("failed to establish kubernetes connection: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @spec build_conn(keyword()) :: {:ok, K8s.Conn.t()} | {:error, term()}
  def build_conn(config) do
    case Keyword.get(config, :conn, :auto) do
      {:kubeconfig, path} when is_binary(path) ->
        path
        |> Path.expand()
        |> K8s.Conn.from_file()

      {:service_account, opts} when is_list(opts) ->
        K8s.Conn.from_service_account(opts)

      {:service_account, _} ->
        {:error, :invalid_service_account_options}

      :service_account ->
        K8s.Conn.from_service_account()

      :auto ->
        auto_conn()

      other ->
        Logger.error("invalid kubernetes connection configuration: #{inspect(other)}")
        {:error, :invalid_kubernetes_conn_config}
    end
  end

  defp auto_conn do
    case System.get_env("KUBECONFIG") do
      nil ->
        if File.exists?("/var/run/secrets/kubernetes.io/serviceaccount/token") do
          K8s.Conn.from_service_account()
        else
          {:error, :no_kubernetes_credentials_found}
        end

      path when is_binary(path) ->
        expanded = Path.expand(path)

        if File.exists?(expanded) do
          K8s.Conn.from_file(expanded)
        else
          Logger.error("KUBECONFIG points to missing file: #{expanded}")
          {:error, :kubeconfig_not_found}
        end
    end
  end

  @spec run(K8s.Conn.t(), K8s.Operation.t()) :: {:ok, map()} | {:error, term()}
  def run(conn, %K8s.Operation{} = operation) do
    case K8s.Client.run(conn, operation) do
      {:ok, _} = ok -> ok
      {:error, %K8s.Client.APIError{} = error} -> {:error, error}
      {:error, reason} -> {:error, reason}
    end
  end
end
