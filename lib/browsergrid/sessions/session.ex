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

    field :screen, :map, default: %{"width" => 1920, "height" => 1080, "dpi" => 96, "scale" => 1.0}
    field :limits, :map, default: %{"cpu" => nil, "memory" => nil, "timeout_minutes" => 30}

    field :headless, :boolean, default: false
    field :timeout, :integer, default: 30

    belongs_to :profile, Browsergrid.Profiles.Profile, type: :binary_id

    timestamps()
  end

  # Public API

  def changeset(session, attrs) do
    session
    |> cast(attrs, [:name, :browser_type, :status, :cluster, :profile_id, :headless, :timeout, :screen, :limits])
    |> validate_required([:browser_type, :status])
    |> validate_inclusion(:browser_type, @browser_types)
    |> validate_inclusion(:status, @statuses)
    |> validate_number(:timeout, greater_than: 0)
    |> validate_screen()
    |> validate_limits()
    |> validate_profile_compatibility()
    |> put_default_name()
  end

  def create_changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:name, :browser_type, :cluster, :profile_id, :headless, :timeout, :screen, :limits])
    |> put_change(:status, :pending)
    |> validate_inclusion(:browser_type, @browser_types)
    |> validate_screen()
    |> validate_limits()
    |> validate_profile_compatibility()
    |> put_default_name()
  end

  def status_changeset(session, status) when status in @statuses do
    change(session, status: status)
  end

  def to_runtime_context(session) do
    screen = session.screen || %{"width" => 1920, "height" => 1080, "dpi" => 96, "scale" => 1.0}

    %{
      session_id: session.id,
      browser_type: session.browser_type,
      screen_width: Map.get(screen, "width", 1920),
      screen_height: Map.get(screen, "height", 1080),
      device_scale_factor: Map.get(screen, "scale", 1.0),
      screen_dpi: Map.get(screen, "dpi", 96),
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

  defp validate_screen(changeset) do
    screen = get_field(changeset, :screen) || %{}

    cond do
      is_map(screen) ->
        width = Map.get(screen, "width", 1920)
        height = Map.get(screen, "height", 1080)
        dpi = Map.get(screen, "dpi", 96)
        scale = Map.get(screen, "scale", 1.0)

        if width > 0 and height > 0 and dpi > 0 and scale > 0 do
          changeset
        else
          add_error(changeset, :screen, "invalid screen dimensions")
        end

      true ->
        add_error(changeset, :screen, "must be a map")
    end
  end

  defp validate_limits(changeset) do
    limits = get_field(changeset, :limits) || %{}

    if is_map(limits) do
      changeset
    else
      add_error(changeset, :limits, "must be a map")
    end
  end

  defp validate_profile_compatibility(changeset) do
    with profile_id when not is_nil(profile_id) <- get_field(changeset, :profile_id),
         browser_type when not is_nil(browser_type) <- get_field(changeset, :browser_type),
         profile when not is_nil(profile) <- Browsergrid.Profiles.get_profile(profile_id) do
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
  defp serialize_screen(screen) when is_map(screen) do
    screen
  end
end
