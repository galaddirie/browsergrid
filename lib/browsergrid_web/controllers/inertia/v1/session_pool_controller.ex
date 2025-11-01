defmodule BrowsergridWeb.Inertia.V1.SessionPoolController do
  use BrowsergridWeb, :controller

  alias Browsergrid.Profiles
  alias Browsergrid.Repo
  alias Browsergrid.SessionPools
  alias Browsergrid.Sessions

  @idle_default 600_000

  @default_form %{
    "name" => "",
    "description" => "",
    "min" => 1,
    "max" => 0,
    "idle_shutdown_after" => @idle_default,
    "session_template" => %{
      "browser_type" => "chrome",
      "headless" => false,
      "timeout" => 30,
      "ttl_seconds" => nil,
      "screen" => %{"width" => 1920, "height" => 1080, "dpi" => 96, "scale" => 1.0},
      "limits" => %{"cpu" => nil, "memory" => nil, "timeout_minutes" => 30}
    }
  }

  def index(conn, _params) do
    user = conn.assigns.current_user

    pools =
      user
      |> SessionPools.list_visible_pools()
      |> Repo.preload(:owner)
      |> Enum.map(&decorate_pool/1)

    summary = summarize_pools(pools)

    render_inertia(conn, "Pools/Index", %{
      pools: pools,
      summary: summary
    })
  end

  def new(conn, _params) do
    user = conn.assigns.current_user
    profiles = Profiles.list_user_profiles(user, status: :active)

    render_inertia(conn, "Pools/New", %{
      profiles: Enum.map(profiles, &profile_payload/1),
      form: @default_form,
      errors: %{}
    })
  end

  def create(conn, %{"pool" => pool_params}) do
    user = conn.assigns.current_user

    case SessionPools.create_pool(pool_params, user) do
      {:ok, pool} ->
        conn
        |> put_flash(:info, "Session pool created successfully")
        |> redirect(to: ~p"/pools/#{pool.id}")

      {:error, changeset} ->
        profiles = Profiles.list_user_profiles(user, status: :active)

        conn
        |> put_flash(:error, "Failed to create session pool")
        |> render_inertia("Pools/New", %{
          profiles: Enum.map(profiles, &profile_payload/1),
          form: Map.merge(@default_form, stringify_keys(pool_params)),
          errors: format_changeset_errors(changeset)
        })
    end
  end

  def show(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    case fetch_pool_for_user(id, user) do
      {:ok, pool} ->
        render_show(conn, pool, %{})

      {:error, :not_found} ->
        conn
        |> put_flash(:error, "Pool not found")
        |> redirect(to: ~p"/pools")

      {:error, :forbidden} ->
        conn
        |> put_flash(:error, "You do not have access to that pool")
        |> redirect(to: ~p"/pools")
    end
  end

  def update(conn, %{"id" => id, "pool" => pool_params}) do
    user = conn.assigns.current_user

    with {:ok, pool} <- fetch_pool_for_user(id, user),
         {:ok, updated} <- SessionPools.update_pool(pool, pool_params) do
      conn
      |> put_flash(:info, "Pool updated successfully")
      |> redirect(to: ~p"/pools/#{updated.id}")
    else
      {:error, :not_found} ->
        conn
        |> put_flash(:error, "Pool not found")
        |> redirect(to: ~p"/pools")

      {:error, :forbidden} ->
        conn
        |> put_flash(:error, "You do not have access to that pool")
        |> redirect(to: ~p"/pools")

      {:error, changeset} ->
        case fetch_pool_for_user(id, user) do
          {:ok, pool} ->
            conn
            |> put_flash(:error, "Failed to update pool")
            |> render_show(pool, %{
              form: Map.merge(@default_form, stringify_keys(pool_params)),
              errors: format_changeset_errors(changeset)
            })

          _ ->
            conn
            |> put_flash(:error, "Pool not found")
            |> redirect(to: ~p"/pools")
        end
    end
  end

  def delete(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    with {:ok, pool} <- fetch_pool_for_user(id, user),
         {:ok, _deleted} <- SessionPools.delete_pool(pool, actor: user) do
      conn
      |> put_flash(:info, "Pool deleted successfully")
      |> redirect(to: ~p"/pools")
    else
      {:error, :system_pool} ->
        conn
        |> put_flash(:error, "System pools cannot be deleted")
        |> redirect(to: ~p"/pools/#{id}")

      {:error, :last_system_pool} ->
        conn
        |> put_flash(:error, "Cannot delete the last remaining system pool")
        |> redirect(to: ~p"/pools/#{id}")

      {:error, :active_sessions} ->
        conn
        |> put_flash(:error, "Pool still has active sessions")
        |> redirect(to: ~p"/pools/#{id}")

      {:error, :not_found} ->
        conn
        |> put_flash(:error, "Pool not found")
        |> redirect(to: ~p"/pools")

      {:error, :forbidden} ->
        conn
        |> put_flash(:error, "You do not have access to that pool")
        |> redirect(to: ~p"/pools")
    end
  end

  def claim(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    with {:ok, pool} <- fetch_pool_for_user(id, user),
         {:ok, claimed} <- SessionPools.claim_session(pool, user),
         claimed = Repo.preload(claimed, [:profile, :session_pool]),
         {:ok, connection} <- Sessions.get_connection_info(claimed.id) do
      conn
      |> put_flash(:info, "Claimed session #{short_id(claimed.id)}")
      |> render_show(pool, %{
        claim_result: %{
          session: session_payload(claimed),
          connection: connection
        }
      })
    else
      {:error, :no_available_sessions} ->
        conn
        |> put_flash(:warning, "No ready sessions right now. The pool will backfill shortly.")
        |> redirect(to: ~p"/pools/#{id}")

      {:error, :not_found} ->
        conn
        |> put_flash(:error, "Pool not found")
        |> redirect(to: ~p"/pools")

      {:error, :forbidden} ->
        conn
        |> put_flash(:error, "You do not have access to that pool")
        |> redirect(to: ~p"/pools")

      {:error, reason} ->
        conn
        |> put_flash(:error, "Failed to claim a session: #{inspect(reason)}")
        |> redirect(to: ~p"/pools/#{id}")
    end
  end

  defp fetch_pool_for_user(id, user) do
    with {:ok, pool} <- SessionPools.fetch_pool(id),
         :ok <- SessionPools.authorize_manage(pool, user) do
      {:ok, pool}
    else
      {:error, :forbidden} -> {:error, :forbidden}
      error -> error
    end
  end

  defp render_show(conn, pool, extra_assigns) do
    pool = Repo.preload(pool, :owner)
    stats = SessionPools.pool_statistics(pool)
    template = SessionPools.session_template(pool)

    sessions =
      pool.id
      |> Sessions.list_sessions_for_pool(preload: [:profile, session_pool: [:owner]])
      |> Enum.map(&session_payload/1)

    user = conn.assigns.current_user

    profiles =
      user
      |> Profiles.list_user_profiles(status: :active)
      |> Enum.map(&profile_payload/1)

    assigns =
      Map.merge(
        %{
          pool: decorate_pool(pool, stats, template),
          stats: stats,
          sessions: sessions,
          profiles: profiles,
          form: Map.merge(@default_form, stringify_keys(template_form(pool, template))),
          errors: %{}
        },
        extra_assigns
      )

    render_inertia(conn, "Pools/Show", assigns)
  end

  defp decorate_pool(pool, stats \\ nil, template \\ nil) do
    stats = stats || SessionPools.pool_statistics(pool)
    template = template || SessionPools.session_template(pool)

    %{
      id: pool.id,
      name: pool.name,
      description: pool.description,
      min: pool.min_ready,
      max: pool.max_ready,
      idle_shutdown_after_ms: pool.idle_shutdown_after_ms,
      system: pool.system,
      visibility: if(pool.system, do: "system", else: "private"),
      owner:
        case pool.owner do
          nil -> nil
          owner -> %{id: owner.id, email: owner.email}
        end,
      health: pool_health(pool, stats),
      statistics: stats,
      session_template: template,
      inserted_at: pool.inserted_at,
      updated_at: pool.updated_at
    }
  end

  defp session_payload(session) do
    %{
      id: session.id,
      name: session.name,
      status: to_string(session.status || ""),
      browser_type: session.browser_type,
      cluster: session.cluster,
      headless: session.headless,
      timeout: session.timeout,
      ttl_seconds: session.ttl_seconds,
      inserted_at: session.inserted_at,
      updated_at: session.updated_at,
      claimed_at: session.claimed_at,
      attachment_deadline_at: session.attachment_deadline_at,
      profile:
        case session.profile do
          nil -> nil
          profile -> %{id: profile.id, name: profile.name}
        end,
      session_pool:
        case session.session_pool do
          nil -> nil
          assoc -> %{id: assoc.id, name: assoc.name, system: assoc.system}
        end
    }
  end

  defp summarize_pools(pools) do
    Enum.reduce(pools, %{total: 0, ready: 0, claimed: 0, running: 0, errored: 0}, fn pool, acc ->
      stats = Map.get(pool, :statistics, %{})

      %{
        total: acc.total + 1,
        ready: acc.ready + Map.get(stats, :ready, 0),
        claimed: acc.claimed + Map.get(stats, :claimed, 0),
        running: acc.running + Map.get(stats, :running, 0),
        errored: acc.errored + Map.get(stats, :errored, 0)
      }
    end)
  end

  defp pool_health(pool, stats) do
    cond do
      Map.get(stats, :errored, 0) > 0 ->
        "degraded"

      pool.min_ready == 0 and Map.get(stats, :ready, 0) == 0 ->
        "idle"

      Map.get(stats, :ready, 0) >= pool.min_ready ->
        "healthy"

      Map.get(stats, :ready, 0) + Map.get(stats, :warming, 0) >= pool.min_ready ->
        "scaling"

      true ->
        "warming"
    end
  end

  defp profile_payload(profile) do
    %{
      id: profile.id,
      name: profile.name,
      browser_type: profile.browser_type,
      status: profile.status
    }
  end

  defp format_changeset_errors(nil), do: %{}

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end

  defp stringify_keys(map) when is_map(map) do
    Map.new(map, fn
      {key, value} when is_atom(key) -> {Atom.to_string(key), stringify_keys(value)}
      {key, value} -> {key, stringify_keys(value)}
    end)
  end

  defp stringify_keys(list) when is_list(list), do: Enum.map(list, &stringify_keys/1)
  defp stringify_keys(value), do: value

  defp template_form(pool, template) do
    %{
      "name" => pool.name,
      "description" => pool.description,
      "min" => pool.min_ready,
      "max" => pool.max_ready,
      "idle_shutdown_after" => pool.idle_shutdown_after_ms,
      "session_template" => template
    }
  end

  defp short_id(nil), do: ""
  defp short_id(id) when is_binary(id), do: String.slice(id, 0, 8)
end
