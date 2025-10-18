defmodule Browsergrid.Connect.Config do
  @moduledoc """
  Runtime configuration facade for the Connect idle session pool and routing.
  """

  @defaults [
    enabled: true,
    pool_size: 1,
    claim_timeout_ms: 10_000,
    token: nil,
    session_prefix: "connect",
    session_metadata: %{"source" => "connect_pool"},
    browser_type: :chrome,
    routing: [
      mode: :path,
      path_prefix: "/connect",
      host: nil
    ]
  ]

  @spec config() :: keyword()
  def config do
    env_config = Application.get_env(:browsergrid, Browsergrid.Connect, [])
    Keyword.merge(@defaults, env_config, &merge_deep/3)
  end

  @spec enabled?() :: boolean()
  def enabled? do
    Keyword.get(config(), :enabled, true)
  end

  @spec pool_size() :: non_neg_integer()
  def pool_size do
    Keyword.get(config(), :pool_size, 1)
  end

  @spec claim_timeout_ms() :: non_neg_integer()
  def claim_timeout_ms do
    Keyword.get(config(), :claim_timeout_ms, 10_000)
  end

  @spec token() :: String.t() | nil
  def token do
    Keyword.get(config(), :token)
  end

  @spec require_token?() :: boolean()
  def require_token? do
    not is_nil(token())
  end

  @spec session_prefix() :: String.t()
  def session_prefix do
    Keyword.get(config(), :session_prefix, "connect")
  end

  @spec session_metadata() :: map()
  def session_metadata do
    Keyword.get(config(), :session_metadata, %{})
  end

  @spec browser_type() :: atom()
  def browser_type do
    Keyword.get(config(), :browser_type, :chrome)
  end

  @spec routing() :: keyword()
  def routing do
    Keyword.get(config(), :routing, [])
  end

  @spec routing_mode() :: :path | :subdomain | :both
  def routing_mode do
    routing()
    |> Keyword.get(:mode, :path)
    |> normalize_mode()
  end

  @spec path_prefix() :: String.t()
  def path_prefix do
    Keyword.get(routing(), :path_prefix, "/connect")
  end

  @spec host() :: String.t() | nil
  def host do
    Keyword.get(routing(), :host)
  end

  defp normalize_mode(mode) when mode in [:path, :subdomain, :both], do: mode
  defp normalize_mode(_other), do: :path

  defp merge_deep(_key, default, nil), do: default

  defp merge_deep(_key, default, value) when is_list(default) and is_list(value) do
    Keyword.merge(default, value, &merge_deep/3)
  end

  defp merge_deep(_key, _default, value), do: value
end
