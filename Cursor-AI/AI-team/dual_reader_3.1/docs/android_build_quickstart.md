# Android Build Quick Start Guide

Quick reference for building Android APK and AAB files.

## Prerequisites Check

```powershell
# Check Flutter
flutter --version

# Check Java (for signing)
keytool -help

# Verify setup
.\scripts\verify_android_build.ps1
```

## First-Time Setup

### 1. Generate Keystore (One-time)

```powershell
.\scripts\generate_keystore.ps1
```

Follow prompts to create `upload-keystore.jks`.

### 2. Configure Signing

```powershell
# Copy template
Copy-Item android\key.properties.template android\key.properties

# Edit android/key.properties and fill in:
# - storePassword (from keystore generation)
# - keyPassword (from keystore generation)
# - keyAlias=upload
# - storeFile=../upload-keystore.jks
```

## Building

### Build APK (Direct Installation)

```powershell
# Universal APK (all architectures)
.\scripts\build_apk.ps1

# Split APKs (per architecture, smaller)
.\scripts\build_apk.ps1 -Split
```

**Output:** `build/app/outputs/flutter-apk/app-release.apk`

### Build AAB (Play Store)

```powershell
.\scripts\build_aab.ps1
```

**Output:** `build/app/outputs/bundle/release/app-release.aab`

### Build Both

```powershell
.\scripts\build_android.ps1 -Type Both
```

## Version Management

```powershell
# Show current version
.\scripts\version_manager.ps1

# Bump patch version (3.1.0 → 3.1.1)
.\scripts\version_manager.ps1 -Bump Patch

# Bump minor version (3.1.0 → 3.2.0)
.\scripts\version_manager.ps1 -Bump Minor

# Bump major version (3.1.0 → 4.0.0)
.\scripts\version_manager.ps1 -Bump Major

# Set build number
.\scripts\version_manager.ps1 -Build 42
```

## Installation

### Install APK via ADB

```bash
adb install build/app/outputs/flutter-apk/app-release.apk
```

### Upload AAB to Play Store

1. Go to [Google Play Console](https://play.google.com/console)
2. Select app → Release → Production
3. Create new release
4. Upload `build/app/outputs/bundle/release/app-release.aab`
5. Submit for review

## Troubleshooting

### "key.properties not found"
→ Run `.\scripts\generate_keystore.ps1` and configure signing

### "Keystore file not found"
→ Check `storeFile` path in `android/key.properties`

### "Version code must be incremented"
→ Run `.\scripts\version_manager.ps1 -Build <next_number>`

### Build fails
→ Run `flutter clean && flutter pub get` and try again

## File Locations

- **APK:** `build/app/outputs/flutter-apk/app-release.apk`
- **AAB:** `build/app/outputs/bundle/release/app-release.aab`
- **Keystore:** `upload-keystore.jks`
- **Config:** `android/key.properties`

## Quick Commands Reference

```powershell
# Verify setup
.\scripts\verify_android_build.ps1

# Generate keystore
.\scripts\generate_keystore.ps1

# Build APK
.\scripts\build_apk.ps1

# Build AAB
.\scripts\build_aab.ps1

# Version management
.\scripts\version_manager.ps1 -Bump Patch
```

For detailed information, see [Android Build Guide](android_build_guide.md).
