defmodule BrowsergridWeb.SystemUtils do
  @moduledoc """
  Utility functions for system detection and configuration.
  """

  @type browser_type :: :chrome | :chromium | :firefox

  @doc """
  Determines the default browser type based on the system architecture.
  Returns :chromium for ARM-based systems (like Apple Silicon Macs) and :chrome for others.
  """
  @spec default_browser_type() :: browser_type()
  def default_browser_type do
    cond do
      is_arm_system?() -> :chromium
      true -> :chrome
    end
  end

  @doc """
  Checks if the current system is ARM-based.
  """
  @spec is_arm_system?() :: boolean()
  def is_arm_system? do
    case System.cmd("uname", ["-m"]) do
      {architecture, 0} ->
        String.contains?(architecture, "arm") or String.contains?(architecture, "aarch64")
      _ ->
        false
    end
  end

  @doc """
  Checks if the current system is macOS.
  """
  @spec is_macos?() :: boolean()
  def is_macos? do
    case System.cmd("uname", ["-s"]) do
      {"Darwin" <> _, 0} -> true
      _ -> false
    end
  end
end
