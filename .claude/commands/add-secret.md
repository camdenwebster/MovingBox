# Add Secret to Project

Add a new secret/API key to the MovingBox project configuration: $ARGUMENTS

## Overview

This skill guides you through adding a new secret (API key, token, etc.) to the MovingBox project. Secrets are:
- Stored in `~/.movingbox_env` (local development, git-ignored)
- Generated into `Base.xcconfig` by the CI script
- Referenced in `Info.plist` for runtime access
- Available in both local development and CI/CD (Xcode Cloud)

## Process

Follow these steps in order to add a new secret:

### 1. Add to Environment File (~/.movingbox_env)

Add the secret to the user's environment file:

```bash
# In ~/.movingbox_env
export NEW_SECRET_NAME="your-secret-value-here"
```

**Naming Convention:**
- Use `SCREAMING_SNAKE_CASE`
- Be descriptive and specific (e.g., `OPENAI_API_KEY`, not `API_KEY`)
- Follow existing patterns in the file

### 2. Update Base.template.xcconfig

Add the secret placeholder to the template file at `MovingBox/Configuration/Base.template.xcconfig`:

```xcconfig
// Description of what this secret is for
NEW_SECRET_NAME = $(NEW_SECRET_NAME)
```

**Important:**
- Add a descriptive comment above the line
- Place it in a logical section (group related secrets together)
- The placeholder `$(NEW_SECRET_NAME)` will be replaced by the CI script

### 3. Update CI Script (ci_scripts/ci_post_clone.sh)

Add three sections to the CI script:

#### a. Add environment variable check (around line 32-70):
```bash
# Check if NEW_SECRET_NAME environment variable is set in Xcode Cloud
if [ -z "$NEW_SECRET_NAME" ]; then
    echo "Warning: NEW_SECRET_NAME environment variable is not set."
    echo "Using placeholder value for development purposes."
    NEW_SECRET_NAME="development-placeholder-new-secret"
fi
```

#### b. Add escaping and sed replacement (around line 88-103):
```bash
# In the escaping section:
escaped_new_secret=$(printf '%s\n' "$NEW_SECRET_NAME" | sed 's/[\/&]/\\&/g')

# In the sed replacement section:
sed -i.bak "s/\$(NEW_SECRET_NAME)/${escaped_new_secret}/g" "$OUTPUT_FILE"
```

#### c. Add preview output (around line 131-144):
```bash
# Add preview of NEW_SECRET_NAME (first 5 characters)
NEW_SECRET_PREVIEW=$(grep "NEW_SECRET_NAME" "$OUTPUT_FILE" | cut -d "=" -f2 | tr -d ' ' | cut -c1-5)
echo "NEW_SECRET_NAME preview (first 5 chars): ${NEW_SECRET_PREVIEW}..."
echo "========================================================"
```

### 4. Update Info.plist (if needed for runtime access)

If the secret needs to be accessible at runtime (via `Bundle.main.infoDictionary`), add it to `MovingBox/Info.plist`:

```xml
<key>NEW_SECRET_NAME</key>
<string>$(NEW_SECRET_NAME)</string>
```

**When to add to Info.plist:**
- ✅ SDK initialization (API keys for third-party services)
- ✅ Runtime configuration (feature flags, endpoints)
- ❌ Build-time only configs (doesn't need runtime access)
- ❌ Swift Package Manager configurations (use xcconfig directly)

### 5. Test the Configuration

Test that the secret is properly configured:

```bash
# Run the CI script
source ~/.movingbox_env && bash ci_scripts/ci_post_clone.sh

# Verify the secret appears in Base.xcconfig
grep "NEW_SECRET_NAME" MovingBox/Configuration/Base.xcconfig

# If added to Info.plist, verify it's there
grep "NEW_SECRET_NAME" MovingBox/Info.plist
```

### 6. Access the Secret in Code

#### From Info.plist:
```swift
if let secret = Bundle.main.infoDictionary?["NEW_SECRET_NAME"] as? String {
    // Use the secret
    print("Secret loaded: \(secret)")
}
```

#### From Build Settings (if needed in Swift Package):
Create a generated Swift file that reads from build settings (see existing patterns in the codebase).

### 7. Document in Xcode Cloud (for CI/CD)

When setting up Xcode Cloud, add the secret as an environment variable:
1. Go to Xcode Cloud settings
2. Add environment variable: `NEW_SECRET_NAME` = `actual-value`
3. Mark as "Secret" to prevent logging

## Checklist

When adding a new secret, ensure you've completed:

- [ ] Added to `~/.movingbox_env` with descriptive name
- [ ] Added to `Base.template.xcconfig` with comment
- [ ] Added environment check to CI script (with placeholder fallback)
- [ ] Added escaping logic to CI script
- [ ] Added sed replacement to CI script
- [ ] Added preview output to CI script
- [ ] (Optional) Added to `Info.plist` if needed at runtime
- [ ] Tested locally with `source ~/.movingbox_env && bash ci_scripts/ci_post_clone.sh`
- [ ] Verified secret appears correctly in generated `Base.xcconfig`
- [ ] (If applicable) Documented in Xcode Cloud environment variables

## Example: Adding Stripe API Key

**User Request:** "Add Stripe API key to the project"

**Implementation:**

1. **~/.movingbox_env:**
```bash
export STRIPE_PUBLISHABLE_KEY="pk_test_51H..."
```

2. **Base.template.xcconfig:**
```xcconfig
// Stripe publishable key for payment processing
STRIPE_PUBLISHABLE_KEY = $(STRIPE_PUBLISHABLE_KEY)
```

3. **ci_post_clone.sh (check section):**
```bash
if [ -z "$STRIPE_PUBLISHABLE_KEY" ]; then
    echo "Warning: STRIPE_PUBLISHABLE_KEY environment variable is not set."
    echo "Using placeholder value for development purposes."
    STRIPE_PUBLISHABLE_KEY="development-placeholder-stripe-key"
fi
```

4. **ci_post_clone.sh (escaping section):**
```bash
escaped_stripe=$(printf '%s\n' "$STRIPE_PUBLISHABLE_KEY" | sed 's/[\/&]/\\&/g')
```

5. **ci_post_clone.sh (replacement section):**
```bash
sed -i.bak "s/\$(STRIPE_PUBLISHABLE_KEY)/${escaped_stripe}/g" "$OUTPUT_FILE"
```

6. **ci_post_clone.sh (preview section):**
```bash
STRIPE_KEY_PREVIEW=$(grep "STRIPE_PUBLISHABLE_KEY" "$OUTPUT_FILE" | cut -d "=" -f2 | tr -d ' ' | cut -c1-5)
echo "STRIPE_PUBLISHABLE_KEY preview (first 5 chars): ${STRIPE_KEY_PREVIEW}..."
echo "========================================================"
```

7. **Info.plist:**
```xml
<key>STRIPE_PUBLISHABLE_KEY</key>
<string>$(STRIPE_PUBLISHABLE_KEY)</string>
```

8. **Swift code:**
```swift
guard let stripeKey = Bundle.main.infoDictionary?["STRIPE_PUBLISHABLE_KEY"] as? String else {
    fatalError("STRIPE_PUBLISHABLE_KEY not configured")
}
StripeAPI.defaultPublishableKey = stripeKey
```

## Security Notes

- ✅ Never commit actual secret values to git
- ✅ Always use placeholders in Base.template.xcconfig
- ✅ Base.xcconfig is in .gitignore (generated file)
- ✅ ~/.movingbox_env should have secure permissions (chmod 600)
- ✅ Mark secrets as "Secret" in Xcode Cloud to prevent logging
- ❌ Don't hardcode secrets in Swift code
- ❌ Don't commit Base.xcconfig (it contains real secrets)

## Troubleshooting

**Secret not appearing in Base.xcconfig:**
- Verify environment file is sourced: `echo $NEW_SECRET_NAME`
- Check CI script for typos in variable name
- Ensure sed replacement matches the exact placeholder format

**Secret showing as $(VARIABLE_NAME) at runtime:**
- Verify Base.xcconfig is included in build settings
- Check that Info.plist uses the exact variable name
- Rebuild project to pick up xcconfig changes

**CI script fails with "bad flag in substitute":**
- Ensure special characters are escaped in the sed escaping section
- Check that the escaped variable is used in sed (not the raw variable)

## Related Files

- `~/.movingbox_env` - Local environment variables
- `MovingBox/Configuration/Base.template.xcconfig` - Secret placeholders
- `MovingBox/Configuration/Base.xcconfig` - Generated config (git-ignored)
- `ci_scripts/ci_post_clone.sh` - Secret injection script
- `MovingBox/Info.plist` - Runtime secret access
- `.claude/settings.json` - SessionStart hook configuration
