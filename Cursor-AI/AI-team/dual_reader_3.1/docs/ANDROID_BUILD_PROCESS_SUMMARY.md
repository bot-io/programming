# Android Build Process Summary

## Overview

This document provides a concise summary of the Android build and signing process for Dual Reader 3.1. For detailed instructions, see the [Complete Guide](ANDROID_BUILD_COMPLETE_GUIDE.md).

## Quick Start

### 1. Initial Setup (One-Time)

```powershell
# Generate keystore for signing
.\scripts\generate_keystore.ps1

# Configure signing (edit android/key.properties)
# Copy from android/key.properties.template and fill in details
```

### 2. Build APK (Direct Installation)

```powershell
# Universal APK (all architectures)
.\scripts\build_apk.ps1

# Split APKs (smaller files per architecture)
.\scripts\build_apk.ps1 -Split
```

**Output**: `build/app/outputs/flutter-apk/app-release.apk`

### 3. Build AAB (Play Store)

```powershell
.\scripts\build_aab.ps1
```

**Output**: `build/app/outputs/bundle/release/app-release.aab`

## Build Configuration

### APK Configuration

- **Universal APK**: Single file with all architectures (~80-100MB)
- **Split APKs**: Separate files per architecture (~30-40MB each)
  - `app-arm64-v8a-release.apk` (64-bit ARM)
  - `app-armeabi-v7a-release.apk` (32-bit ARM)
  - `app-x86_64-release.apk` (64-bit x86)

**Configuration**: `android/app/build.gradle` (lines 208-216)

### AAB Configuration

- **App Bundle**: Optimized format for Play Store (~40-60MB)
- **ABI Splitting**: Enabled (Google generates device-specific APKs)
- **Language/Density Splitting**: Disabled (all included)

**Configuration**: `android/app/build.gradle` (lines 192-206)

## Signing Configuration

### Keystore Setup

1. **Generate Keystore**:
   ```powershell
   .\scripts\generate_keystore.ps1
   ```

2. **Configure Signing**:
   - Copy `android/key.properties.template` to `android/key.properties`
   - Fill in keystore details:
     ```properties
     storePassword=YOUR_STORE_PASSWORD
     keyPassword=YOUR_KEY_PASSWORD
     keyAlias=upload
     storeFile=../upload-keystore.jks
     ```

3. **Verify**:
   ```powershell
   .\scripts\verify_android_build.ps1
   ```

### Signing Behavior

- **With keystore**: Release builds are signed with release keystore
- **Without keystore**: Release builds use debug signing (not for Play Store)
- **Debug builds**: Always use debug signing

**Configuration**: `android/app/build.gradle` (lines 90-155)

## Version Management

### Version Format

Version is managed in `pubspec.yaml`:
```yaml
version: 3.1.0+1  # versionName+versionCode
```

- **Version Name** (`3.1.0`): User-visible version (x.y.z)
- **Version Code** (`1`): Build number (must increment for each release)

### Version Commands

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
.\scripts\version_manager.ps1 -Build 42
```

**Configuration**: `android/app/build.gradle` (lines 24-58)

## Build Scripts

| Script | Purpose | Usage |
|--------|---------|-------|
| `build_apk.ps1` | Build APK | `.\scripts\build_apk.ps1 [-Split]` |
| `build_aab.ps1` | Build AAB | `.\scripts\build_aab.ps1` |
| `build_android.ps1` | Master script | `.\scripts\build_android.ps1 -Type APK\|AAB\|Both` |
| `generate_keystore.ps1` | Generate keystore | `.\scripts\generate_keystore.ps1` |
| `version_manager.ps1` | Manage versions | `.\scripts\version_manager.ps1 [-Bump\|-Build\|-Set]` |
| `verify_android_build.ps1` | Verify config | `.\scripts\verify_android_build.ps1` |

## Build Outputs

### APK Outputs

- **Universal**: `build/app/outputs/flutter-apk/app-release.apk`
- **Split**: `build/app/outputs/flutter-apk/app-*-release.apk`

### AAB Output

- **Bundle**: `build/app/outputs/bundle/release/app-release.aab`

## Build Types

### Debug Build

- **Signing**: Debug signing
- **Optimization**: Disabled
- **Obfuscation**: Disabled
- **App ID**: `com.dualreader.app.debug`
- **Version**: `3.1.0-debug`

**Configuration**: `android/app/build.gradle` (lines 136-144)

### Release Build

- **Signing**: Release keystore (if configured)
- **Optimization**: Enabled (minify, shrink resources)
- **Obfuscation**: Enabled (ProGuard)
- **App ID**: `com.dualreader.app`
- **Version**: `3.1.0`

**Configuration**: `android/app/build.gradle` (lines 145-155)

## Build Process Flow

```
1. Verify Flutter Installation
   ↓
2. Check Signing Configuration
   ↓
3. Clean Previous Builds
   ↓
4. Get Dependencies (flutter pub get)
   ↓
5. Extract Version from pubspec.yaml
   ↓
6. Build APK/AAB
   ↓
7. Sign with Release Keystore (if configured)
   ↓
8. Output to build/ directory
```

## Common Commands

### Build Commands

```powershell
# Build universal APK
flutter build apk --release

# Build split APKs
flutter build apk --release --split-per-abi

# Build AAB
flutter build appbundle --release

# Clean build
flutter clean
```

### Verification Commands

```powershell
# Verify build configuration
.\scripts\verify_android_build.ps1

# Check Flutter version
flutter --version

# Check Java/keytool
keytool -help
```

### Installation Commands

```powershell
# Install APK on connected device
adb install build/app/outputs/flutter-apk/app-release.apk

# Install split APK (64-bit ARM)
adb install build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

## Troubleshooting

### Common Issues

1. **Missing keystore**:
   - Run `.\scripts\generate_keystore.ps1`
   - Configure `android/key.properties`

2. **Version code error**:
   - Increment build number: `.\scripts\version_manager.ps1 -Build <number>`
   - Version code must be higher than previous release

3. **Build fails**:
   - Run `flutter clean`
   - Run `flutter pub get`
   - Verify Flutter installation: `flutter doctor`

4. **Signing errors**:
   - Verify keystore file exists
   - Check passwords in `key.properties`
   - Test keystore: `keytool -list -v -keystore upload-keystore.jks`

## Security Notes

⚠️ **Never commit to version control**:
- `android/key.properties`
- `*.jks` / `*.keystore` files
- `android/local.properties`

✅ **Already in `.gitignore`**:
- Lines 71-73: `key.properties`, `*.jks`, `*.keystore`

## File Structure

```
project/
├── android/
│   ├── app/
│   │   ├── build.gradle          # Build configuration
│   │   ├── proguard-rules.pro    # ProGuard rules
│   │   └── src/main/
│   │       └── AndroidManifest.xml
│   ├── build.gradle              # Project-level config
│   ├── gradle.properties         # Gradle settings
│   ├── key.properties            # Signing config (not in git)
│   └── key.properties.template   # Signing template
├── scripts/
│   ├── build_apk.ps1            # APK build script
│   ├── build_aab.ps1             # AAB build script
│   ├── generate_keystore.ps1     # Keystore generator
│   ├── version_manager.ps1      # Version manager
│   └── verify_android_build.ps1  # Verification script
├── upload-keystore.jks           # Keystore file (not in git)
└── pubspec.yaml                  # Version source
```

## Production Checklist

Before building for production:

- [ ] Keystore generated and secured
- [ ] `key.properties` configured
- [ ] Version updated in `pubspec.yaml`
- [ ] Build configuration verified: `.\scripts\verify_android_build.ps1`
- [ ] Test build successful
- [ ] APK/AAB file size reasonable
- [ ] Version information correct
- [ ] Signing verified (for AAB)

## Additional Resources

- **Complete Guide**: [docs/ANDROID_BUILD_COMPLETE_GUIDE.md](ANDROID_BUILD_COMPLETE_GUIDE.md)
- **Quick Reference**: [android/README_BUILD.md](../android/README_BUILD.md)
- **Acceptance Verification**: [ANDROID_BUILD_ACCEPTANCE_VERIFICATION.md](../ANDROID_BUILD_ACCEPTANCE_VERIFICATION.md)
- **Flutter Build Docs**: https://docs.flutter.dev/deployment/android
