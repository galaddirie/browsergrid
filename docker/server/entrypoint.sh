#!/bin/bash
set -e

# Ensure npm cache has correct permissions
if [ -d "${HOME}/.npm" ]; then
  chown -R ${UID}:${GID} "${HOME}/.npm"
fi

# Clean up any stale X locks and ensure proper permissions for X11
rm -f /tmp/.X0-lock
rm -f /tmp/.X1-lock
rm -f /tmp/.X11-unix/X0
rm -f /tmp/.X11-unix/X1

# Ensure /tmp/.X11-unix exists with correct permissions
mkdir -p /tmp/.X11-unix
chmod 1777 /tmp/.X11-unix

# Start supervisord to bring up Xvfb/x11vnc (runs in background)
/usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf &

echo "Supervisor started"

# Wait for X server to become ready before continuing
echo "Waiting for X server on ${DISPLAY:-unset}..."
attempt=0
max_attempts=30
until xdpyinfo -display "$DISPLAY" >/dev/null 2>&1; do
  attempt=$((attempt + 1))
  if [ $attempt -ge $max_attempts ]; then
    echo "X server failed to start within ${max_attempts}s; continuing anyway"
    break
  fi
  sleep 1
done

echo "X server ready (or continuing after timeout)"

exec "$@"