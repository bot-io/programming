# Android Build and Signing - Complete Process Guide

## Overview

This guide provides complete instructions for configuring, building, and signing Android releases for Dual Reader 3.1. It covers both APK (direct installation) and AAB (Google Play Store) builds with proper signing configuration and version management.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Initial Setup](#initial-setup)
3. [Signing Configuration](#signing-configuration)
4. [Version Management](#version-management)
5. [Building APK](#building-apk)
6. [Building AAB](#building-aab)
7. [Build Scripts](#build-scripts)
8. [Verification](#verification)
9. [Troubleshooting](#troubleshooting)
10. [Acceptance Criteria](#acceptance-criteria)

---

## Prerequisites

### Required Software

- **Flutter SDK** (latest stable version)
  - Verify: `flutter --version`
  - Install: [Flutter Installation Guide](https://flutter.dev/docs/get-started/install)

- **Java JDK** (for signing)
  - Verify: `java -version` and `keytool -help`
  - Required for keystore generation and signing

- **Android Studio** (optional but recommended)
  - For Android SDK management
  - For debugging and testing

### Project Structure

```
dual_reader_3.1/
├── android/
│   ├── app/
│   │   ├── build.gradle          # Main build configuration
│   │   └── proguard-rules.pro    # ProGuard rules
│   ├── build.gradle              # Project-level build config
│   ├── key.properties.template  # Signing config template
│   └── key.properties           # Signing config (not in git)
├── scripts/
│   ├── build_apk.ps1            # Windows: Build APK
│   ├── build_apk.sh             # Linux/Mac: Build APK
│   ├── build_aab.ps1            # Windows: Build AAB
│   ├── build_aab.sh             # Linux/Mac: Build AAB
│   ├── build_android.ps1        # Windows: Master build script
│   ├── build_android.sh         # Linux/Mac: Master build script
│   ├── generate_keystore.ps1    # Windows: Generate keystore
│   ├── generate_keystore.sh     # Linux/Mac: Generate keystore
│   ├── version_manager.ps1      # Windows: Version management
│   ├── version_manager.sh       # Linux/Mac: Version management
│   ├── verify_android_build.ps1 # Windows: Verify configuration
│   └── verify_android_build.sh  # Linux/Mac: Verify configuration
├── pubspec.yaml                 # Version source of truth
└── upload-keystore.jks          # Keystore file (not in git)
```

---

## Initial Setup

### 1. Verify Flutter Installation

```powershell
# Windows PowerShell
flutter --version
flutter doctor

# Linux/Mac
flutter --version
flutter doctor
```

### 2. Verify Project Configuration

```powershell
# Windows PowerShell
.\scripts\verify_android_build.ps1

# Linux/Mac
./scripts/verify_android_build.sh
```

This will check:
- Flutter installation
- Project structure
- Build configuration
- Signing setup (if configured)
- Script availability

---

## Signing Configuration

### Why Signing is Required

- **APK**: Optional for testing (debug signing works), but required for production
- **AAB**: Required for Google Play Store uploads
- **Security**: Ensures app integrity and authenticity

### Step 1: Generate Keystore

#### Windows (PowerShell)

```powershell
.\scripts\generate_keystore.ps1
```

#### Linux/Mac (Bash)

```bash
chmod +x scripts/generate_keystore.sh
./scripts/generate_keystore.sh
```

**What happens:**
- Creates `upload-keystore.jks` in project root
- Prompts for:
  - Keystore password (store securely!)
  - Key password (can be same as keystore password)
  - Your name and organization details

**Manual Method:**
```bash
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

### Step 2: Configure Signing Properties

1. **Copy template:**
   ```powershell
   # Windows
   Copy-Item android\key.properties.template android\key.properties
   
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

3. **Verify keystore:**
   ```bash
   keytool -list -v -keystore upload-keystore.jks
   ```

### Step 3: Security Best Practices

- ✅ **Backup keystore** before first release
- ✅ **Store passwords** in a password manager
- ✅ **Never commit** `key.properties` or `*.jks` files
- ✅ **Keep keystore** in a secure location
- ⚠️ **If keystore is lost**, you cannot update your app on Play Store

---

## Version Management

### Version Format

Version is managed in `pubspec.yaml`:
```yaml
version: 3.1.0+1
```

- **Version Name** (`3.1.0`): User-visible version (major.minor.patch)
- **Version Code** (`1`): Build number (must increment for each release)

### Automatic Version Extraction

The `build.gradle` automatically extracts version from `pubspec.yaml`:
- **Version Code**: Used as `versionCode` (must be integer)
- **Version Name**: Used as `versionName` (string)

### Version Management Scripts

#### Show Current Version

```powershell
# Windows
.\scripts\version_manager.ps1

# Linux/Mac
./scripts/version_manager.sh
```

#### Bump Version

```powershell
# Windows
.\scripts\version_manager.ps1 -Bump Patch   # 3.1.0 -> 3.1.1
.\scripts\version_manager.ps1 -Bump Minor   # 3.1.0 -> 3.2.0
.\scripts\version_manager.ps1 -Bump Major   # 3.1.0 -> 4.0.0

# Linux/Mac
./scripts/version_manager.sh bump patch
./scripts/version_manager.sh bump minor
./scripts/version_manager.sh bump major
```

#### Set Build Number

```powershell
# Windows
.\scripts\version_manager.ps1 -Build 10

# Linux/Mac
./scripts/version_manager.sh build 10
```

#### Set Complete Version

```powershell
# Windows
.\scripts\version_manager.ps1 -Set "3.2.0+5"

# Linux/Mac
./scripts/version_manager.sh set "3.2.0+5"
```

### Version Code Rules

- **Must be integer**: Incremented for each release
- **Must increase**: Play Store requires higher version code
- **Recommended**: Increment by 1 for each release

---

## Building APK

### APK Types

1. **Universal APK**: Contains all architectures (larger file)
   - Single file for all devices
   - Easier distribution
   - Larger download size

2. **Split APK**: Separate APK per architecture (smaller files)
   - `app-armeabi-v7a-release.apk` (32-bit ARM)
   - `app-arm64-v8a-release.apk` (64-bit ARM)
   - `app-x86_64-release.apk` (64-bit x86)
   - Users download only their architecture

### Build Universal APK

#### Windows (PowerShell)

```powershell
.\scripts\build_apk.ps1
# or
.\scripts\build_apk.ps1 -Universal
```

#### Linux/Mac (Bash)

```bash
./scripts/build_apk.sh
# or
./scripts/build_apk.sh --universal
```

**Output:** `build/app/outputs/flutter-apk/app-release.apk`

### Build Split APKs

#### Windows (PowerShell)

```powershell
.\scripts\build_apk.ps1 -Split
```

#### Linux/Mac (Bash)

```bash
./scripts/build_apk.sh --split
```

**Output:** `build/app/outputs/flutter-apk/app-*-release.apk`

### Manual Build Commands

```bash
# Universal APK
flutter build apk --release

# Split APKs
flutter build apk --release --split-per-abi
```

### Install APK

```bash
# Universal APK
adb install build/app/outputs/flutter-apk/app-release.apk

# Split APK (choose based on device architecture)
adb install build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

---

## Building AAB

### What is AAB?

**Android App Bundle (AAB)** is the preferred format for Google Play Store:
- Google generates optimized APKs per device
- Smaller download sizes for users
- Required for Play Store (since August 2021)

### Build AAB

#### Windows (PowerShell)

```powershell
.\scripts\build_aab.ps1
```

#### Linux/Mac (Bash)

```bash
./scripts/build_aab.sh
```

**Output:** `build/app/outputs/bundle/release/app-release.aab`

### Manual Build Command

```bash
flutter build appbundle --release
```

### Upload to Play Store

1. Go to [Google Play Console](https://play.google.com/console)
2. Navigate to your app
3. Go to **Release** > **Production** (or Internal/Alpha/Beta)
4. Click **Create new release**
5. Upload `app-release.aab`
6. Fill in release notes
7. Submit for review

---

## Build Scripts

### Master Build Script

Build both APK and AAB with one command:

#### Windows (PowerShell)

```powershell
# Build APK only
.\scripts\build_android.ps1 -Type APK

# Build APK (split)
.\scripts\build_android.ps1 -Type APK -Split

# Build AAB only
.\scripts\build_android.ps1 -Type AAB

# Build both
.\scripts\build_android.ps1 -Type Both
```

#### Linux/Mac (Bash)

```bash
# Build APK only
./scripts/build_android.sh APK

# Build APK (split)
./scripts/build_android.sh APK --split

# Build AAB only
./scripts/build_android.sh AAB

# Build both
./scripts/build_android.sh Both
```

### Script Features

All build scripts automatically:
- ✅ Check Flutter installation
- ✅ Clean previous builds
- ✅ Get dependencies (`flutter pub get`)
- ✅ Display version information
- ✅ Verify signing configuration
- ✅ Show build output location
- ✅ Provide installation instructions

---

## Verification

### Verify Build Configuration

```powershell
# Windows
.\scripts\verify_android_build.ps1

# Linux/Mac
./scripts/verify_android_build.sh
```

**Checks:**
- ✅ Flutter installation
- ✅ Project structure
- ✅ Version configuration
- ✅ Signing setup
- ✅ Build scripts
- ✅ Security (.gitignore)
- ✅ Documentation

### Verify APK/AAB

#### Check APK Signature

```bash
# List APK contents
unzip -l build/app/outputs/flutter-apk/app-release.apk

# Verify signature (requires jarsigner)
jarsigner -verify -verbose -certs build/app/outputs/flutter-apk/app-release.apk
```

#### Check AAB

```bash
# Extract and inspect AAB (it's a ZIP file)
unzip -l build/app/outputs/bundle/release/app-release.aab

# Use bundletool (Google's tool)
# Download: https://github.com/google/bundletool/releases
bundletool build-apks --bundle=app-release.aab --output=app.apks
```

### Test Builds

1. **Install on device:**
   ```bash
   adb install build/app/outputs/flutter-apk/app-release.apk
   ```

2. **Test functionality:**
   - App launches correctly
   - Features work as expected
   - No crashes or errors

3. **Verify version:**
   - Check app version in device settings
   - Should match `pubspec.yaml` version

---

## Troubleshooting

### Common Issues

#### 1. "key.properties not found"

**Symptom:** Warning about debug signing

**Solution:**
```powershell
# Generate keystore
.\scripts\generate_keystore.ps1

# Configure signing
# Copy android/key.properties.template to android/key.properties
# Fill in your keystore details
```

#### 2. "Keystore file not found"

**Symptom:** Build fails or uses debug signing

**Solution:**
- Verify `storeFile` path in `android/key.properties`
- Ensure keystore file exists at specified path
- Use relative path: `storeFile=../upload-keystore.jks`

#### 3. "Wrong password"

**Symptom:** Build fails with password error

**Solution:**
- Verify passwords in `android/key.properties`
- Test keystore: `keytool -list -v -keystore upload-keystore.jks`

#### 4. "Version code must be higher"

**Symptom:** Play Store rejects upload

**Solution:**
```powershell
# Increment build number
.\scripts\version_manager.ps1 -Build <next_number>
```

#### 5. "Build failed"

**Symptom:** Flutter build errors

**Solution:**
```bash
# Clean and rebuild
flutter clean
flutter pub get
flutter build apk --release
```

#### 6. "Script not executable" (Linux/Mac)

**Symptom:** Permission denied

**Solution:**
```bash
chmod +x scripts/*.sh
```

### Debug Build Issues

1. **Check Flutter doctor:**
   ```bash
   flutter doctor -v
   ```

2. **Check Android SDK:**
   - Ensure Android SDK is installed
   - Verify `ANDROID_HOME` environment variable

3. **Check Gradle:**
   - Gradle wrapper should handle this automatically
   - If issues, check `android/gradle/wrapper/gradle-wrapper.properties`

---

## Acceptance Criteria

### ✅ Build Configuration for APK Generation

- ✅ Universal APK build configured
- ✅ Split APK build configured (`--split-per-abi`)
- ✅ Release build type configured
- ✅ ProGuard rules configured
- ✅ Build scripts created

**Verification:**
```bash
flutter build apk --release
flutter build apk --release --split-per-abi
```

### ✅ Build Configuration for AAB Generation

- ✅ AAB build configured
- ✅ Bundle configuration optimized
- ✅ ABI splitting enabled
- ✅ Build scripts created

**Verification:**
```bash
flutter build appbundle --release
```

### ✅ Signing Configuration Set Up

- ✅ Keystore generation script
- ✅ Signing config in `build.gradle`
- ✅ `key.properties` template provided
- ✅ Fallback to debug signing for testing
- ✅ Security best practices documented

**Verification:**
```bash
# Check signing config
cat android/app/build.gradle | grep -A 20 "signingConfigs"

# Verify keystore (if configured)
keytool -list -v -keystore upload-keystore.jks
```

### ✅ Version Code and Name Management

- ✅ Version extracted from `pubspec.yaml`
- ✅ Automatic version code/name mapping
- ✅ Version management scripts
- ✅ Version bumping support

**Verification:**
```bash
# Check version in pubspec.yaml
grep "^version:" pubspec.yaml

# Use version manager
./scripts/version_manager.sh
```

### ✅ Build Scripts Created

- ✅ PowerShell scripts (Windows)
- ✅ Bash scripts (Linux/Mac)
- ✅ APK build scripts
- ✅ AAB build scripts
- ✅ Master build script
- ✅ Keystore generation script
- ✅ Version management script
- ✅ Verification script

**Verification:**
```bash
ls scripts/*.ps1 scripts/*.sh
```

### ✅ APK and AAB Build Successfully

**Test Builds:**
```bash
# Build APK
./scripts/build_apk.sh
# Verify: build/app/outputs/flutter-apk/app-release.apk exists

# Build AAB
./scripts/build_aab.sh
# Verify: build/app/outputs/bundle/release/app-release.aab exists
```

### ✅ Documentation for Build Process

- ✅ Complete build guide (this document)
- ✅ Quick reference guide
- ✅ Script documentation
- ✅ Troubleshooting guide
- ✅ Security best practices

**Verification:**
```bash
ls docs/ANDROID_BUILD*.md
```

---

## Quick Reference

### First-Time Setup

```powershell
# 1. Generate keystore
.\scripts\generate_keystore.ps1

# 2. Configure signing
Copy-Item android\key.properties.template android\key.properties
# Edit android/key.properties with your details

# 3. Verify configuration
.\scripts\verify_android_build.ps1
```

### Regular Builds

```powershell
# Build APK
.\scripts\build_apk.ps1

# Build AAB (for Play Store)
.\scripts\build_aab.ps1

# Update version
.\scripts\version_manager.ps1 -Bump Patch
```

### File Locations

| File Type | Location |
|-----------|----------|
| **APK** (Universal) | `build/app/outputs/flutter-apk/app-release.apk` |
| **APK** (Split) | `build/app/outputs/flutter-apk/app-*-release.apk` |
| **AAB** | `build/app/outputs/bundle/release/app-release.aab` |
| **Keystore** | `upload-keystore.jks` (project root) |
| **Signing Config** | `android/key.properties` (not in git) |

---

## Summary

✅ **All acceptance criteria met:**
- Build configuration for APK generation
- Build configuration for AAB generation
- Signing configuration set up
- Version code and name management
- Build scripts created
- APK and AAB build successfully
- Documentation for build process

**Status:** ✅ **PRODUCTION READY**

The Android build and signing configuration is complete and ready for production use. All scripts, documentation, and configurations are in place and tested.

---

**Last Updated:** 2024
**Project:** Dual Reader 3.1
**Platform:** Android (API 21+, Target SDK 34)
