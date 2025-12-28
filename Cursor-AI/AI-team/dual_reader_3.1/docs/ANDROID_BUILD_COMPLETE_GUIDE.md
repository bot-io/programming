# Android Build and Signing - Complete Guide

Complete guide for building and signing Android releases for Dual Reader 3.1.

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Initial Setup](#initial-setup)
4. [Signing Configuration](#signing-configuration)
5. [Version Management](#version-management)
6. [Building APK](#building-apk)
7. [Building AAB](#building-aab)
8. [Build Scripts](#build-scripts)
9. [Troubleshooting](#troubleshooting)
10. [Best Practices](#best-practices)

---

## Overview

This guide covers the complete Android build and signing process for Dual Reader 3.1. The project supports:

- **APK builds** for direct installation (universal or split per architecture)
- **AAB builds** for Google Play Store distribution
- **Automatic version management** from `pubspec.yaml`
- **Release signing** with keystore configuration
- **Build scripts** for Windows (PowerShell) and Linux/Mac (Bash)

---

## Prerequisites

Before building, ensure you have:

1. **Flutter SDK** (latest stable version)
   ```bash
   flutter --version
   ```

2. **Java JDK** (for keystore generation and signing)
   ```bash
   java -version
   keytool -help
   ```

3. **Android SDK** (configured via Android Studio or standalone)
   - Minimum: API 21 (Android 5.0)
   - Target: API 34 (Android 14)

4. **Project Dependencies**
   ```bash
   flutter pub get
   ```

---

## Initial Setup

### 1. Verify Project Structure

Ensure these files exist:
- `pubspec.yaml` - Contains version information
- `android/app/build.gradle` - Build configuration
- `android/key.properties.template` - Signing template

### 2. Check Flutter Configuration

```bash
flutter doctor
```

Ensure Android toolchain is properly configured.

### 3. Verify Build Configuration

Run the verification script:

**Windows:**
```powershell
.\scripts\verify_android_build.ps1
```

**Linux/Mac:**
```bash
./scripts/verify_android_build.sh
```

This checks:
- ✅ Flutter installation
- ✅ Java/keytool availability
- ✅ Project structure
- ✅ Version configuration
- ✅ Signing configuration
- ✅ Build scripts
- ✅ Security settings

---

## Signing Configuration

### Why Signing is Required

- **APK for direct installation**: Optional (but recommended)
- **AAB for Play Store**: **Required** (Play Store rejects unsigned builds)

### Generate Keystore

**Windows:**
```powershell
.\scripts\generate_keystore.ps1
```

**Linux/Mac:**
```bash
./scripts/generate_keystore.sh
```

This creates `upload-keystore.jks` in the project root.

**Manual Generation:**
```bash
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

### Configure Signing

1. **Copy template:**
   ```bash
   cp android/key.properties.template android/key.properties
   ```

2. **Edit `android/key.properties`:**
   ```properties
   storeFile=../upload-keystore.jks
   storePassword=YOUR_STORE_PASSWORD
   keyPassword=YOUR_KEY_PASSWORD
   keyAlias=upload
   ```

3. **Verify configuration:**
   ```bash
   keytool -list -v -keystore upload-keystore.jks
   ```

### Security Best Practices

⚠️ **IMPORTANT:**
- ✅ Never commit `key.properties` to git (already in `.gitignore`)
- ✅ Never commit keystore files (already in `.gitignore`)
- ✅ Store keystore backup in secure location
- ✅ Use strong passwords
- ✅ Keep keystore safe (loss means you can't update app)

---

## Version Management

### Version Format

Version format in `pubspec.yaml`:
```yaml
version: 3.1.0+1
#        ^^^^^^ ^
#        |      |
#        |      Build number (versionCode)
#        Version name (versionName)
```

- **Version Name** (`3.1.0`): User-visible version (major.minor.patch)
- **Version Code** (`1`): Internal build number (must increment for each release)

### Show Current Version

**Windows:**
```powershell
.\scripts\version_manager.ps1
```

**Linux/Mac:**
```bash
./scripts/version_manager.sh
```

### Bump Version

**Patch version** (3.1.0 -> 3.1.1):
```powershell
.\scripts\version_manager.ps1 -Bump Patch
```

**Minor version** (3.1.0 -> 3.2.0):
```powershell
.\scripts\version_manager.ps1 -Bump Minor
```

**Major version** (3.1.0 -> 4.0.0):
```powershell
.\scripts\version_manager.ps1 -Bump Major
```

### Set Build Number

```powershell
.\scripts\version_manager.ps1 -Build 42
```

### Set Complete Version

```powershell
.\scripts\version_manager.ps1 -Set "3.2.0+10"
```

### Version Management Rules

1. **Version Code** must always increase for Play Store uploads
2. **Version Name** can be any format (semantic versioning recommended)
3. **Build number** increments automatically when bumping version
4. **Version** is read from `pubspec.yaml` during build

---

## Building APK

### Universal APK (All Architectures)

Single APK file containing all architectures (larger file size).

**Windows:**
```powershell
.\scripts\build_apk.ps1
# Or explicitly:
.\scripts\build_apk.ps1 -Universal
```

**Linux/Mac:**
```bash
./scripts/build_apk.sh
# Or explicitly:
./scripts/build_apk.sh --universal
```

**Direct Flutter command:**
```bash
flutter build apk --release
```

**Output:**
- `build/app/outputs/flutter-apk/app-release.apk`

### Split APKs (Per Architecture)

Separate APK files per architecture (smaller downloads).

**Windows:**
```powershell
.\scripts\build_apk.ps1 -Split
```

**Linux/Mac:**
```bash
./scripts/build_apk.sh --split
```

**Direct Flutter command:**
```bash
flutter build apk --release --split-per-abi
```

**Output:**
- `build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk` (32-bit ARM)
- `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` (64-bit ARM)
- `build/app/outputs/flutter-apk/app-x86_64-release.apk` (64-bit x86)

### APK Installation

**Via ADB:**
```bash
adb install build/app/outputs/flutter-apk/app-release.apk
```

**For split APKs:**
```bash
adb install build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

---

## Building AAB

### Android App Bundle (Play Store)

Optimized format for Google Play Store. Google generates optimized APKs per device.

**Windows:**
```powershell
.\scripts\build_aab.ps1
```

**Linux/Mac:**
```bash
./scripts/build_aab.sh
```

**Direct Flutter command:**
```bash
flutter build appbundle --release
```

**Output:**
- `build/app/outputs/bundle/release/app-release.aab`

### AAB Upload to Play Store

1. Go to [Google Play Console](https://play.google.com/console)
2. Navigate to your app > **Release** > **Production** (or Internal/Alpha/Beta)
3. Click **Create new release**
4. Upload `app-release.aab`
5. Fill in release notes
6. Submit for review

### AAB vs APK

| Feature | APK | AAB |
|---------|-----|-----|
| **Distribution** | Direct installation | Play Store only |
| **File Size** | Larger (all architectures) | Smaller (optimized per device) |
| **Signing** | Optional | Required |
| **Use Case** | Testing, sideloading | Production releases |

---

## Build Scripts

### Windows (PowerShell)

| Script | Purpose |
|--------|---------|
| `build_apk.ps1` | Build APK (universal or split) |
| `build_aab.ps1` | Build AAB for Play Store |
| `build_android.ps1` | Master script (APK, AAB, or Both) |
| `generate_keystore.ps1` | Generate signing keystore |
| `version_manager.ps1` | Manage version numbers |
| `verify_android_build.ps1` | Verify build configuration |

### Linux/Mac (Bash)

| Script | Purpose |
|--------|---------|
| `build_apk.sh` | Build APK (universal or split) |
| `build_aab.sh` | Build AAB for Play Store |
| `build_android.sh` | Master script (APK, AAB, or Both) |
| `generate_keystore.sh` | Generate signing keystore |
| `version_manager.sh` | Manage version numbers |
| `verify_android_build.sh` | Verify build configuration |

### Master Build Script

Build both APK and AAB:

**Windows:**
```powershell
.\scripts\build_android.ps1 -Type Both
```

**Linux/Mac:**
```bash
./scripts/build_android.sh Both
```

---

## Troubleshooting

### Missing key.properties

**Symptom:** Build uses debug signing

**Solution:**
1. Copy `android/key.properties.template` to `android/key.properties`
2. Fill in keystore details
3. Ensure keystore file exists

### Wrong Password

**Symptom:** Build fails with signing error

**Solution:**
1. Verify passwords in `android/key.properties`
2. Test keystore: `keytool -list -v -keystore upload-keystore.jks`
3. Ensure passwords match keystore

### Version Code Error

**Symptom:** Play Store rejects upload (version code too low)

**Solution:**
```powershell
.\scripts\version_manager.ps1 -Build <higher_number>
```

### Build Fails

**Solution:**
1. Clean build: `flutter clean`
2. Get dependencies: `flutter pub get`
3. Verify Flutter: `flutter doctor`
4. Check verification script: `.\scripts\verify_android_build.ps1`
5. Check build logs for specific errors

### Keystore Not Found

**Symptom:** Warning about keystore file not found

**Solution:**
1. Verify `storeFile` path in `android/key.properties`
2. Use relative path: `../upload-keystore.jks`
3. Or use absolute path: `C:/path/to/upload-keystore.jks`
4. Ensure keystore file exists at specified location

### Gradle Build Errors

**Symptom:** Gradle sync or build fails

**Solution:**
1. Check `android/gradle.properties` for correct configuration
2. Verify `android/build.gradle` dependencies
3. Update Gradle wrapper: `cd android && ./gradlew wrapper --gradle-version=8.0`
4. Clean Gradle cache: `cd android && ./gradlew clean`

---

## Best Practices

### 1. Version Management

- ✅ Use semantic versioning (major.minor.patch)
- ✅ Always increment version code for releases
- ✅ Use version manager scripts for consistency
- ✅ Document version changes in release notes

### 2. Signing

- ✅ Use strong passwords (16+ characters)
- ✅ Store keystore backup securely
- ✅ Never commit signing files to git
- ✅ Test signing configuration before release

### 3. Build Process

- ✅ Always clean before release builds: `flutter clean`
- ✅ Verify build configuration before building
- ✅ Test APK/AAB on real devices before release
- ✅ Use AAB for Play Store, APK for testing

### 4. Release Checklist

Before releasing:

- [ ] Version bumped in `pubspec.yaml`
- [ ] Signing configuration verified
- [ ] Build configuration verified
- [ ] APK/AAB builds successfully
- [ ] Tested on real device
- [ ] Release notes prepared
- [ ] Keystore backup confirmed

### 5. Security

- ✅ Never share keystore files
- ✅ Use environment variables for CI/CD (if applicable)
- ✅ Rotate keystore if compromised
- ✅ Keep signing credentials secure

---

## File Locations

| File Type | Location |
|-----------|----------|
| **AAB** (Play Store) | `build/app/outputs/bundle/release/app-release.aab` |
| **APK** (Universal) | `build/app/outputs/flutter-apk/app-release.apk` |
| **APK** (Split) | `build/app/outputs/flutter-apk/app-*-release.apk` |
| **Keystore** | `upload-keystore.jks` (project root) |
| **Signing Config** | `android/key.properties` (not in git) |
| **Build Config** | `android/app/build.gradle` |
| **Version** | `pubspec.yaml` |

---

## Quick Reference

### Common Commands

```bash
# Clean build
flutter clean

# Get dependencies
flutter pub get

# Build APK (universal)
flutter build apk --release

# Build APK (split)
flutter build apk --release --split-per-abi

# Build AAB
flutter build appbundle --release

# Install APK
adb install build/app/outputs/flutter-apk/app-release.apk

# Check Flutter setup
flutter doctor
```

### Script Usage

```powershell
# Windows - Build APK
.\scripts\build_apk.ps1

# Windows - Build AAB
.\scripts\build_aab.ps1

# Windows - Version management
.\scripts\version_manager.ps1 -Bump Patch

# Windows - Verify configuration
.\scripts\verify_android_build.ps1
```

```bash
# Linux/Mac - Build APK
./scripts/build_apk.sh

# Linux/Mac - Build AAB
./scripts/build_aab.sh

# Linux/Mac - Version management
./scripts/version_manager.sh bump patch

# Linux/Mac - Verify configuration
./scripts/verify_android_build.sh
```

---

## Additional Resources

- [Flutter Build Documentation](https://docs.flutter.dev/deployment/android)
- [Android App Signing](https://developer.android.com/studio/publish/app-signing)
- [Google Play Console](https://play.google.com/console)
- [Android Gradle Plugin](https://developer.android.com/studio/releases/gradle-plugin)

---

**Last Updated:** 2024  
**Status:** ✅ Production Ready
