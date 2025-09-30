#!/usr/bin/env bash
set -euo pipefail

REMOTE_DEBUG_PORT="${CHROME_REMOTE_DEBUG_PORT:-9222}"
REMOTE_DEBUG_ADDRESS="${CHROME_REMOTE_DEBUG_ADDRESS:-0.0.0.0}"
PROFILE_DIR="${CHROME_REMOTE_PROFILE_DIR:-/var/lib/browsergrid/chrome-profile}"
CHROME_BIN="${CHROME_BIN:-}";

# Determine which Chromium/Chrome binary to use
if [ -n "$CHROME_BIN" ] && command -v "$CHROME_BIN" >/dev/null 2>&1; then
  BROWSER_CMD="$CHROME_BIN"
else
  for candidate in chromium chromium-browser google-chrome-stable google-chrome; do
    if command -v "$candidate" >/dev/null 2>&1; then
      BROWSER_CMD="$candidate"
      break
    fi
  done
fi

if [ -z "${BROWSER_CMD:-}" ]; then
  echo "[openbox-autostart] No Chrome/Chromium binary found in PATH" >&2
else
  mkdir -p "$PROFILE_DIR"
  # Launch browser with remote debugging enabled and minimal GPU usage for headless environments
  "$BROWSER_CMD" \
    --no-sandbox \
    --disable-gpu \
    --disable-software-rasterizer \
    --enable-unsafe-webgpu \
    --no-first-run \
    --disable-default-apps \
    --disable-sync \
    --disable-component-extensions-with-background-pages \
    --homepage=https://www.google.com \
    --force-color-profile=srgb \
    --flag-switches-begin \
    --flag-switches-end \
    --enable-features=NetworkService,NetworkServiceInProcess,LoadCryptoTokenExtension,PermuteTLSExtensions \
    --disable-features=FlashDeprecationWarning,EnablePasswordsAccountStorage \
    --accept-lang=en-US \
    --lang=en-US \
    --remote-debugging-port="$REMOTE_DEBUG_PORT" \
    --remote-debugging-address="$REMOTE_DEBUG_ADDRESS" \
    --user-data-dir="$PROFILE_DIR" \
    --no-first-run \
    --disable-default-apps \
    --disable-dev-shm-usage \
    --disable-gpu \
    --start-maximized &
fi

# Start a terminal for interactive CLI access inside the VNC session
if command -v xterm >/dev/null 2>&1; then
  xterm &
fi
