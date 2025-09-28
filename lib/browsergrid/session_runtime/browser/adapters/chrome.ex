defmodule Browsergrid.SessionRuntime.Browser.Adapters.Chrome do
  @moduledoc false
  @behaviour Browsergrid.SessionRuntime.Browser.Adapter

  @linux_candidates [
    "/usr/bin/google-chrome-stable",
    "/usr/bin/google-chrome",
    "/opt/google/chrome/chrome",
    "/usr/bin/chromium-browser"
  ]

  @darwin_candidates [
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
  ]

  @windows_candidates [
    "C:/Program Files/Google/Chrome/Application/chrome.exe",
    "C:/Program Files (x86)/Google/Chrome/Application/chrome.exe"
  ]

  @playwright_candidates [
    # Linux
    "~/.cache/ms-playwright/chromium/chrome-linux/chrome",
    "~/.cache/ms-playwright/chromium/chrome",
    # macOS
    "~/Library/Caches/ms-playwright/chromium/chrome-mac/Chromium.app/Contents/MacOS/Chromium",
    # Windows
    "%USERPROFILE%/AppData/Local/ms-playwright/chromium/chrome-win/chrome.exe"
  ]

  @impl true
  def command_candidates do
    [
      "google-chrome-stable",
      "google-chrome",
      "chrome"
    ] ++ @linux_candidates ++ @darwin_candidates ++ @windows_candidates ++ @playwright_candidates
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
