#!/bin/bash
set -e

# Test nginx configuration
nginx -t

# Nginx configuration is now static and properly configured
echo "Nginx configured to proxy to browsermux on port 8080" 