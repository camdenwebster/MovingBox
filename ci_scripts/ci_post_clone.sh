#!/bin/bash
set -e

# JWT Secret Configuration Script for Xcode Cloud
# This script generates the Base.xcconfig file with JWT secret

# -------------------------------------------------------------------------
# Configuration
# -------------------------------------------------------------------------

# Define paths relative to the project root
PROJECT_ROOT="$(dirname "$0")/.."
CONFIG_DIR="$PROJECT_ROOT/MovingBox/Configuration"
OUTPUT_FILE="$CONFIG_DIR/Base.xcconfig"
TEMPLATE_FILE="$CONFIG_DIR/Base.template.xcconfig"

# -------------------------------------------------------------------------
# Main Script
# -------------------------------------------------------------------------

echo "========================================================"
echo "  JWT Secret Configuration for Xcode Cloud"
echo "========================================================"

# Create Configuration directory if it doesn't exist
if [ ! -d "$CONFIG_DIR" ]; then
    echo "Creating configuration directory..."
    mkdir -p "$CONFIG_DIR"
fi

# Check if JWT_SECRET environment variable is set in Xcode Cloud
if [ -z "$JWT_SECRET" ]; then
    echo "Warning: JWT_SECRET environment variable is not set."
    echo "Using placeholder value for development purposes."
    JWT_SECRET="development-placeholder-jwt-secret"
fi

# Create the Base.xcconfig file from template if it exists
if [ -f "$TEMPLATE_FILE" ]; then
    echo "Generating $OUTPUT_FILE from template..."
    cp "$TEMPLATE_FILE" "$OUTPUT_FILE"
    
    # CHANGE: Use different delimiter and escape special characters in JWT_SECRET
    escaped_secret=$(printf '%s\n' "$JWT_SECRET" | sed 's/[\/&]/\\&/g')
    sed -i.bak "s/\$(JWT_SECRET)/${escaped_secret}/g" "$OUTPUT_FILE"
    rm -f "$OUTPUT_FILE.bak"
else
    # Create the file directly if template doesn't exist
    echo "ERROR: No template found at $TEMPLATE_FILE"
    exit 1
fi

echo "Base.xcconfig successfully generated."
# Extract and display marketing version
MARKETING_VERSION=$(grep "MARKETING_VERSION" "$OUTPUT_FILE" | cut -d "=" -f2 | tr -d ' ')
echo "Marketing version: $MARKETING_VERSION"
echo "========================================================"

# Add preview of JWT_SECRET (first 5 characters)
SECRET_PREVIEW=$(grep "JWT_SECRET" "$OUTPUT_FILE" | cut -d "=" -f2 | tr -d ' ' | cut -c1-5)
echo "JWT_SECRET preview (first 5 chars): ${SECRET_PREVIEW}..."
echo "========================================================"

# Add preview of REVENUE_CAT_API_KEY (first 5 characters)
RC_API_KEY_PREVIEW=$(grep "REVENUE_CAT_API_KEY" "$OUTPUT_FILE" | cut -d "=" -f2 | tr -d ' ' | cut -c1-5)
echo "REVENUE_CAT_API_KEY preview (first 5 chars): ${RC_API_KEY_PREVIEW}..."
echo "========================================================"
