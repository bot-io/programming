# Android Build and Signing Guide

Complete guide for building and signing Android releases for Dual Reader 3.1.

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Initial Setup](#initial-setup)
4. [Signing Configuration](#signing-configuration)
5. [Version Management](#version-management)
6. [Building APK](#building-apk)
7. [Building AAB](#building-aab)
8. [Verification](#verification)
9. [Troubleshooting](#troubleshooting)
10. [Best Practices](#best-practices)

## Overview

This project supports building Android apps in two formats:

- **APK (Android Package)**: For direct installation on devices
  - Universal APK: Single file with all architectures (larger size)
  - Split APK: Separate files per architecture (smaller downloads)

- **AAB (Android App Bundle)**: For Google Play Store distribution
  - Optimized format where Google generates APKs per device
  - Smaller download sizes for end users
  - Required for Play Store releases

### Build Configuration

The build configuration is located in `android/app/build.gradle` and includes:

- ✅ Version management (reads from `pubspec.yaml`)
- ✅ Signing configuration (reads from `android/key.properties`)
- ✅ ProGuard/R8 code shrinking and obfuscation
- ✅ Multi-architecture support (ARM, x86)
- ✅ Release and debug build types

## Prerequisites

### Required Software

1. **Flutter SDK** (latest stable version)
   ```bash
   flutter --version
   ```

2. **Java JDK** (for signing)
   ```bash
   java -version
   keytool -help
   ```

3. **Android SDK** (via Flutter)
   ```bash
   flutter doctor
   ```

### Required Files

- `pubspec.yaml` - Contains version information
- `android/app/build.gradle` - Build configuration
- `android/key.properties` - Signing configuration (create from template)

## Initial Setup

### 1. Verify Flutter Installation

```bash
flutter doctor
```

Ensure all required components are installed and configured.

### 2. Get Dependencies

```bash
flutter pub get
```

### 3. Verify Project Structure

```bash
# Windows PowerShell
.\scripts\verify_android_build.ps1

# Linux/Mac
chmod +x scripts/*.sh
./scripts/verify_android_build.sh
```

## Signing Configuration

### Why Signing is Required

- **APK**: Can be installed without signing (debug signing), but release signing is recommended
- **AAB**: **Must be signed** for Play Store uploads

### Step 1: Generate Keystore

**Windows PowerShell:**
```powershell
.\scripts\generate_keystore.ps1
```

**Linux/Mac:**
```bash
chmod +x scripts/generate_keystore.sh
./scripts/generate_keystore.sh
```

**Manual Method:**
```bash
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

This creates `upload-keystore.jks` in the project root.

**Important Information to Provide:**
- Keystore password (store this securely!)
- Key password (can be same as keystore password)
- Your name and organization details

### Step 2: Configure Signing

1. **Copy the template:**
   ```bash
   # Windows
   copy android\key.properties.template android\key.properties
   
   # Linux/Mac
   cp android/key.properties.template android/key.properties
   ```

2. **Edit `android/key.properties`:**
   ```properties
   storePassword=YOUR_STORE_PASSWORD
   keyPassword=YOUR_KEY_PASSWORD
   keyAlias=upload
   storeFile=../upload-keystore.jks
   ```

3. **Verify keystore file exists:**
   - The keystore should be at: `upload-keystore.jks` (project root)
   - Or update `storeFile` path if using a different location

### Step 3: Verify Signing Configuration

```bash
# Windows
.\scripts\verify_android_build.ps1

# Linux/Mac
./scripts/verify_android_build.sh
```

### Security Best Practices

⚠️ **CRITICAL SECURITY NOTES:**

1. **Never commit sensitive files:**
   - `android/key.properties` (already in `.gitignore`)
   - `*.jks` / `*.keystore` files (already in `.gitignore`)

2. **Store passwords securely:**
   - Use a password manager
   - Never share passwords in plain text
   - Keep backups of your keystore in a secure location

3. **Keystore backup:**
   - If you lose your keystore, you **cannot update** your app on Play Store
   - Store backups in multiple secure locations
   - Consider using cloud storage with encryption

## Version Management

### Version Format

Version is managed in `pubspec.yaml`:
```yaml
version: 3.1.0+1
#        ^^^^^^  ^
#        |       |
#        |       +-- versionCode (build number)
#        +---------- versionName (user-visible version)
```

- **versionName** (3.1.0): User-visible version (e.g., "3.1.0")
- **versionCode** (1): Build number, must increment for each release

### Version Management Scripts

**Show current version:**
```powershell
# Windows
.\scripts\version_manager.ps1

# Linux/Mac
./scripts/version_manager.sh
```

**Bump version:**
```powershell
# Windows - Patch (3.1.0 -> 3.1.1)
.\scripts\version_manager.ps1 -Bump Patch

# Windows - Minor (3.1.0 -> 3.2.0)
.\scripts\version_manager.ps1 -Bump Minor

# Windows - Major (3.1.0 -> 4.0.0)
.\scripts\version_manager.ps1 -Bump Major

# Linux/Mac
./scripts/version_manager.sh bump patch
./scripts/version_manager.sh bump minor
./scripts/version_manager.sh bump major
```

**Set build number:**
```powershell
# Windows
.\scripts\version_manager.ps1 -Build 42

# Linux/Mac
./scripts/version_manager.sh build 42
```

**Set complete version:**
```powershell
# Windows
.\scripts\version_manager.ps1 -Set "3.2.0+10"

# Linux/Mac
./scripts/version_manager.sh set "3.2.0+10"
```

### Version Code Rules

- **Must increment** for each Play Store release
- **Cannot decrease** (Play Store requirement)
- **Must be unique** across all releases

## Building APK

APK files are used for direct installation on Android devices.

### Universal APK

Single APK file containing all architectures (larger file size).

**Windows PowerShell:**
```powershell
.\scripts\build_apk.ps1
# or
.\scripts\build_apk.ps1 -Universal
```

**Linux/Mac:**
```bash
./scripts/build_apk.sh
# or
./scripts/build_apk.sh --universal
```

**Manual Command:**
```bash
flutter build apk --release
```

**Output:** `build/app/outputs/flutter-apk/app-release.apk`

### Split APK

Separate APK files per architecture (smaller file sizes, users download only their architecture).

**Windows PowerShell:**
```powershell
.\scripts\build_apk.ps1 -Split
```

**Linux/Mac:**
```bash
./scripts/build_apk.sh --split
```

**Manual Command:**
```bash
flutter build apk --release --split-per-abi
```

**Output:**
- `build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk` (32-bit ARM)
- `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` (64-bit ARM)
- `build/app/outputs/flutter-apk/app-x86_64-release.apk` (64-bit x86)

### Installing APK

**Via ADB:**
```bash
adb install build/app/outputs/flutter-apk/app-release.apk
```

**Via Device:**
1. Transfer APK to device
2. Enable "Install from Unknown Sources" in device settings
3. Open APK file on device
4. Follow installation prompts

## Building AAB

AAB (Android App Bundle) is the required format for Google Play Store distribution.

### Build AAB

**Windows PowerShell:**
```powershell
.\scripts\build_aab.ps1
```

**Linux/Mac:**
```bash
chmod +x scripts/build_aab.sh
./scripts/build_aab.sh
```

**Manual Command:**
```bash
flutter build appbundle --release
```

**Output:** `build/app/outputs/bundle/release/app-release.aab`

### Uploading to Play Store

1. **Go to Google Play Console:**
   - Navigate to: https://play.google.com/console

2. **Select your app:**
   - Choose your app from the dashboard

3. **Navigate to Release:**
   - Go to: Release > Production (or Internal/Alpha/Beta)

4. **Create new release:**
   - Click "Create new release"
   - Upload `app-release.aab`
   - Fill in release notes
   - Review and submit

### AAB Benefits

- **Smaller downloads**: Google generates optimized APKs per device
- **Dynamic delivery**: Users download only what they need
- **Required format**: Play Store requires AAB for new apps (since August 2021)

## Verification

### Verify Build Configuration

Run the verification script to check your setup:

**Windows PowerShell:**
```powershell
.\scripts\verify_android_build.ps1
```

**Linux/Mac:**
```bash
./scripts/verify_android_build.sh
```

**What it checks:**
- ✅ Flutter installation
- ✅ Java/keytool availability
- ✅ Project structure
- ✅ Version configuration
- ✅ Signing configuration
- ✅ Build scripts
- ✅ Security settings (.gitignore)

### Verify APK/AAB

**Check APK signature:**
```bash
jarsigner -verify -verbose -certs build/app/outputs/flutter-apk/app-release.apk
```

**Check AAB:**
```bash
bundletool build-apks --bundle=build/app/outputs/bundle/release/app-release.aab --output=app.apks
```

**Check APK info:**
```bash
aapt dump badging build/app/outputs/flutter-apk/app-release.apk | grep -E "package|versionCode|versionName"
```

## Troubleshooting

### Common Issues

#### 1. "key.properties not found"

**Problem:** Build uses debug signing (not suitable for Play Store)

**Solution:**
```bash
# Create key.properties from template
cp android/key.properties.template android/key.properties
# Edit and fill in your keystore details
```

#### 2. "Keystore file not found"

**Problem:** Keystore path in `key.properties` is incorrect

**Solution:**
- Verify keystore file exists
- Check path in `key.properties` (relative or absolute)
- Ensure path is correct from `android/` directory

#### 3. "Wrong password"

**Problem:** Keystore or key password is incorrect

**Solution:**
- Verify passwords in `key.properties`
- Test keystore: `keytool -list -v -keystore upload-keystore.jks`

#### 4. "Version code must be higher"

**Problem:** Version code is not higher than previous release

**Solution:**
```bash
# Increment version code
.\scripts\version_manager.ps1 -Build <next_number>
# or
./scripts/version_manager.sh build <next_number>
```

#### 5. "Build failed"

**Problem:** Various build errors

**Solution:**
```bash
# Clean build
flutter clean
flutter pub get

# Try building again
flutter build apk --release
# or
flutter build appbundle --release
```

#### 6. "Gradle build failed"

**Problem:** Gradle configuration issues

**Solution:**
```bash
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
flutter build apk --release
```

### Debug Build Issues

**Enable verbose logging:**
```bash
flutter build apk --release --verbose
```

**Check Gradle logs:**
```bash
cd android
./gradlew assembleRelease --stacktrace
```

## Best Practices

### 1. Version Management

- ✅ Always increment version code for releases
- ✅ Use semantic versioning (MAJOR.MINOR.PATCH)
- ✅ Document version changes in release notes

### 2. Signing

- ✅ Use release signing for all production builds
- ✅ Keep keystore backups in secure locations
- ✅ Never commit signing files to version control
- ✅ Use strong passwords for keystore

### 3. Build Process

- ✅ Always clean before release builds: `flutter clean`
- ✅ Verify builds before uploading to Play Store
- ✅ Test APK on multiple devices before release
- ✅ Use AAB for Play Store (required format)

### 4. Testing

- ✅ Test on multiple Android versions (API 21+)
- ✅ Test on different screen sizes
- ✅ Verify all features work correctly
- ✅ Test offline functionality

### 5. Release Checklist

Before releasing:

- [ ] Version code incremented
- [ ] Version name updated
- [ ] Signing configuration verified
- [ ] Build successful (no errors)
- [ ] APK/AAB tested on device
- [ ] Release notes prepared
- [ ] Screenshots updated (if needed)
- [ ] Play Store listing updated

## File Locations

| File Type | Location |
|-----------|----------|
| **AAB** (Play Store) | `build/app/outputs/bundle/release/app-release.aab` |
| **APK** (Universal) | `build/app/outputs/flutter-apk/app-release.apk` |
| **APK** (Split - ARM64) | `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` |
| **APK** (Split - ARM32) | `build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk` |
| **APK** (Split - x86_64) | `build/app/outputs/flutter-apk/app-x86_64-release.apk` |
| **Keystore** | `upload-keystore.jks` (project root) |
| **Signing Config** | `android/key.properties` (not in git) |
| **Build Config** | `android/app/build.gradle` |
| **ProGuard Rules** | `android/app/proguard-rules.pro` |

## Quick Reference

### Build Commands

```bash
# APK (Universal)
flutter build apk --release

# APK (Split)
flutter build apk --release --split-per-abi

# AAB (Play Store)
flutter build appbundle --release
```

### Script Commands

```powershell
# Windows PowerShell
.\scripts\build_apk.ps1              # Build universal APK
.\scripts\build_apk.ps1 -Split        # Build split APKs
.\scripts\build_aab.ps1                # Build AAB
.\scripts\version_manager.ps1          # Show version
.\scripts\version_manager.ps1 -Bump Patch  # Bump patch version
.\scripts\generate_keystore.ps1        # Generate keystore
.\scripts\verify_android_build.ps1     # Verify configuration
```

```bash
# Linux/Mac
./scripts/build_apk.sh                # Build universal APK
./scripts/build_apk.sh --split        # Build split APKs
./scripts/build_aab.sh                # Build AAB
./scripts/version_manager.sh           # Show version
./scripts/version_manager.sh bump patch  # Bump patch version
./scripts/generate_keystore.sh        # Generate keystore
./scripts/verify_android_build.sh     # Verify configuration
```

## Additional Resources

- **Flutter Build Documentation**: https://docs.flutter.dev/deployment/android
- **Android App Signing**: https://developer.android.com/studio/publish/app-signing
- **Google Play Console**: https://play.google.com/console
- **Android App Bundle**: https://developer.android.com/guide/app-bundle

## Support

For issues or questions:
1. Check [Troubleshooting](#troubleshooting) section
2. Run verification script: `.\scripts\verify_android_build.ps1`
3. Check Flutter documentation: https://docs.flutter.dev
4. Review build logs for detailed error messages

---

**Last Updated:** 2024
**Project:** Dual Reader 3.1
**Platform:** Android
