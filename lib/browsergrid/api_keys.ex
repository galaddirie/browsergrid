defmodule Browsergrid.ApiKeys do
  @moduledoc """
  Context for managing API keys and token verification.
  """

  import Ecto.Query, warn: false

  alias Browsergrid.ApiKeys.APIKey
  alias Browsergrid.ApiKeys.RateLimiter
  alias Browsergrid.ApiKeys.Token
  alias Browsergrid.Repo

  @max_generation_attempts 5


  def list_api_keys(opts \\ []) do
    APIKey
    |> maybe_filter_by_user(opts)
    |> maybe_filter_revoked(opts)
    |> order_by([k], desc: k.inserted_at)
    |> Repo.all()
  end

  def get_api_key!(id), do: Repo.get!(APIKey, id)
  def get_api_key(id), do: Repo.get(APIKey, id)

  def create_api_key(attrs \\ %{}) do
    fn ->
      case do_insert_api_key(attrs) do
        {:ok, api_key, token} -> {api_key, token}
        {:error, reason} -> Repo.rollback(reason)
      end
    end
    |> Repo.transaction()
    |> case do
      {:ok, {api_key, token}} -> {:ok, %{api_key: api_key, token: token}}
      {:error, reason} -> {:error, reason}
    end
  end

  def revoke_api_key(%APIKey{} = api_key, opts \\ []) do
    revoked_at = Keyword.get(opts, :revoked_at, DateTime.utc_now())

    api_key
    |> APIKey.update_changeset(%{revoked_at: revoked_at})
    |> Repo.update()
  end

  def regenerate_api_key(%APIKey{} = api_key, attrs \\ %{}) do
    fn ->
      case revoke_api_key(api_key) do
        {:ok, revoked} ->
          attrs
          |> merge_defaults_from(api_key)
          |> do_insert_api_key()
          |> case do
            {:ok, new_key, token} -> {revoked, new_key, token}
            {:error, reason} -> Repo.rollback(reason)
          end

        {:error, reason} ->
          Repo.rollback(reason)
      end
    end
    |> Repo.transaction()
    |> case do
      {:ok, {revoked, new_key, token}} ->
        {:ok, %{revoked_key: revoked, api_key: new_key, token: token}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def verify_token(token) when is_binary(token) do
    with {:ok, parsed} <- Token.parse(token),
         {:ok, api_key} <- fetch_by_prefix(parsed.prefix),
         true <- Argon2.verify_pass(token, api_key.key_hash) do
      case ensure_active(api_key) do
        :ok -> {:ok, api_key}
        {:error, reason} -> {:error, reason}
      end
    else
      {:error, :invalid_format} ->
        {:error, :invalid_token}

      {:error, :not_found} ->
        Argon2.no_user_verify()
        {:error, :invalid_token}

      {:error, reason} ->
        {:error, reason}

      false ->
        {:error, :invalid_token}
    end
  end

  def verify_token(_), do: {:error, :invalid_token}

  def register_usage(%APIKey{} = api_key) do
    now = DateTime.utc_now()

    case from(k in APIKey, where: k.id == ^api_key.id)
         |> Repo.update_all([set: [last_used_at: now, updated_at: now], inc: [usage_count: 1]]) do
      {1, _} -> {:ok, Repo.get!(APIKey, api_key.id)}
      _ -> {:error, :not_found}
    end
  end

  def check_rate_limit(%APIKey{} = api_key, opts \\ []) do
    RateLimiter.check(api_key.id, opts)
  end


  defp do_insert_api_key(attrs) do
    with {:ok, token_data} <- generate_unique_token(),
         params = prepare_params(attrs, token_data),
         changeset = APIKey.create_changeset(%APIKey{}, params),
         {:ok, api_key} <- Repo.insert(changeset) do
      {:ok, api_key, token_data.token}
    else
      {:error, _} = error -> error
    end
  end

  defp prepare_params(attrs, token_data) do
    attrs = sanitize_attrs(attrs)

    attrs
    |> Map.put(:key_hash, Argon2.hash_pwd_salt(token_data.token))
    |> Map.put(:prefix, token_data.prefix)
    |> Map.put(:last_four, token_data.last_four)
    |> Map.put_new(:metadata, %{})
  end

  defp sanitize_attrs(attrs) do
    %{}
    |> maybe_put(attrs, :name)
    |> maybe_put(attrs, :created_by)
    |> maybe_put(attrs, :metadata)
    |> maybe_put(attrs, :expires_at)
  end

  defp maybe_put(acc, attrs, key) do
    case fetch_attr(attrs, key) do
      nil -> acc
      value -> Map.put(acc, key, value)
    end
  end

  defp fetch_attr(attrs, key) do
    Map.get(attrs, key) || Map.get(attrs, Atom.to_string(key))
  end

  defp merge_defaults_from(attrs, %APIKey{} = api_key) do
    attrs
    |> sanitize_attrs()
    |> Map.put_new(:name, api_key.name)
    |> Map.put_new(:created_by, api_key.created_by)
    |> Map.put_new(:metadata, api_key.metadata)
    |> Map.put_new(:expires_at, api_key.expires_at)
  end

  defp fetch_by_prefix(prefix) do
    case Repo.get_by(APIKey, prefix: prefix) do
      nil -> {:error, :not_found}
      api_key -> {:ok, api_key}
    end
  end

  defp ensure_active(%APIKey{revoked_at: revoked_at}) when not is_nil(revoked_at), do: {:error, :revoked}

  defp ensure_active(%APIKey{expires_at: nil}), do: :ok

  defp ensure_active(%APIKey{expires_at: expires_at}) do
    case DateTime.compare(expires_at, DateTime.utc_now()) do
      :lt -> {:error, :expired}
      _ -> :ok
    end
  end

  defp generate_unique_token do
    Enum.reduce_while(1..@max_generation_attempts, nil, fn attempt, _acc ->
      candidate = Token.generate()

      case Repo.get_by(APIKey, prefix: candidate.prefix) do
        nil -> {:halt, {:ok, candidate}}
        _ when attempt == @max_generation_attempts -> {:halt, {:error, :prefix_collision}}
        _ -> {:cont, nil}
      end
    end)
  end

  defp maybe_filter_revoked(query, opts) do
    if Keyword.get(opts, :include_revoked, true) do
      query
    else
      where(query, [k], is_nil(k.revoked_at))
    end
  end

  defp maybe_filter_by_user(query, opts) do
    case Keyword.get(opts, :user_id) do
      nil -> query
      user_id -> where(query, [k], k.user_id == ^user_id)
    end
  end
end
