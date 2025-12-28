# Android Build Quick Reference

Quick reference guide for building and signing Android releases for Dual Reader 3.1.

## Quick Start

### First-Time Setup

```powershell
# 1. Generate keystore (for Play Store releases)
.\scripts\generate_keystore.ps1

# 2. Configure signing (edit android/key.properties)
# Copy from android/key.properties.template

# 3. Verify configuration
.\scripts\verify_android_build.ps1
```

### Build Commands

```powershell
# Build APK (universal - all architectures)
.\scripts\build_apk.ps1

# Build APK (split - per architecture, smaller files)
.\scripts\build_apk.ps1 -Split

# Build AAB (for Play Store)
.\scripts\build_aab.ps1

# Build both APK and AAB
.\scripts\build_android.ps1 -Type Both
```

### Version Management

```powershell
# Show current version
.\scripts\version_manager.ps1

# Bump patch version (3.1.0 -> 3.1.1)
.\scripts\version_manager.ps1 -Bump Patch

# Bump minor version (3.1.0 -> 3.2.0)
.\scripts\version_manager.ps1 -Bump Minor

# Bump major version (3.1.0 -> 4.0.0)
.\scripts\version_manager.ps1 -Bump Major

# Set build number
.\scripts\version_manager.ps1 -Build 10
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

**File**: `android/key.properties`

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

This checks:
- ✅ Flutter installation
- ✅ Signing configuration
- ✅ Version management
- ✅ Build scripts
- ✅ Security settings

## Documentation

For detailed documentation, see:
- **Complete Guide**: `docs/ANDROID_BUILD_COMPLETE_GUIDE.md`
- **Acceptance Verification**: `ANDROID_BUILD_AND_SIGNING_ACCEPTANCE.md`
