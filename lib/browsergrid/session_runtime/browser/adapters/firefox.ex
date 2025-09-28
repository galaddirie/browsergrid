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

  @impl true
  def command_candidates do
    ["firefox"] ++ @linux_candidates ++ @darwin_candidates ++ @windows_candidates
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
