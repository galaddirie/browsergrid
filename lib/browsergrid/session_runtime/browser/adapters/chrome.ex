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
      # Security and sandboxing
      "--no-sandbox",

      # GPU and rendering
      "--disable-gpu",
      "--disable-software-rasterizer",
      "--enable-unsafe-webgpu",

      # First run and setup
      "--no-first-run",
      "--no-default-browser-check",
      "--disable-default-apps",
      "--disable-sync",
      "--disable-component-extensions-with-background-pages",

      # Memory and performance
      "--disable-dev-shm-usage",
      "--disable-background-timer-throttling",
      "--disable-background-networking",
      "--disable-renderer-backgrounding",
      "--disable-backgrounding-occluded-windows",

      # Component and service management
      "--disable-component-update",
      "--no-service-autorun",
      "--disable-background-mode",

      # Networking and connectivity
      "--no-pings",
      "--metrics-recording-only",

      # Password and credential storage
      "--password-store=basic",
      "--use-mock-keychain",

      # UI and notifications
      "--disable-infobars",
      "--deny-permission-prompts",

      # Crash reporting and debugging
      "--disable-breakpad",

      # Remote debugging
      "--remote-debugging-address=0.0.0.0",
      "--remote-allow-origins=*",

      # Security and localhost
      "--allow-insecure-localhost",

      # Anti-detection measures
      "--disable-blink-features=AutomationControlled",

      # Homepage and startup
      "--homepage=https://www.google.com",

      # Color and rendering consistency
      "--force-color-profile=srgb",

      # Flag switches
      "--flag-switches-begin",
      "--flag-switches-end",

      # Feature flags
      "--enable-features=NetworkService,NetworkServiceInProcess,LoadCryptoTokenExtension,PermuteTLSExtensions",
      "--disable-features=FlashDeprecationWarning,EnablePasswordsAccountStorage",

      # Localization
      "--accept-lang=en-US",
      "--lang=en-US"
    ]
  end

  @impl true
  def default_env(_context) do
    [{"DISPLAY", System.get_env("DISPLAY", ":1")}]
  end
end
