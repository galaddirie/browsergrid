defmodule Browsergrid.Sessions.Session do
  @moduledoc """
  Ecto schema for a browser session with profile support
  """

  use Browsergrid.Schema

  @derive {Jason.Encoder, except: [:__meta__, :profile]}

  @browser_types [:chrome, :chromium, :firefox]
  @statuses [:pending, :running, :stopped, :error, :starting, :stopping]

  @type t :: %__MODULE__{
    id: Ecto.UUID.t() | nil,
    name: String.t() | nil,
    browser_type: atom() | nil,
    status: atom() | nil,
    options: map() | nil,
    cluster: String.t() | nil,
    profile_id: Ecto.UUID.t() | nil,
    profile_snapshot_created: boolean()
  }

  schema "sessions" do
    field :name, :string
    field :browser_type, Ecto.Enum, values: @browser_types, default: :chrome
    field :status, Ecto.Enum, values: @statuses, default: :pending
    field :options, :map, default: %{}
    field :cluster, :string
    field :profile_snapshot_created, :boolean, default: false

    # Profile association
    belongs_to :profile, Browsergrid.Profiles.Profile, type: :binary_id

    timestamps()
  end

  def changeset(session, attrs) do
    session
    |> cast(attrs, [:name, :browser_type, :status, :options, :cluster, :profile_id, :profile_snapshot_created, :headless, :is_pooled, :operating_system, :provider, :version, :webhooks_enabled])
    |> validate_required([:browser_type, :status])
    |> validate_inclusion(:browser_type, @browser_types)
    |> validate_inclusion(:status, @statuses)
    |> validate_profile_browser_compatibility()
    |> put_default_name()
    |> put_default_options()
  end

  def create_changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:name, :browser_type, :options, :cluster, :profile_id, :headless, :is_pooled, :operating_system, :provider, :version, :webhooks_enabled])
    |> validate_inclusion(:browser_type, @browser_types)
    |> validate_profile_browser_compatibility()
    |> put_change(:status, :pending)
    |> put_change(:profile_snapshot_created, false)
    |> put_default_name()
    |> put_default_options()
  end

  def status_changeset(%__MODULE__{} = session, new_status)
      when new_status in @statuses do
    change(session, status: new_status)
  end

  defp validate_profile_browser_compatibility(changeset) do
    profile_id = get_field(changeset, :profile_id)
    browser_type = get_field(changeset, :browser_type)

    if profile_id && browser_type do
      # Load profile to check browser compatibility
      case Browsergrid.Profiles.get_profile(profile_id) do
        nil ->
          add_error(changeset, :profile_id, "profile not found")
        profile ->
          if profile.browser_type != browser_type do
            add_error(changeset, :profile_id,
              "profile browser type (#{profile.browser_type}) doesn't match session browser type (#{browser_type})")
          else
            changeset
          end
      end
    else
      changeset
    end
  end

  defp put_default_name(changeset) do
    case get_field(changeset, :name) do
      nil -> put_change(changeset, :name, generate_session_name())
      "" -> put_change(changeset, :name, generate_session_name())
      _ -> changeset
    end
  end

  defp put_default_options(changeset) do
    default_options = %{
      "headless" => false,
      "timeout" => 30,
      "screen_width" => 1920,
      "screen_height" => 1080,
      "profile_enabled" => get_field(changeset, :profile_id) != nil
    }

    # Extract additional fields from changeset and put them in options
    extra_options = %{}
    extra_options = put_extra_option(changeset, extra_options, :headless)
    extra_options = put_extra_option(changeset, extra_options, :is_pooled)
    extra_options = put_extra_option(changeset, extra_options, :operating_system)
    extra_options = put_extra_option(changeset, extra_options, :provider)
    extra_options = put_extra_option(changeset, extra_options, :version)
    extra_options = put_extra_option(changeset, extra_options, :webhooks_enabled)

    options = get_field(changeset, :options) || %{}
    # Merge extra options with existing options
    all_options = Map.merge(options, extra_options)

    # Handle nested structures from frontend
    flattened_options = flatten_frontend_options(all_options)
    processed_options = process_option_values(flattened_options)
    merged_options = Map.merge(default_options, processed_options)

    put_change(changeset, :options, merged_options)
  end

  defp process_option_values(options) do
    options
    |> Enum.map(fn {key, value} -> {key, process_option_value(key, value)} end)
    |> Map.new()
  end

  defp process_option_value("headless", value) when is_binary(value) do
    value == "true"
  end
  defp process_option_value("timeout", value) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} -> int
      :error -> 30
    end
  end
  defp process_option_value("screen_width", value) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} -> int
      :error -> 1920
    end
  end
  defp process_option_value("screen_height", value) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} -> int
      :error -> 1080
    end
  end
  defp process_option_value(_key, value), do: value

  # Extract cast fields that should go into options
  defp put_extra_option(changeset, options, field) do
    case get_change(changeset, field) do
      nil -> options
      value -> Map.put(options, Atom.to_string(field), value)
    end
  end

  # Flatten nested frontend options into the format expected by the schema
  defp flatten_frontend_options(options) do
    options
    |> flatten_screen_options()
    |> flatten_resource_limits_options()
  end

  defp flatten_screen_options(options) do
    case options["screen"] do
      nil -> options
      screen when is_map(screen) ->
        options
        |> Map.delete("screen")
        |> Map.put("screen_width", screen["width"] || 1920)
        |> Map.put("screen_height", screen["height"] || 1080)
        |> Map.put("screen_dpi", screen["dpi"] || 96)
        |> Map.put("screen_scale", screen["scale"] || 1.0)
    end
  end

  defp flatten_resource_limits_options(options) do
    case options["resource_limits"] do
      nil -> options
      limits when is_map(limits) ->
        options
        |> Map.delete("resource_limits")
        |> Map.put("cpu_cores", limits["cpu"])
        |> Map.put("memory_limit", limits["memory"])
        |> Map.put("timeout", limits["timeout_minutes"] || 30)
    end
  end

  defp generate_session_name do
    "Session #{:rand.uniform(9999)}"
  end
end
