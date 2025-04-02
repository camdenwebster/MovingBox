#!/bin/bash
set -e

# Define the output xcconfig path
CONFIG_FILE="${SRCROOT}/MovingBox/Configuration/Base.xcconfig"

# Skip if we're in CI or if the config file already exists
if [ "$CI" == "true" ]; then
    echo "Skipping JWT configuration - running in CI environment"
    exit 0
fi

if [ -f "$CONFIG_FILE" ]; then
    echo "Base.xcconfig already exists, skipping configuration"
    exit 0
fi

# Get the path to the scripts directory
SCRIPT_DIR="${SRCROOT}/ci_scripts"
CI_POST_CLONE_SCRIPT="$SCRIPT_DIR/ci_post_clone.sh"

# Check if the script exists and run it
if [ -f "$CI_POST_CLONE_SCRIPT" ]; then
    echo "Running JWT configuration script for local development..."
    chmod +x "$CI_POST_CLONE_SCRIPT"
    "$CI_POST_CLONE_SCRIPT"
else
    echo "Error: ci_post_clone.sh not found at $CI_POST_CLONE_SCRIPT"
    exit 1
fi
