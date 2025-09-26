#!/bin/bash
set -euo pipefail

# Set up environment if needed
export PATH="/app/bin:$PATH"

# Ensure browseruser home and writable dirs are properly set (already done in Dockerfile)
# For any dynamic setup, add here (e.g., generate session-specific config)

# Trap signals for clean shutdown
trap 'echo "Received signal, shutting down gracefully..."; /app/bin/browsergrid stop || true; exit 0' SIGTERM SIGINT

# Start the Elixir release
exec /app/bin/browsergrid start
