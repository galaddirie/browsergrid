defmodule Browsergrid.SessionRuntime.Browser.Adapters.Chrome do
  @moduledoc false
  @behaviour Browsergrid.SessionRuntime.Browser.Adapter

  @linux_candidates [
    "/usr/bin/google-chrome-stable",
    "/usr/bin/google-chrome",
    "/opt/google/chrome/chrome"
  ]

  @darwin_candidates [
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
  ]

  @windows_candidates [
    "C:/Program Files/Google/Chrome/Application/chrome.exe",
    "C:/Program Files (x86)/Google/Chrome/Application/chrome.exe"
  ]

  @impl true
  def command_candidates do
    [
      "google-chrome-stable",
      "google-chrome",
      "chrome"
    ] ++ @linux_candidates ++ @darwin_candidates ++ @windows_candidates
  end

  @impl true
  def default_args(_context) do
    [
      "--disable-gpu",
      "--disable-software-rasterizer"
    ]
  end

  @impl true
  def default_env(_context), do: []
end
