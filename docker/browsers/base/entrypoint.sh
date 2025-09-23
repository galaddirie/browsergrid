#!/bin/bash
set -e

# Ensure npm cache has correct permissions
if [ -d "${HOME}/.npm" ]; then
  chown -R ${UID}:${GID} "${HOME}/.npm"
fi

rm -f /tmp/.X0-lock #


# Update Chrome's homepage to use the HTTP service worker server instead of file:///

/usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf &

echo "Supervisor started"


echo "Waiting for X server to be ready..."
max_attempts=30
attempt=0
while ! xdpyinfo -display "$DISPLAY" >/dev/null 2>&1; do
    attempt=$((attempt+1))
    if [ $attempt -ge $max_attempts ]; then
        echo "X server failed to start after $max_attempts attempts. Exiting."
        # break out of the loop
        break
    fi
    echo "X server not ready yet. Waiting... (Attempt $attempt/$max_attempts)"
    sleep 1
done

echo "X server is ready!"

# Execute the original command
exec "$@"