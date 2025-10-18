defmodule Browsergrid.Connect do
  @moduledoc """
  Public API surface for the Connect subsystem. Coordinates token validation
  and delegates to the idle pool for session provisioning and lifecycle
  management.
  """

  alias Browsergrid.Connect.Config
  alias Browsergrid.Connect.IdlePool
  alias Browsergrid.Connect.SessionInfo

  @typedoc "Opaque identifier supplied by callers to reserve a session."
  @type token :: String.t()

  @doc """
  Claims an idle session for the provided `token`.

  Returns `{:ok, %SessionInfo{}}` on success or `{:error, reason}` on failure.
  """
  @spec claim_session(token()) :: {:ok, SessionInfo.t()} | {:error, term()}
  def claim_session(token) do
    with :ok <- authorize_token(token) do
      IdlePool.claim(token)
    end
  end

  @doc """
  Fetches the session currently bound to `token`, if any.
  """
  @spec fetch_claim(token()) :: {:ok, SessionInfo.t()} | {:error, term()}
  def fetch_claim(token) do
    with :ok <- authorize_token(token) do
      IdlePool.get_claim(token)
    end
  end

  @doc """
  Marks the WebSocket process as attached for the supplied `token`.

  Returns the updated session information, or an error if the token does not
  have an active claim.
  """
  @spec attach_websocket(token(), pid()) :: {:ok, SessionInfo.t()} | {:error, term()}
  def attach_websocket(token, ws_pid) do
    with :ok <- authorize_token(token) do
      IdlePool.attach_websocket(token, ws_pid)
    end
  end

  @doc """
  Releases the claim associated with `token`, if present.
  """
  @spec release(token(), term()) :: :ok
  def release(token, reason) do
    case authorize_token(token) do
      :ok -> IdlePool.release(token, reason)
      {:error, _} -> :ok
    end
  end

  @doc """
  Returns `true` if the token is authorised to access the Connect surface.
  """
  @spec token_authorised?(token()) :: boolean()
  def token_authorised?(token) do
    authorize_token(token) == :ok
  end

  @doc """
  Returns the configured claim timeout (milliseconds).
  """
  @spec claim_timeout_ms() :: non_neg_integer()
  def claim_timeout_ms do
    Config.claim_timeout_ms()
  end

  @doc """
  Returns the configured routing mode.
  """
  @spec routing_mode() :: :path | :subdomain | :both
  def routing_mode do
    Config.routing_mode()
  end

  @doc """
  Returns the configured Connect host, when subdomain routing is enabled.
  """
  @spec host() :: String.t() | nil
  def host do
    Config.host()
  end

  @doc """
  Returns the configured Connect path prefix for path-based routing.
  """
  @spec path_prefix() :: String.t()
  def path_prefix do
    Config.path_prefix()
  end

  @doc """
  Returns a snapshot of the current pool state designed for diagnostics.
  """
  @spec snapshot() :: map()
  def snapshot do
    base = %{
      enabled: Config.enabled?(),
      pool_size: Config.pool_size(),
      claim_timeout_ms: Config.claim_timeout_ms(),
      session_prefix: Config.session_prefix(),
      browser_type: maybe_atom_to_string(Config.browser_type())
    }

    if base.enabled do
      case IdlePool.snapshot() do
        {:ok, snapshot} ->
          Map.merge(base, snapshot)

        {:error, :not_running} ->
          Map.merge(base, offline_snapshot(base))
      end
    else
      Map.merge(base, offline_snapshot(base))
    end
  end

  defp authorize_token(token) when not is_binary(token) or token == "" do
    {:error, :missing_token}
  end

  defp authorize_token(token) do
    case Config.token() do
      nil ->
        :ok

      expected when is_binary(expected) ->
        if secure_compare(token, expected) do
          :ok
        else
          {:error, :unauthorized}
        end
    end
  end

  defp secure_compare(provided, expected)
       when is_binary(provided) and is_binary(expected) and byte_size(provided) == byte_size(expected) do
    Plug.Crypto.secure_compare(provided, expected)
  rescue
    ArgumentError -> false
  end

  defp secure_compare(_provided, _expected), do: false

  defp offline_snapshot(_base) do
    %{
      online: false,
      sessions: [],
      counts: %{},
      idle_queue: [],
      claims: [],
      fetched_at: DateTime.to_iso8601(DateTime.utc_now())
    }
  end

  defp maybe_atom_to_string(nil), do: nil
  defp maybe_atom_to_string(value) when is_atom(value), do: Atom.to_string(value)
  defp maybe_atom_to_string(value), do: value
end
