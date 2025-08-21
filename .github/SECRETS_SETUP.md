# GitHub Actions Secrets Setup Guide

This document outlines the required secrets and environment configuration for the MovingBox CI/CD pipeline.

## Required Secrets

### Development & API Secrets
These secrets are required for all workflows:

| Secret Name | Description | Required For | Example/Format |
|-------------|-------------|--------------|----------------|
| `JWT_SECRET` | JWT secret for OpenAI proxy authentication | All builds | Base64 encoded string |
| `REVENUE_CAT_API_KEY` | RevenueCat API key for subscription management | All builds | `appl_xxxxxxxxxx` |
| `SENTRY_DSN` | Sentry DSN for error tracking | All builds | `https://...@sentry.io/...` |
| `TELEMETRY_DECK_APP_ID` | TelemetryDeck app ID for analytics | All builds | UUID format |

### Apple Team Configuration (Production Only)
These secrets are required for automatic code signing:

| Secret Name | Description | Required For | Format |
|-------------|-------------|--------------|--------|
| `APPLE_TEAM_ID` | Apple Developer Team ID | Release builds | String (e.g., `ABC123DEF4`) |

### App Store Connect API (Production Only)
Required for TestFlight and App Store uploads:

| Secret Name | Description | Required For | Format |
|-------------|-------------|--------------|--------|
| `APP_STORE_CONNECT_API_KEY_ID` | App Store Connect API Key ID | TestFlight/App Store | String (e.g., `2X9R4HXF34`) |
| `APP_STORE_CONNECT_ISSUER_ID` | App Store Connect Issuer ID | TestFlight/App Store | UUID format |
| `APP_STORE_CONNECT_API_PRIVATE_KEY` | App Store Connect Private Key | TestFlight/App Store | Base64 encoded .p8 file |

### Claude Code Integration
Required for intelligent CI/CD features:

| Secret Name | Description | Required For | Format |
|-------------|-------------|--------------|--------|
| `ANTHROPIC_API_KEY` | Claude API key for AI features | Version generation, Release notes | `sk-ant-...` |

## Setup Instructions

### 1. Adding Secrets to GitHub

1. Navigate to your GitHub repository
2. Go to **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Add each secret with the exact name from the tables above

### 2. Development Secrets Setup

#### JWT_SECRET
```bash
# Generate a new JWT secret (or use existing)
openssl rand -base64 32
```

#### API Keys
- **RevenueCat**: Get from RevenueCat dashboard → Apps → [Your App] → API Keys
- **Sentry**: Get from Sentry → Settings → Projects → [Your Project] → Client Keys (DSN)
- **TelemetryDeck**: Get from TelemetryDeck dashboard → Apps → [Your App] → App ID

### 3. Apple Team ID Setup (Production)

#### Find Your Apple Team ID
```bash
# Method 1: From Apple Developer Portal
# Go to https://developer.apple.com/account/#/membership/
# Your Team ID is shown in the membership details

# Method 2: From Xcode
# Open your project in Xcode
# Go to Project Settings → Signing & Capabilities
# Your Team ID is shown next to your team name

# Method 3: From command line (if you have existing certificates)
security find-identity -v -p codesigning | grep "Developer ID\|iPhone Developer\|iPhone Distribution"
# The Team ID is in parentheses in the certificate name
```

### 4. App Store Connect API Setup

1. Go to [App Store Connect](https://appstoreconnect.apple.com/)
2. Navigate to **Users and Access** → **Keys** → **App Store Connect API**
3. Click **Generate API Key**
4. Select **Developer** access (sufficient for CI/CD operations)
5. Download the `.p8` file
6. Note the Key ID and Issuer ID

```bash
# Base64 encode the .p8 file for GitHub secret
base64 -i AuthKey_[KEY_ID].p8 | pbcopy
```

**Important**: The App Store Connect API key handles both authentication and automatic provisioning profile management, eliminating the need for manual certificate and profile management.

### 5. Automatic Code Signing Benefits

Using App Store Connect API for automatic code signing provides several advantages:

- **No Manual Certificate Management**: Xcode automatically downloads and manages certificates
- **Automatic Provisioning Profile Updates**: Profiles are created and updated as needed
- **Team Synchronization**: All team members use the same signing setup
- **Reduced Maintenance**: No need to manually renew and update certificates
- **Enhanced Security**: Certificates are managed by Apple's secure infrastructure
- **Simplified CI/CD**: No complex certificate installation scripts

### 6. Environment-Specific Configuration

#### Repository Environments
Create the following environments in GitHub:
- `development` - For feature branches and PR builds
- `staging` - For main branch builds and TestFlight
- `production` - For release builds and App Store

#### Environment Protection Rules
- **staging**: Require review from team leads
- **production**: Require review from maintainers, restrict to release branches only

### 7. Local Development Setup

For local development, create a `.env` file (not committed to git):

```bash
# .env (local development only)
JWT_SECRET=your_jwt_secret_here
REVENUE_CAT_API_KEY=your_revenue_cat_key
SENTRY_DSN=your_sentry_dsn
TELEMETRY_DECK_APP_ID=your_telemetry_deck_id
```

Update your local `Base.xcconfig` as needed for development.

**Note**: Local development typically uses automatic signing with your personal Apple ID. The CI/CD pipeline uses the team's App Store Connect API for production builds.

## Security Best Practices

### 1. Secret Rotation
- Rotate all secrets quarterly or immediately if compromised
- Update secrets in both GitHub and any local copies
- Test workflows after rotation

### 2. Access Control
- Only repository admins should have access to production secrets
- Use environment protection rules to control deployment access
- Regularly audit secret access logs

### 3. Secret Validation
- All workflows validate required secrets before proceeding
- Workflows fail gracefully if secrets are missing or invalid
- No secrets are ever logged or exposed in build outputs

### 4. Backup and Recovery
- Keep encrypted backups of certificates and keys
- Document the recovery process for certificate expiration
- Maintain alternative signing certificates as backup

## Troubleshooting

### Missing Secrets
```bash
# Check if required secrets are set (will show "***" if present)
# Run this locally to test secret availability
echo "JWT_SECRET: ${JWT_SECRET:+SET}"
echo "REVENUE_CAT_API_KEY: ${REVENUE_CAT_API_KEY:+SET}"
echo "APPLE_TEAM_ID: ${APPLE_TEAM_ID:+SET}"
```

### Automatic Signing Issues
```bash
# Verify your Apple Team ID
security find-identity -v -p codesigning

# Check App Store Connect API connectivity
# (This requires the API key to be properly configured)
fastlane spaceship auth --api_key_id YOUR_KEY_ID --api_key_issuer_id YOUR_ISSUER_ID --api_key_path YOUR_KEY_PATH.p8
```

### App Store Connect API Issues
```bash
# Test API connectivity (replace with your values)
curl -H "Authorization: Bearer $JWT_TOKEN" \
  "https://api.appstoreconnect.apple.com/v1/apps"
```

## Workflow Secret Usage

### Development Builds
- Uses basic app configuration secrets only
- No code signing secrets required (uses automatic signing)
- Safe for PR builds from forks (with limitations)

### Staging Builds (TestFlight)
- Uses all secrets including App Store Connect API
- Requires Apple Team ID for automatic signing
- Protected environment with review requirements

### Production Builds (App Store)
- Uses all secrets including App Store Connect API
- Automatic code signing with distribution certificates
- Highest security environment with strict access controls

## Automation Scripts

### Secret Validation Script
Create a script to validate all required secrets are present:

```bash
#!/bin/bash
# scripts/validate-secrets.sh

REQUIRED_SECRETS=(
  "JWT_SECRET"
  "REVENUE_CAT_API_KEY" 
  "SENTRY_DSN"
  "TELEMETRY_DECK_APP_ID"
)

PRODUCTION_SECRETS=(
  "KEYCHAIN_PASSWORD"
  "CERTIFICATES_P12"
  "CERTIFICATES_PASSWORD"
  "PROVISIONING_PROFILE"
  "APP_STORE_CONNECT_API_KEY_ID"
  "APP_STORE_CONNECT_ISSUER_ID"
  "APP_STORE_CONNECT_API_PRIVATE_KEY"
)

echo "Validating development secrets..."
for secret in "${REQUIRED_SECRETS[@]}"; do
  if [[ -z "${!secret}" ]]; then
    echo "❌ Missing required secret: $secret"
    exit 1
  else
    echo "✅ $secret is set"
  fi
done

if [[ "$1" == "production" ]]; then
  echo "Validating production secrets..."
  for secret in "${PRODUCTION_SECRETS[@]}"; do
    if [[ -z "${!secret}" ]]; then
      echo "❌ Missing production secret: $secret"
      exit 1
    else
      echo "✅ $secret is set"
    fi
  done
fi

echo "🎉 All required secrets are configured"
```

### Certificate Expiration Checker
```bash
#!/bin/bash
# scripts/check-certificate-expiry.sh

if [[ -n "$CERTIFICATES_P12" ]]; then
  # Decode and check certificate expiry
  echo "$CERTIFICATES_P12" | base64 --decode > /tmp/cert.p12
  
  # Extract certificate and check expiry
  openssl pkcs12 -in /tmp/cert.p12 -clcerts -nokeys -passin pass:"$CERTIFICATES_PASSWORD" | \
    openssl x509 -noout -enddate
  
  rm -f /tmp/cert.p12
fi
```

## Migration from Existing Setup

If you have existing CI/CD setup:

1. **Audit Current Secrets**: List all currently used environment variables
2. **Map to New Structure**: Match existing secrets to the new naming convention
3. **Test in Staging**: Validate all workflows work with new secrets
4. **Gradual Migration**: Migrate one environment at a time
5. **Cleanup**: Remove old, unused secrets after successful migration

---

For questions or issues with secrets setup, contact the development team leads or create an issue in the repository.