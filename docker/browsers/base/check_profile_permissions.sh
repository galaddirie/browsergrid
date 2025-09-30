#!/bin/bash

# Helper script to check and potentially fix profile permissions
# This script should be run from within the browser container

PROFILE_PATH="$1"
USER_ID=$(id -u)
GROUP_ID=$(id -g)

if [ -z "$PROFILE_PATH" ]; then
    echo "Usage: $0 <profile_path>"
    exit 1
fi

echo "Checking profile permissions for: $PROFILE_PATH"
echo "Current user: $(id -un) (UID: $USER_ID, GID: $GROUP_ID)"

if [ ! -d "$PROFILE_PATH" ]; then
    echo "ERROR: Profile path does not exist: $PROFILE_PATH"
    exit 1
fi

# Check if we can read the directory
if [ ! -r "$PROFILE_PATH" ]; then
    echo "ERROR: Cannot read profile directory: $PROFILE_PATH"
    ls -la "$PROFILE_PATH/.." 2>/dev/null || echo "Cannot list parent directory"
    exit 1
fi

# Check if we can write to the directory
if [ ! -w "$PROFILE_PATH" ]; then
    echo "WARNING: Cannot write to profile directory: $PROFILE_PATH"
    echo "This may cause Chrome to fail"
fi

# Show detailed permissions
echo "Profile directory permissions:"
ls -la "$PROFILE_PATH"

# Check a few key files/directories that Chrome typically needs
CHECK_PATHS=(
    "."
    "Default"
    "Default/Preferences"
    "Default/Local State"
    "Default/Cache"
    "Default/Sessions"
)

for path in "${CHECK_PATHS[@]}"; do
    full_path="$PROFILE_PATH/$path"
    if [ -e "$full_path" ]; then
        echo "Checking $path:"
        ls -la "$full_path" 2>/dev/null || echo "  Cannot stat $path"
        
        # Check if we can read
        if [ -r "$full_path" ]; then
            echo "  ✓ Readable"
        else
            echo "  ✗ Not readable"
        fi
        
        # Check if we can write (if it's a directory or file we should be able to write to)
        if [ -d "$full_path" ] || [ -f "$full_path" ]; then
            if [ -w "$full_path" ]; then
                echo "  ✓ Writable"
            else
                echo "  ✗ Not writable"
            fi
        fi
    fi
done

# Try to fix permissions if we're running as root or have sudo access
if [ "$USER_ID" -eq 0 ] || sudo -n true 2>/dev/null; then
    echo "Attempting to fix permissions..."
    
    # Make sure the profile directory is owned by the browser user (UID 1000)
    if [ "$USER_ID" -eq 0 ]; then
        chown -R 1000:1000 "$PROFILE_PATH" 2>/dev/null && echo "✓ Fixed ownership" || echo "✗ Could not fix ownership"
        chmod -R 755 "$PROFILE_PATH" 2>/dev/null && echo "✓ Fixed permissions" || echo "✗ Could not fix permissions"
    else
        sudo chown -R 1000:1000 "$PROFILE_PATH" 2>/dev/null && echo "✓ Fixed ownership" || echo "✗ Could not fix ownership"
        sudo chmod -R 755 "$PROFILE_PATH" 2>/dev/null && echo "✓ Fixed permissions" || echo "✗ Could not fix permissions"
    fi
else
    echo "Cannot fix permissions - no root access"
fi

echo "Permission check complete." 