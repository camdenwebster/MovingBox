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

# Check if TELEMETRY_DECK_APP_ID environment variable is set in Xcode Cloud
if [ -z "$TELEMETRY_DECK_APP_ID" ]; then
    echo "Warning: TELEMETRY_DECK_APP_ID environment variable is not set."
    echo "Using placeholder value for development purposes."
    TELEMETRY_DECK_APP_ID="development-placeholder-td-app-id"
fi

# Check if REVENUE_CAT_API_KEY environment variable is set in Xcode Cloud
if [ -z "$REVENUE_CAT_API_KEY" ]; then
    echo "Warning: REVENUE_CAT_API_KEY environment variable is not set."
    echo "Using placeholder value for development purposes."
    REVENUE_CAT_API_KEY="development-placeholder-revenuecat-api-key"
fi

# Check if SENTRY_DSN environment variable is set in Xcode Cloud
if [ -z "$SENTRY_DSN" ]; then
    echo "Warning: SENTRY_DSN environment variable is not set."
    echo "Using placeholder value for development purposes."
    SENTRY_DSN="development-placeholder-sentry-dsn"
fi

# Check if WISHKIT_API_KEY environment variable is set in Xcode Cloud
if [ -z "$WISHKIT_API_KEY" ]; then
    echo "Warning: WISHKIT_API_KEY environment variable is not set."
    echo "Using placeholder value for development purposes."
    WISHKIT_API_KEY="development-placeholder-wishkit-api-key"
fi

# Check if AIPROXY_DEVICE_CHECK_BYPASS environment variable is set in Xcode Cloud
if [ -z "$AIPROXY_DEVICE_CHECK_BYPASS" ]; then
    echo "Warning: AIPROXY_DEVICE_CHECK_BYPASS environment variable is not set."
    echo "Using placeholder value for development purposes."
    AIPROXY_DEVICE_CHECK_BYPASS="development-placeholder-aiproxy-bypass"
fi

# Set version suffix for PR builds (semver pre-release format)
if [ -n "$CI_PULL_REQUEST_NUMBER" ]; then
    echo "PR build detected: #$CI_PULL_REQUEST_NUMBER"
    CI_VERSION_SUFFIX="-pr.$CI_PULL_REQUEST_NUMBER"
else
    echo "Non-PR build detected"
    CI_VERSION_SUFFIX=""
fi
export CI_VERSION_SUFFIX

# Create the Base.xcconfig file from template if it exists
if [ -f "$TEMPLATE_FILE" ]; then
    echo "Generating $OUTPUT_FILE from template..."
    cp "$TEMPLATE_FILE" "$OUTPUT_FILE"

    # Escape special characters for sed replacement
    escaped_jwt_secret=$(printf '%s\n' "$JWT_SECRET" | sed 's/[\/&]/\\&/g')
    escaped_telemetry_deck=$(printf '%s\n' "$TELEMETRY_DECK_APP_ID" | sed 's/[\/&]/\\&/g')
    escaped_revenue_cat=$(printf '%s\n' "$REVENUE_CAT_API_KEY" | sed 's/[\/&]/\\&/g')
    escaped_sentry_dsn=$(printf '%s\n' "$SENTRY_DSN" | sed 's/[\/&]/\\&/g')
    escaped_wishkit=$(printf '%s\n' "$WISHKIT_API_KEY" | sed 's/[\/&]/\\&/g')
    escaped_aiproxy=$(printf '%s\n' "$AIPROXY_DEVICE_CHECK_BYPASS" | sed 's/[\/&]/\\&/g')

    # Replace all environment variables in the xcconfig file
    sed -i.bak "s/\$(JWT_SECRET)/${escaped_jwt_secret}/g" "$OUTPUT_FILE"
    sed -i.bak "s/\$(TELEMETRY_DECK_APP_ID)/${escaped_telemetry_deck}/g" "$OUTPUT_FILE"
    sed -i.bak "s/\$(REVENUE_CAT_API_KEY)/${escaped_revenue_cat}/g" "$OUTPUT_FILE"
    sed -i.bak "s/\$(SENTRY_DSN)/${escaped_sentry_dsn}/g" "$OUTPUT_FILE"
    sed -i.bak "s/\$(WISHKIT_API_KEY)/${escaped_wishkit}/g" "$OUTPUT_FILE"
    sed -i.bak "s/\$(AIPROXY_DEVICE_CHECK_BYPASS)/${escaped_aiproxy}/g" "$OUTPUT_FILE"
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

# Add preview of TELEMETRY_DECK_APP_ID (first 5 characters)
TELEMETRY_DECK_APP_ID_PREVIEW=$(grep "TELEMETRY_DECK_APP_ID" "$OUTPUT_FILE" | cut -d "=" -f2 | tr -d ' ' | cut -c1-5)
echo "TELEMETRY_DECK_APP_ID preview (first 5 chars): ${TELEMETRY_DECK_APP_ID_PREVIEW}..."
echo "========================================================"

# Add preview of SENTRY_DSN (first 5 characters)
SENTRY_DSN_PREVIEW=$(grep "SENTRY_DSN" "$OUTPUT_FILE" | cut -d "=" -f2 | tr -d ' ' | cut -c1-5)
echo "SENTRY_DSN preview (first 5 chars): ${SENTRY_DSN_PREVIEW}..."
echo "========================================================"

# Add preview of WISHKIT_API_KEY (first 5 characters)
WISHKIT_API_KEY_PREVIEW=$(grep "WISHKIT_API_KEY" "$OUTPUT_FILE" | cut -d "=" -f2 | tr -d ' ' | cut -c1-5)
echo "WISHKIT_API_KEY preview (first 5 chars): ${WISHKIT_API_KEY_PREVIEW}..."
echo "========================================================"

# Add preview of AIPROXY_DEVICE_CHECK_BYPASS (first 5 characters)
AIPROXY_BYPASS_PREVIEW=$(grep "AIPROXY_DEVICE_CHECK_BYPASS" "$OUTPUT_FILE" | cut -d "=" -f2 | tr -d ' ' | cut -c1-5)
echo "AIPROXY_DEVICE_CHECK_BYPASS preview (first 5 chars): ${AIPROXY_BYPASS_PREVIEW}..."
echo "========================================================"

echo "Disabling plugin and macro validation"
defaults write com.apple.dt.Xcode IDESkipPackagePluginFingerprintValidatation -bool YES
defaults write com.apple.dt.Xcode IDESkipMacroFingerprintValidation -bool YES

