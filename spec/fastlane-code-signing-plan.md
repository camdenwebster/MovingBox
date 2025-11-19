# Fastlane Automatic Code Signing with App Store Connect API Key

## Overview

This plan outlines the setup for automatic code signing in Fastlane using `match` for certificate and provisioning profile management, enabling seamless TestFlight/App Store deployment via GitHub Actions.

## Current State

- **Development Team ID**: V7HLP74XY3
- **Bundle ID**: com.mothersound.movingbox
- **Code Sign Style**: Automatic (Xcode-managed)
- **Entitlements**: CloudKit, iCloud services

## Recommended Approach: `match` + App Store Connect API Key

### Why `match` over `sigh`?

| Feature | `match` | `sigh` |
|---------|---------|--------|
| Certificates | Managed | Manual |
| Provisioning Profiles | Managed | Managed |
| Team Support | ✅ Excellent | ⚠️ Limited |
| CI/CD Integration | ✅ Seamless | ⚠️ Complex |
| Cert Storage | Git (encrypted) | Local/manual |
| App Store Workflow | ✅ Industry standard | ⚠️ Not ideal |

## Implementation Plan

### Phase 1: Prerequisites

#### 1.1 Create Private Certificate Repository
- Create private GitHub repository (e.g., `movingbox-certificates`)
- Purpose: Store encrypted certificates and provisioning profiles
- Access: Team members + CI/CD runner

#### 1.2 Generate App Store Connect API Key
- Log in to App Store Connect
- Users & Access → Keys → Create new API key
- Permissions: App Manager (sufficient for TestFlight uploads)
- Download and securely store `.p8` file
- Record: Key ID, Issuer ID, Team ID

#### 1.3 Gather GitHub Token
- Generate Personal Access Token (PAT) with `repo` scope
- Recommended: Use dedicated service account or machine token
- Store securely for CI/CD

### Phase 2: Fastlane Configuration

#### 2.1 Update `fastlane/Appfile`
```ruby
app_identifier("com.mothersound.movingbox")
apple_id("YOUR_APPLE_ID@example.com")
team_id("V7HLP74XY3")
team_name("Your Team Name")
itc_team_id("ITC_TEAM_ID")  # Can differ from team_id
```

#### 2.2 Create `fastlane/Matchfile`
```ruby
git_url("https://github.com/USERNAME/movingbox-certificates.git")
git_branch("main")
storage_mode("git")
type("appstore")  # For App Store/TestFlight distribution
team_id("V7HLP74XY3")
app_identifier(["com.mothersound.movingbox"])
verbose(true)
```

#### 2.3 Update `fastlane/Fastfile`
Add new lanes:
- `setup_ci`: Initialize code signing for CI environment
- `build_release`: Build with signing for TestFlight
- `upload_testflight`: Upload to TestFlight

Example structure:
```ruby
lane :setup_ci do
  match(
    type: "appstore",
    readonly: true,
    git_basic_authorization: ENV["MATCH_GIT_TOKEN"]
  )
end

lane :build_release do
  match(type: "appstore")
  build_app(
    scheme: "MovingBox",
    configuration: "Release",
    export_method: "app-store"
  )
end

lane :upload_testflight do
  upload_to_testflight(
    api_key_path: ENV["APP_STORE_CONNECT_API_KEY_PATH"],
    skip_waiting_for_build_processing: true
  )
end
```

### Phase 3: GitHub Actions Integration

#### 3.1 Add Repository Secrets
```
MATCH_GIT_TOKEN              # GitHub token for certificate repo access
MATCH_GIT_BASIC_AUTHORIZATION  # Base64 encoded: username:token
APP_STORE_CONNECT_API_KEY_PATH  # Path to .p8 file
APP_STORE_CONNECT_API_KEY_ID     # API Key ID
APP_STORE_CONNECT_ISSUER_ID      # Issuer ID (Team ID)
```

#### 3.2 Update `.github/workflows/test-and-build.yml`
Add TestFlight deployment job:
- Depend on `build` job
- Setup code signing with `match`
- Build release binary
- Upload to TestFlight
- Add workflow dispatch trigger for manual deployments

### Phase 4: Local Setup Documentation

Create `FASTLANE_SETUP.md` documenting:

1. **First-time setup**:
   ```bash
   cd fastlane
   fastlane match appstore
   ```

2. **Certificate initialization** (first developer on team)
3. **Syncing certificates** (subsequent developers)
4. **Troubleshooting** common issues (cert expiration, etc.)

## Files to Create/Modify

| File | Action | Purpose |
|------|--------|---------|
| `fastlane/Appfile` | Modify | Add team info and Apple ID |
| `fastlane/Matchfile` | Create | Configure match |
| `fastlane/Fastfile` | Modify | Add release & TestFlight lanes |
| `.github/workflows/test-and-build.yml` | Modify | Add deployment job |
| `.github/workflows/test-and-build.yml` | Modify | Add secrets setup |
| `FASTLANE_SETUP.md` | Create | Local setup guide |

## Security Considerations

- ✅ Certificates stored encrypted in private Git repo
- ✅ App Store Connect API key stored as GitHub Actions secret
- ✅ GitHub token stored as GitHub Actions secret
- ✅ Never commit secrets to main repository
- ✅ Rotate API keys periodically
- ✅ Use readonly `match` in CI for security

## Deployment Workflow

```
1. Push to develop/main
   ↓
2. GitHub Actions triggered
   ↓
3. Unit tests run
   ↓
4. Build for simulator (optional)
   ↓
5. Setup code signing with match
   ↓
6. Build release binary (iOS device)
   ↓
7. Upload to TestFlight
   ↓
8. Notification on success/failure
```

## Timeline & Effort

- **Phase 1 (Prerequisites)**: 15-30 min (mostly in Apple/GitHub dashboards)
- **Phase 2 (Fastlane config)**: 30-45 min
- **Phase 3 (GitHub Actions)**: 20-30 min
- **Phase 4 (Documentation)**: 15-20 min
- **Total**: ~2-3 hours

## Rollback Plan

If issues occur:
1. Switch to Xcode manual signing temporarily
2. Disable TestFlight deployment in CI
3. Investigate cert/profile issues locally
4. Re-run match to refresh certificates

## References

- [Fastlane match documentation](https://docs.fastlane.tools/actions/match/)
- [App Store Connect API documentation](https://developer.apple.com/documentation/appstoreconnect)
- [GitHub Actions security best practices](https://docs.github.com/en/actions/security-guides)

## Next Steps

1. Prepare prerequisites (API keys, tokens, private repo)
2. Implement Phase 2 (Fastlane configuration)
3. Test locally with `fastlane match`
4. Integrate into GitHub Actions workflow
5. Document in `FASTLANE_SETUP.md`
