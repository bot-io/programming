# Android Build Quick Reference

Quick reference guide for building and signing Android releases.

## Quick Start

### 1. First-Time Setup

```powershell
# Generate keystore
.\scripts\generate_keystore.ps1

# Configure signing (edit android/key.properties)
# Copy from android/key.properties.template
```

### 2. Build for Play Store (AAB)

```powershell
.\scripts\build_aab.ps1
```

**Output:** `build/app/outputs/bundle/release/app-release.aab`

### 3. Build for Direct Install (APK)

```powershell
# Universal APK
.\scripts\build_apk.ps1

# Split APKs (smaller files)
.\scripts\build_apk.ps1 -Split
```

**Output:** `build/app/outputs/flutter-apk/app-release.apk`

## Version Management

```powershell
# Show current version
.\scripts\version_manager.ps1

# Bump version
.\scripts\version_manager.ps1 -Bump Patch   # 3.1.0 -> 3.1.1
.\scripts\version_manager.ps1 -Bump Minor   # 3.1.0 -> 3.2.0
.\scripts\version_manager.ps1 -Bump Major   # 3.1.0 -> 4.0.0

# Set build number
.\scripts\version_manager.ps1 -Build 42
```

## File Locations

| File Type | Location |
|-----------|----------|
| **AAB** (Play Store) | `build/app/outputs/bundle/release/app-release.aab` |
| **APK** (Universal) | `build/app/outputs/flutter-apk/app-release.apk` |
| **APK** (Split) | `build/app/outputs/flutter-apk/app-*-release.apk` |
| **Keystore** | `upload-keystore.jks` (project root) |
| **Signing Config** | `android/key.properties` (not in git) |

## Signing Configuration

**File:** `android/key.properties`

```properties
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFile=../upload-keystore.jks
```

⚠️ **Never commit this file to git!**

## Common Commands

```powershell
# Clean build
flutter clean

# Get dependencies
flutter pub get

# Build AAB
flutter build appbundle --release

# Build APK (universal)
flutter build apk --release

# Build APK (split)
flutter build apk --release --split-per-abi

# Install APK
adb install build/app/outputs/flutter-apk/app-release.apk
```

## Troubleshooting

### Missing key.properties
- Build will use debug signing (not for Play Store)
- Create `android/key.properties` from template

### Wrong password
- Verify passwords in `key.properties`
- Test keystore: `keytool -list -v -keystore upload-keystore.jks`

### Version code error
- Increment version code: `.\scripts\version_manager.ps1 -Build <number>`
- Version code must be higher than previous release

## Verification

Verify your build configuration:

```powershell
.\scripts\verify_android_build.ps1
```

This will check:
- Flutter installation
- Signing configuration
- Version management
- Build scripts
- Security settings

## Documentation

For detailed documentation, see:
- **Complete Guide**: [docs/ANDROID_BUILD_COMPLETE_GUIDE.md](../docs/ANDROID_BUILD_COMPLETE_GUIDE.md)
- **Summary**: [docs/ANDROID_BUILD_AND_SIGNING.md](../docs/ANDROID_BUILD_AND_SIGNING.md)
- **Acceptance Verification**: [ANDROID_BUILD_ACCEPTANCE_VERIFICATION.md](../ANDROID_BUILD_ACCEPTANCE_VERIFICATION.md)
