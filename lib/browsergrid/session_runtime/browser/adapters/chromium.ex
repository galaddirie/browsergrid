defmodule Browsergrid.SessionRuntime.Browser.Adapters.Chromium do
  @moduledoc false
  @behaviour Browsergrid.SessionRuntime.Browser.Adapter

  @linux_candidates [
    "/usr/bin/chromium-browser",
    "/usr/bin/chromium",
    "/snap/bin/chromium"
  ]

  @windows_candidates [
    "C:/Program Files/Chromium/Application/chrome.exe",
    "C:/Program Files (x86)/Chromium/Application/chrome.exe"
  ]

  @impl true
  def command_candidates do
    [
      "chromium-browser",
      "chromium"
    ] ++ @linux_candidates ++ @windows_candidates
  end

  @impl true
  def default_args(_context) do
    [
      "--disable-gpu"
    ]
  end

  @impl true
  def default_env(_context) do
    [
      {"GOOGLE_API_KEY", "AIzaSyCkfPOPZXDKNn8hhgu3JrA62wIgC93d44k"},
      {"GOOGLE_DEFAULT_CLIENT_ID", "811574891467.apps.googleusercontent.com"},
      {"GOOGLE_DEFAULT_CLIENT_SECRET", "kdloedMFGdGla2P1zacGjAQh"}
    ]
  end
end
