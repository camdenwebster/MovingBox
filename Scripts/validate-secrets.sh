#!/bin/bash
set -euo pipefail

# validate-secrets.sh
# Validates that all required secrets are available for CI/CD pipelines

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Required secrets for all builds
REQUIRED_SECRETS=(
  "JWT_SECRET"
  "REVENUE_CAT_API_KEY" 
  "SENTRY_DSN"
  "TELEMETRY_DECK_APP_ID"
)

# Additional secrets for production builds
PRODUCTION_SECRETS=(
  "APPLE_TEAM_ID"
  "APP_STORE_CONNECT_API_KEY_ID"
  "APP_STORE_CONNECT_ISSUER_ID"
  "APP_STORE_CONNECT_API_PRIVATE_KEY"
)

# Claude Code integration secrets
CLAUDE_SECRETS=(
  "ANTHROPIC_API_KEY"
)

function check_secret() {
  local secret_name=$1
  local is_optional=${2:-false}
  
  if [[ -n "${!secret_name:-}" ]]; then
    echo -e "${GREEN}✅ $secret_name${NC} is set"
    return 0
  else
    if [[ "$is_optional" == "true" ]]; then
      echo -e "${YELLOW}⚠️  $secret_name${NC} is not set (optional)"
      return 0
    else
      echo -e "${RED}❌ $secret_name${NC} is missing"
      return 1
    fi
  fi
}

function validate_secret_format() {
  local secret_name=$1
  local secret_value="${!secret_name:-}"
  
  case $secret_name in
    "JWT_SECRET")
      if [[ ! "$secret_value" =~ ^[A-Za-z0-9+/=]+$ ]]; then
        echo -e "${YELLOW}⚠️  $secret_name${NC} format may be invalid (should be base64)"
      fi
      ;;
    "REVENUE_CAT_API_KEY")
      if [[ ! "$secret_value" =~ ^appl_[A-Za-z0-9]+$ ]]; then
        echo -e "${YELLOW}⚠️  $secret_name${NC} format may be invalid (should start with 'appl_')"
      fi
      ;;
    "SENTRY_DSN")
      if [[ ! "$secret_value" =~ ^https://.+@.+\.sentry\.io/.+$ ]]; then
        echo -e "${YELLOW}⚠️  $secret_name${NC} format may be invalid (should be Sentry DSN URL)"
      fi
      ;;
    "TELEMETRY_DECK_APP_ID")
      if [[ ! "$secret_value" =~ ^[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}$ ]]; then
        echo -e "${YELLOW}⚠️  $secret_name${NC} format may be invalid (should be UUID)"
      fi
      ;;
    "APPLE_TEAM_ID")
      if [[ ! "$secret_value" =~ ^[A-Z0-9]{10}$ ]]; then
        echo -e "${YELLOW}⚠️  $secret_name${NC} format may be invalid (should be 10 alphanumeric characters)"
      fi
      ;;
    "APP_STORE_CONNECT_API_KEY_ID")
      if [[ ! "$secret_value" =~ ^[A-Z0-9]{10}$ ]]; then
        echo -e "${YELLOW}⚠️  $secret_name${NC} format may be invalid (should be 10 alphanumeric characters)"
      fi
      ;;
    "APP_STORE_CONNECT_ISSUER_ID")
      if [[ ! "$secret_value" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]]; then
        echo -e "${YELLOW}⚠️  $secret_name${NC} format may be invalid (should be UUID)"
      fi
      ;;
    "ANTHROPIC_API_KEY")
      if [[ ! "$secret_value" =~ ^sk-ant-.+$ ]]; then
        echo -e "${YELLOW}⚠️  $secret_name${NC} format may be invalid (should start with 'sk-ant-')"
      fi
      ;;
  esac
}

function main() {
  local build_type=${1:-"development"}
  local exit_code=0
  
  echo "🔐 Validating secrets for $build_type build..."
  echo "============================================="
  echo ""
  
  # Validate required secrets
  echo "📋 Checking required secrets..."
  for secret in "${REQUIRED_SECRETS[@]}"; do
    if ! check_secret "$secret"; then
      exit_code=1
    else
      validate_secret_format "$secret"
    fi
  done
  echo ""
  
  # Validate Claude Code secrets
  echo "🤖 Checking Claude Code integration secrets..."
  for secret in "${CLAUDE_SECRETS[@]}"; do
    check_secret "$secret" "true"  # Claude secrets are optional
    if [[ -n "${!secret:-}" ]]; then
      validate_secret_format "$secret"
    fi
  done
  echo ""
  
  # Validate production secrets if needed
  if [[ "$build_type" == "production" || "$build_type" == "staging" ]]; then
    echo "🏭 Checking production secrets..."
    for secret in "${PRODUCTION_SECRETS[@]}"; do
      if ! check_secret "$secret"; then
        exit_code=1
      fi
    done
    echo ""
    
    # Additional validation for App Store Connect API
    if [[ -n "${APP_STORE_CONNECT_API_PRIVATE_KEY:-}" ]]; then
      echo "🔑 Validating App Store Connect API key..."
      
      # Try to decode the API key
      if echo "$APP_STORE_CONNECT_API_PRIVATE_KEY" | base64 --decode > /tmp/test_api_key.p8 2>/dev/null; then
        # Check if it's a valid P8 key format
        if grep -q "BEGIN PRIVATE KEY" /tmp/test_api_key.p8; then
          echo -e "${GREEN}✅ App Store Connect API key${NC} format is valid"
        else
          echo -e "${YELLOW}⚠️  App Store Connect API key${NC} format may be invalid (should be a .p8 private key)"
        fi
        rm -f /tmp/test_api_key.p8
      else
        echo -e "${RED}❌ App Store Connect API key${NC} is not valid base64 or is corrupted"
        exit_code=1
      fi
    fi
  fi
  
  # Final summary
  echo "============================================="
  if [[ $exit_code -eq 0 ]]; then
    echo -e "${GREEN}🎉 All required secrets are configured correctly!${NC}"
    
    if [[ "$build_type" == "development" ]]; then
      echo ""
      echo "💡 To validate production secrets, run:"
      echo "   ./scripts/validate-secrets.sh production"
    fi
  else
    echo -e "${RED}💥 Secret validation failed!${NC}"
    echo ""
    echo "Please ensure all required secrets are configured in GitHub Actions."
    echo "See .github/SECRETS_SETUP.md for detailed setup instructions."
  fi
  
  exit $exit_code
}

# Help function
function show_help() {
  echo "Usage: $0 [build_type]"
  echo ""
  echo "Arguments:"
  echo "  build_type    Build type to validate (development, staging, production)"
  echo "                Default: development"
  echo ""
  echo "Examples:"
  echo "  $0                    # Validate development secrets"
  echo "  $0 staging           # Validate staging secrets"
  echo "  $0 production        # Validate production secrets"
  echo ""
  echo "Environment variables are expected to be set with the secret values."
}

# Check for help flag
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  show_help
  exit 0
fi

# Run main function
main "${1:-development}"