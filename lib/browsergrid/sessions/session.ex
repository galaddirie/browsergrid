defmodule Browsergrid.Sessions.Session do
  @moduledoc """
  Schema for a browser session with profile support
  """
  use Browsergrid.Schema

  @derive {Jason.Encoder, except: [:__meta__, :profile]}

  @browser_types [:chrome, :chromium, :firefox]
  @statuses [:pending, :running, :stopped, :error, :starting, :stopping]

  schema "sessions" do
    field :name, :string
    field :browser_type, Ecto.Enum, values: @browser_types, default: :chrome
    field :status, Ecto.Enum, values: @statuses, default: :pending
    field :cluster, :string
    field :profile_snapshot_created, :boolean, default: false

    embeds_one :screen, Screen, on_replace: :update, primary_key: false do
      field :width, :integer, default: 1920
      field :height, :integer, default: 1080
      field :dpi, :integer, default: 96
      field :scale, :float, default: 1.0
    end

    embeds_one :limits, Limits, on_replace: :update, primary_key: false do
      field :cpu, :string
      field :memory, :string
      field :timeout_minutes, :integer, default: 30
    end

    field :headless, :boolean, default: false
    field :timeout, :integer, default: 30

    belongs_to :profile, Browsergrid.Profiles.Profile, type: :binary_id

    timestamps()
  end

  # Public API

  def changeset(session, attrs) do
    session
    |> cast(attrs, [:name, :browser_type, :status, :cluster, :profile_id, :headless, :timeout])
    |> cast_embed(:screen, with: &screen_changeset/2)
    |> cast_embed(:limits, with: &limits_changeset/2)
    |> validate_required([:browser_type, :status])
    |> validate_inclusion(:browser_type, @browser_types)
    |> validate_inclusion(:status, @statuses)
    |> validate_number(:timeout, greater_than: 0)
    |> validate_profile_compatibility()
    |> put_default_name()
  end

  def create_changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:name, :browser_type, :cluster, :profile_id, :headless, :timeout])
    |> cast_embed(:screen, with: &screen_changeset/2)
    |> cast_embed(:limits, with: &limits_changeset/2)
    |> put_change(:status, :pending)
    |> put_change(:profile_snapshot_created, false)
    |> validate_inclusion(:browser_type, @browser_types)
    |> validate_profile_compatibility()
    |> put_default_name()
  end

  def status_changeset(session, status) when status in @statuses do
    change(session, status: status)
  end

  def to_runtime_context(session) do
    %{
      session_id: session.id,
      browser_type: session.browser_type,
      screen_width: get_in(session, [Access.key(:screen), Access.key(:width)]),
      screen_height: get_in(session, [Access.key(:screen), Access.key(:height)]),
      device_scale_factor: get_in(session, [Access.key(:screen), Access.key(:scale)]),
      screen_dpi: get_in(session, [Access.key(:screen), Access.key(:dpi)]),
      headless: session.headless
    }
  end

  def to_runtime_metadata(session) do
    %{
      "browser_type" => session.browser_type,
      "profile_id" => session.profile_id,
      "cluster" => session.cluster,
      "screen" => serialize_screen(session.screen),
      "headless" => session.headless
    }
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
    |> Map.new()
  end

  # Private Functions

  defp screen_changeset(schema, params) do
    schema
    |> cast(params, [:width, :height, :dpi, :scale])
    |> validate_number(:width, greater_than: 0)
    |> validate_number(:height, greater_than: 0)
    |> validate_number(:dpi, greater_than: 0)
    |> validate_number(:scale, greater_than: 0)
  end

  defp limits_changeset(schema, params) do
    cast(schema, params, [:cpu, :memory, :timeout_minutes])
  end

  defp validate_profile_compatibility(changeset) do
    with profile_id when not is_nil(profile_id) <- get_field(changeset, :profile_id),
         browser_type when not is_nil(browser_type) <- get_field(changeset, :browser_type),
         {:ok, profile} <- Browsergrid.Profiles.get_profile(profile_id) do
      if profile.browser_type == browser_type do
        changeset
      else
        add_error(changeset, :profile_id,
          "browser type mismatch: profile is #{profile.browser_type}, session is #{browser_type}")
      end
    else
      _ -> changeset
    end
  end

  defp put_default_name(changeset) do
    case get_field(changeset, :name) do
      name when name in [nil, ""] ->
        put_change(changeset, :name, "Session #{:rand.uniform(9999)}")
      _ ->
        changeset
    end
  end

  defp serialize_screen(nil), do: nil
  defp serialize_screen(%Ecto.Association.NotLoaded{}), do: nil
  defp serialize_screen(screen) do
    %{
      "width" => screen.width,
      "height" => screen.height,
      "dpi" => screen.dpi,
      "scale" => screen.scale
    }
  end
end
