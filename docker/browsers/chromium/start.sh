#!/bin/bash
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

# Function to safely start Chromium with error handling
start_chromium() {
  echo "Starting Chromium with data directory: ${HOME}/data-dir"
  echo "Chromium will be started with the following command:"
  echo "/usr/bin/chromium --no-sandbox --no-first-run --user-data-dir=${HOME}/data-dir ..."

  # Check if data directory exists and is accessible
  if [ ! -d "${HOME}/data-dir" ]; then
    echo "ERROR: Data directory ${HOME}/data-dir does not exist!"
    return 1
  fi

  # Check if we can write to the data directory
  if [ ! -w "${HOME}/data-dir" ]; then
    echo "WARNING: Cannot write to data directory ${HOME}/data-dir"
    echo "This may cause Chromium to fail. Attempting to fix permissions..."

    # Try to fix permissions if possible
    if sudo chmod 755 "${HOME}/data-dir" 2>/dev/null; then
      echo "Fixed permissions on data directory"
    else
      echo "Cannot fix permissions - this may cause Chromium to fail"
    fi
  fi

  # List contents of data directory for debugging
  echo "Data directory contents:"
  ls -la "${HOME}/data-dir" || echo "Cannot list directory contents"

  # Test if Chromium can at least start with --version
  echo "Testing Chromium binary..."
  if ! /usr/bin/chromium --version >/dev/null 2>&1; then
    echo "ERROR: Chromium binary is not working!"
    return 1
  fi

  echo "Chromium binary test passed"

  # Start Chromium with error handling
  /usr/bin/chromium \
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
    --user-data-dir=${HOME}/data-dir \
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
    $PROXY_ARG > /var/log/chromium.log 2> /var/log/chromium.err &

  CHROMIUM_PID=$!
  echo "Chromium started with PID: $CHROMIUM_PID"

  # Wait a bit to see if Chromium starts successfully
  sleep 3

  # Check if Chromium is still running
  if ! kill -0 $CHROMIUM_PID 2>/dev/null; then
    echo "ERROR: Chromium process died immediately!"
    echo "Chromium stdout:"
    cat /var/log/chromium.log 2>/dev/null || echo "No stdout log available"
    echo "Chromium stderr:"
    cat /var/log/chromium.err 2>/dev/null || echo "No stderr log available"
    return 1
  fi

  echo "Chromium appears to be running successfully"

  # Wait for Chromium process to finish
  wait $CHROMIUM_PID
  local exit_code=$?

  echo "Chromium process exited with code: $exit_code"
  echo "Chromium stdout:"
  cat /var/log/chromium.log 2>/dev/null || echo "No stdout log available"
  echo "Chromium stderr:"
  cat /var/log/chromium.err 2>/dev/null || echo "No stderr log available"

  return $exit_code
}

# Handle profile data directory setup (single, elegant path)
if [ -d "${HOME}/data-dir" ]; then
  echo "Using data directory: ${HOME}/data-dir"
  # Optionally run permission checker if present
  if [ -f "/usr/local/bin/check_profile_permissions.sh" ]; then
    /usr/local/bin/check_profile_permissions.sh "${HOME}/data-dir" || true
  fi
else
  echo "Creating Chromium data directory"
  mkdir -p ${HOME}/data-dir
  chmod 755 ${HOME}/data-dir || true
fi

PROXY_ARG=""
if [ -n "$PROXY_SERVER" ]; then
  echo "Using proxy server: $PROXY_SERVER"
  PROXY_ARG="--proxy-server=$PROXY_SERVER"
fi

# Try to start Chromium with retries
MAX_RETRIES=3
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
  echo "Chromium startup attempt $((RETRY_COUNT + 1)) of $MAX_RETRIES"

  if start_chromium; then
    echo "Chromium exited normally"
    exit 0
  else
    RETRY_COUNT=$((RETRY_COUNT + 1))
    echo "Chromium failed to start or crashed (attempt $RETRY_COUNT)"

    if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
      echo "Retrying in 5 seconds..."
      sleep 5

      # For persistent failures, ensure we have a clean data directory
      if [ $RETRY_COUNT -eq 2 ]; then
        echo "Trying with a fresh data directory due to repeated failures..."
        rm -rf ${HOME}/data-dir
        mkdir -p ${HOME}/data-dir
        chmod 755 ${HOME}/data-dir
      fi
    fi
  fi
done

echo "Chromium failed to start after $MAX_RETRIES attempts"
echo "Keeping container alive for debugging..."

# Keep container alive so we can debug
tail -f /var/log/chromium.log /var/log/chromium.err &
sleep infinity
