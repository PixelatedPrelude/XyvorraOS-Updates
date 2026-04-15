#!/usr/bin/env bash
# Runs before any files are copied or packages installed.
# Exit non-zero to abort the update.

echo "Running pre-update checks for v1.0.0..."

# Example: check minimum disk space (500MB)
available=$(df / --output=avail -k | tail -1)
if [[ "$available" -lt 512000 ]]; then
    echo "Not enough disk space to apply update (need 500MB free)."
    exit 1
fi

exit 0
