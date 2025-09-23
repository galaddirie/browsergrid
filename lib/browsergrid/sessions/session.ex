defmodule Browsergrid.Sessions.Session do
  @moduledoc """
  Ecto schema for a browser session with profile support
  """

  use Browsergrid.Schema

  @derive {Jason.Encoder, except: [:__meta__, :profile]}

  @browser_types [:chrome, :chromium]
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
    |> cast(attrs, [:name, :browser_type, :status, :options, :cluster, :profile_id, :profile_snapshot_created])
    |> validate_required([:browser_type, :status])
    |> validate_inclusion(:browser_type, @browser_types)
    |> validate_inclusion(:status, @statuses)
    |> validate_profile_browser_compatibility()
    |> put_default_name()
    |> put_default_options()
  end

  def create_changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:name, :browser_type, :options, :cluster, :profile_id])
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

    options = get_field(changeset, :options) || %{}
    processed_options = process_option_values(options)
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

  defp generate_session_name do
    "Session #{:rand.uniform(9999)}"
  end
end
