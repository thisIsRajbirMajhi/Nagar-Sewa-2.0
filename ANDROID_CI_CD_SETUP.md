# Android CI/CD Setup Guide

## Overview

This CI/CD pipeline automatically builds, tests, and releases Android APKs whenever you push to the main branch.

## What's Included

- ✓ Automated code analysis and formatting checks
- ✓ Test execution with coverage reports
- ✓ Debug and Release APK builds
- ✓ Android App Bundle (AAB) generation for Google Play
- ✓ Code shrinking and obfuscation with ProGuard
- ✓ Automatic GitHub releases with changelogs
- ✓ APK signing with release keystore
- ✓ Artifact storage (7-30 days)

## Setup Steps

### 1. Generate Android Signing Keystore

Create a keystore for signing release APKs:

```bash
# Navigate to project root
chmod +x scripts/generate-keystore.sh
./scripts/generate-keystore.sh android/app/keystore.jks your_keystore_password nagar-sewa your_key_password
```

This creates:
- `android/app/keystore.jks` - Your signing keystore (keep secure!)
- Store the passwords somewhere safe

### 2. Encode Keystore for GitHub Secrets

```bash
cat android/app/keystore.jks | base64 -w 0 > keystore.b64
```

### 3. Add GitHub Secrets

Go to: **Settings → Secrets and variables → Actions**

Add these secrets:

**Android Signing:**
- `ANDROID_SIGNING_KEY_BASE64` - Content of `keystore.b64`
- `ANDROID_KEYSTORE_PASSWORD` - Your keystore password
- `ANDROID_KEY_ALIAS` - Key alias (usually: `nagar-sewa`)
- `ANDROID_KEY_PASSWORD` - Your key password

**API Keys:**
- `SUPABASE_URL` - Your Supabase project URL
- `SUPABASE_ANON_KEY` - Your Supabase anon key
- `GOOGLE_MAPS_API_KEY` - Google Maps API key
- `GOOGLE_CLOUD_API_KEY` - Google Cloud API key
- `GEMINI_API_KEY` - Gemini API key

Or use the automated script:

```bash
chmod +x scripts/setup-github-secrets.sh
./scripts/setup-github-secrets.sh
```

### 4. Update .gitignore

Ensure these are in your `.gitignore`:

```
android/app/keystore.jks
android/signing.properties
keystore.b64
```

## Build Triggers

The workflow runs automatically on:

- ✓ Push to `main` branch → Creates GitHub release
- ✓ Push to `develop` branch → Build only (no release)
- ✓ Pull requests to `main`/`develop` → Debug build + tests
- ✓ Manual trigger → Workflow dispatch

## Workflow Steps

### For Pull Requests and Non-Main Branches

1. Code analysis and formatting checks
2. Run unit tests with coverage
3. Build debug APK
4. Upload APK to artifacts (7 days)

### For Main Branch Pushes

1. Code analysis and formatting checks
2. Run unit tests with coverage
3. Build debug APK
4. Build release APK (signed)
5. Build AAB (for Google Play)
6. Create GitHub release with APK + AAB
7. Generate changelog from commits

## Build Outputs

### Artifacts

After a successful build:

- **APK Debug** - Available for 7 days
- **APK Release** - Available for 30 days
- **AAB Release** - Available for 30 days

Download from: **Actions → Latest Workflow → Artifacts**

### GitHub Releases

Automatic releases created on main branch pushes:

```
https://github.com/YOUR_ORG/nagar-sewa/releases
```

Each release includes:
- Signed APK (ready to install)
- AAB (ready for Google Play Store)
- Changelog from commits
- Build metadata (version, size, date)

## Installation from Artifacts

### Debug APK

```bash
# Download from artifacts
adb install -r app-debug.apk
```

### Release APK

```bash
# Download from releases
adb install -r app-release.apk
```

## Google Play Store Deployment

1. Go to [Google Play Console](https://play.google.com/console)
2. Create a new app
3. Navigate to **Release → Production**
4. Upload the `app-release.aab` from GitHub releases
5. Add release notes and review

## Local Building

For local testing without GitHub:

```bash
# Debug build
chmod +x scripts/build-apk.sh
./scripts/build-apk.sh debug

# Release build (requires keystore)
./scripts/build-apk.sh release
```

## ProGuard Configuration

Release builds include code shrinking and obfuscation to:
- Reduce APK size
- Protect code from reverse engineering
- Remove unused code and resources

See `android/app/proguard-rules.pro` for customization.

## Troubleshooting

### Build Fails with Signing Error

**Problem**: "Keystore was tampered with or password was incorrect"

**Solution**:
1. Verify `ANDROID_KEYSTORE_PASSWORD` is correct
2. Re-encode keystore: `cat android/app/keystore.jks | base64 -w 0 > keystore.b64`
3. Update `ANDROID_SIGNING_KEY_BASE64` secret

### Tests Fail

**Solution**:
1. Check test output in workflow logs
2. Run locally: `flutter test`
3. Fix issues and push again

### APK Not Created

**Problem**: "No APK found"

**Solution**:
1. Check workflow logs for build errors
2. Verify Flutter dependencies: `flutter pub get`
3. Check Java version (should be 21)

### Release Not Created

**Problem**: Workflow runs but no release appears

**Solution**:
1. Ensure push is to `main` branch
2. Check if build job succeeded
3. Verify `GITHUB_TOKEN` has write permissions

## Monitoring

View workflow status:

```
https://github.com/YOUR_ORG/nagar-sewa/actions
```

Enable notifications:
- Settings → Notifications → Actions

## Security Best Practices

- ✓ Never commit `android/app/keystore.jks` to git
- ✓ Rotate signing key periodically
- ✓ Use strong passwords for keystore and key
- ✓ Review access to GitHub Secrets
- ✓ Audit workflow logs for sensitive data
- ✓ Store keystore backup in secure location

## Environment Variables

The workflow automatically injects these into builds:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `GOOGLE_MAPS_API_KEY`
- `GOOGLE_CLOUD_API_KEY`
- `GEMINI_API_KEY`
- `DEFAULT_LANGUAGE=hi`

Customize in `.github/workflows/build-release.yml` under `Create .env file` step.

## Next Steps

1. Generate keystore: `./scripts/generate-keystore.sh`
2. Set up GitHub secrets: `./scripts/setup-github-secrets.sh`
3. Push to main branch to trigger first build
4. Monitor workflow at `/actions`
5. Download APK from releases or artifacts

