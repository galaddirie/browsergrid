defmodule BrowsergridWeb.Inertia.V1.ApiTokenController do
  use BrowsergridWeb, :controller

  alias Browsergrid.ApiTokens

  def index(conn, _params) do
    user = conn.assigns.current_user
    render_index(conn, user)
  end

  def create(conn, %{"api_token" => params}) do
    do_create(conn, params)
  end

  def create(conn, params) when is_map(params) do
    do_create(conn, params)
  end

  def delete(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    case ApiTokens.revoke_token(id, user) do
      {:ok, _token} ->
        conn
        |> put_flash(:info, "API token revoked")
        |> redirect(to: ~p"/settings/api")

      {:error, :already_revoked} ->
        conn
        |> put_flash(:info, "API token already revoked")
        |> redirect(to: ~p"/settings/api")

      {:error, :not_found} ->
        conn
        |> put_flash(:error, "API token not found")
        |> redirect(to: ~p"/settings/api")
    end
  end

  defp do_create(conn, params) do
    user = conn.assigns.current_user

    case ApiTokens.create_token(user, params) do
      {:ok, _token, plaintext} ->
        conn
        |> put_flash(:info, "API token created successfully")
        |> put_session(:generated_api_token, plaintext)
        |> redirect(to: ~p"/settings/api")

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render_index(user,
          errors: format_changeset_errors(changeset),
          form: %{
            "name" => Map.get(params, "name", ""),
            "expires_at" => Map.get(params, "expires_at")
          }
        )
    end
  end

  defp render_index(conn, user, opts \\ []) do
    tokens = ApiTokens.list_user_tokens(user)
    {plaintext, conn} = pop_generated_token(conn)

    errors = Keyword.get(opts, :errors, %{})
    form = Keyword.get(opts, :form, %{"name" => "", "expires_at" => nil})
    generated = Keyword.get(opts, :generated_token) || plaintext

    conn
    |> assign_prop(:tokens, Enum.map(tokens, &serialize_token/1))
    |> assign_prop(:form, form)
    |> assign_prop(:errors, errors)
    |> maybe_assign_generated_token(generated)
    |> render_inertia("Settings/ApiTokens")
  end

  defp serialize_token(token) do
    %{
      id: token.id,
      name: token.name,
      prefix: token.token_prefix,
      created_at: format_datetime(token.inserted_at),
      last_used_at: format_datetime(token.last_used_at),
      expires_at: format_datetime(token.expires_at)
    }
  end

  defp format_datetime(nil), do: nil

  defp format_datetime(%DateTime{} = datetime) do
    DateTime.to_iso8601(datetime)
  end

  defp maybe_assign_generated_token(conn, nil), do: conn

  defp maybe_assign_generated_token(conn, token) do
    assign_prop(conn, :generated_token, token)
  end

  defp pop_generated_token(conn) do
    token = get_session(conn, :generated_api_token)
    conn = delete_session(conn, :generated_api_token)
    {token, conn}
  end

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Enum.reduce(opts, message, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
