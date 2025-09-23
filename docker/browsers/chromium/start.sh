#!/bin/bash
# Update docker/browsers/chromium/start.sh

set -e

# Create log directory with proper permissions if it doesn't exist
if [ ! -d "/var/log" ] || [ ! -w "/var/log" ]; then
  sudo mkdir -p /var/log
  sudo chmod 777 /var/log
fi

rm -f /tmp/.X0-lock

until xdpyinfo -display "$DISPLAY" >/dev/null 2>&1; do
  echo "Waiting for X server on $DISPLAY..."
  sleep 0.1
done

PROXY_ARG=""
if [ -n "$PROXY_SERVER" ]; then
  echo "Using proxy server: $PROXY_SERVER"
  PROXY_ARG="--proxy-server=$PROXY_SERVER"
fi

# Use USER_DATA_DIR environment variable if set, otherwise use default
if [ -n "$USER_DATA_DIR" ]; then
  DATA_DIR="$USER_DATA_DIR"
  echo "Using profile directory from environment: $DATA_DIR"
else
  DATA_DIR="${HOME}/data-dir"
  echo "Using default profile directory: $DATA_DIR"
fi

# Ensure data directory exists
if [ ! -d "${DATA_DIR}" ]; then
  echo "Creating data directory at ${DATA_DIR}"
  mkdir -p "${DATA_DIR}"
fi

# Find the Playwright Chromium executable
BROWSER_PATH=$(find /home/user/.cache/ms-playwright -path "*/chrome-linux/chrome" -type f -executable | head -1)

if [ -z "$BROWSER_PATH" ]; then
  echo "Playwright Chromium not found, falling back to system Chrome"
  BROWSER_PATH="/usr/bin/chromium-browser"
fi

export GOOGLE_API_KEY="AIzaSyCkfPOPZXDKNn8hhgu3JrA62wIgC93d44k"
export GOOGLE_DEFAULT_CLIENT_ID="811574891467.apps.googleusercontent.com"
export GOOGLE_DEFAULT_CLIENT_SECRET="kdloedMFGdGla2P1zacGjAQh"

echo "Starting Chromium with data directory: ${DATA_DIR}"
echo "Browser path: ${BROWSER_PATH}"

$BROWSER_PATH \
  --no-sandbox \
  --no-first-run \
  --disable-dev-shm-usage \
  --disable-component-update \
  --no-service-autorun \
  --password-store=basic \
  --disable-backgrounding-occluded-windows \
  --disable-renderer-backgrounding \
  --disable-background-timer-throttling \
  --disable-background-networking \
  --no-pings \
  --disable-infobars \
  --disable-breakpad \
  --no-default-browser-check \
  --remote-debugging-address=0.0.0.0 \
  --remote-debugging-port=${REMOTE_DEBUGGING_PORT} \
  --remote-allow-origins=* \
  --window-size=${RESOLUTION_WIDTH},${RESOLUTION_HEIGHT} \
  --user-data-dir=${DATA_DIR} \
  --allow-insecure-localhost \
  --disable-blink-features=AutomationControlled \
  --flag-switches-begin \
  --flag-switches-end \
  --force-color-profile=srgb \
  --metrics-recording-only \
  --use-mock-keychain \
  --disable-background-mode \
  --enable-features=NetworkService,NetworkServiceInProcess,LoadCryptoTokenExtension,PermuteTLSExtensions \
  --disable-features=FlashDeprecationWarning,EnablePasswordsAccountStorage \
  --deny-permission-prompts \
  --accept-lang=en-US \
  --lang=en-US \
  --disable-gpu \
  --enable-unsafe-webgpu \
  $PROXY_ARG > /var/log/chrome.log 2> /var/log/chrome.err &

sleep 2

echo "Chromium process started, checking logs:"
head -20 /var/log/chrome.err

# Keep container running by tailing the logs
tail -f /var/log/chrome.log /var/log/chrome.err