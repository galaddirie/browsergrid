defmodule Browsergrid.SessionRuntime.Browser.Adapters.Firefox do
  @moduledoc false
  @behaviour Browsergrid.SessionRuntime.Browser.Adapter

  @linux_candidates [
    "/usr/bin/firefox"
  ]

  @darwin_candidates [
    "/Applications/Firefox.app/Contents/MacOS/firefox"
  ]

  @windows_candidates [
    "C:/Program Files/Mozilla Firefox/firefox.exe",
    "C:/Program Files (x86)/Mozilla Firefox/firefox.exe"
  ]

  @playwright_candidates [
    # Linux
    "~/.cache/ms-playwright/firefox-nightly/firefox/firefox",
    "~/.cache/ms-playwright/firefox/firefox",
    # macOS
    "~/Library/Caches/ms-playwright/firefox-nightly/firefox/firefox",
    "~/Library/Caches/ms-playwright/firefox/firefox",
    # Windows
    "%USERPROFILE%/AppData/Local/ms-playwright/firefox-nightly/firefox/firefox.exe",
    "%USERPROFILE%/AppData/Local/ms-playwright/firefox/firefox/firefox.exe"
  ]

  @impl true
  def command_candidates do
    ["firefox"] ++ @linux_candidates ++ @darwin_candidates ++ @windows_candidates ++ @playwright_candidates
  end

  @impl true
  def default_args(_context) do
    [
      "--devtools",
      "--safe-mode"
    ]
  end

  @impl true
  def default_env(_context), do: []
end
