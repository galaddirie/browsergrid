defmodule Browsergrid.Sessions.Session do
  @moduledoc """
  Ecto schema for a browser session with profile support
  """
  use Browsergrid.Schema

  @derive {Jason.Encoder, except: [:__meta__, :profile]}

  @browser_types [:chrome, :chromium, :firefox]
  @statuses [:pending, :running, :stopped, :error, :starting, :stopping]

  defmodule ScreenOptions do
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key false
    embedded_schema do
      field :width, :integer, default: 1920
      field :height, :integer, default: 1080
      field :dpi, :integer, default: 96
      field :scale, :float, default: 1.0
    end

    def changeset(schema, params) do
      schema
      |> cast(params, [:width, :height, :dpi, :scale])
      |> validate_number(:width, greater_than: 0)
      |> validate_number(:height, greater_than: 0)
    end
  end

  defmodule ResourceLimits do
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key false
    embedded_schema do
      field :cpu, :string
      field :memory, :string
      field :timeout_minutes, :integer, default: 30
    end

    def changeset(schema, params) do
      cast(schema, params, [:cpu, :memory, :timeout_minutes])
    end
  end

  defmodule SessionOptions do
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key false
    embedded_schema do
      field :headless, :boolean, default: false
      field :timeout, :integer, default: 30
      embeds_one :screen, ScreenOptions, on_replace: :update
      embeds_one :resource_limits, ResourceLimits, on_replace: :update
    end

    def changeset(schema, params) do
      schema
      |> cast(params, [:headless, :timeout])
      |> cast_embed(:screen)
      |> cast_embed(:resource_limits)
    end
  end

  schema "sessions" do
    field :name, :string
    field :browser_type, Ecto.Enum, values: @browser_types, default: :chrome
    field :status, Ecto.Enum, values: @statuses, default: :pending
    field :cluster, :string
    field :profile_snapshot_created, :boolean, default: false

    # Use map for backward compatibility, but validate with embedded schema
    field :options, :map, default: %{}

    belongs_to :profile, Browsergrid.Profiles.Profile, type: :binary_id

    timestamps()
  end

  # Simplified changesets
  def changeset(session, attrs) do
    session
    |> cast(attrs, [:name, :browser_type, :status, :cluster, :profile_id, :profile_snapshot_created])
    |> validate_required([:browser_type, :status])
    |> validate_inclusion(:browser_type, @browser_types)
    |> validate_inclusion(:status, @statuses)
    |> cast_and_validate_options(attrs)
    |> validate_profile_compatibility()
    |> put_default_name()
  end

  def create_changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:name, :browser_type, :cluster, :profile_id])
    |> validate_inclusion(:browser_type, @browser_types)
    |> put_change(:status, :pending)
    |> put_change(:profile_snapshot_created, false)
    |> cast_and_validate_options(attrs)
    |> validate_profile_compatibility()
    |> put_default_name()
  end

  def status_changeset(session, new_status) when new_status in @statuses do
    change(session, status: new_status)
  end

  # Private helpers
  defp cast_and_validate_options(changeset, attrs) do
    options = get_field(changeset, :options) || %{}
    incoming = Map.get(attrs, "options") || Map.get(attrs, :options) || %{}

    # Merge and normalize options
    merged = Map.merge(default_options(), options) |> Map.merge(incoming)

    # Validate using embedded schema
    case SessionOptions.changeset(%SessionOptions{}, merged) do
      %{valid?: true} = opts_changeset ->
        # Convert back to map for storage
        validated_options = Ecto.Changeset.apply_changes(opts_changeset) |> Map.from_struct()
        put_change(changeset, :options, Map.merge(merged, validated_options))

      _invalid ->
        changeset
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
    if get_field(changeset, :name) in [nil, ""] do
      put_change(changeset, :name, "Session #{:rand.uniform(9999)}")
    else
      changeset
    end
  end

  defp default_options do
    %{
      "headless" => false,
      "timeout" => 30,
      "screen" => %{"width" => 1920, "height" => 1080, "dpi" => 96, "scale" => 1.0}
    }
  end
end
