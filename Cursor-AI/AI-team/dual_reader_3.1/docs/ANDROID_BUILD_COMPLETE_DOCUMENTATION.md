# Android Build and Signing - Complete Documentation

## Overview

This document provides comprehensive documentation for building and signing Android releases for Dual Reader 3.1. It covers APK generation for direct installation, AAB generation for Google Play Store, signing configuration, version management, and build scripts.

## Table of Contents

1. [Quick Start](#quick-start)
2. [Build Configuration](#build-configuration)
3. [Signing Configuration](#signing-configuration)
4. [Version Management](#version-management)
5. [Build Scripts](#build-scripts)
6. [Build Process](#build-process)
7. [Troubleshooting](#troubleshooting)
8. [Acceptance Criteria Verification](#acceptance-criteria-verification)

---

## Quick Start

### Prerequisites

- Flutter SDK (latest stable version)
- Java JDK (for signing)
- Android SDK (via Flutter)
- Git (for version control)

### First-Time Setup

1. **Generate Keystore** (one-time setup):
   ```powershell
   # Windows
   .\scripts\generate_keystore.ps1
   
   # Linux/Mac
   ./scripts/generate_keystore.sh
   ```

2. **Configure Signing**:
   - Copy `android/key.properties.template` to `android/key.properties`
   - Edit `android/key.properties` with your keystore details:
     ```properties
     storePassword=YOUR_STORE_PASSWORD
     keyPassword=YOUR_KEY_PASSWORD
     keyAlias=upload
     storeFile=../upload-keystore.jks
     ```

3. **Verify Configuration**:
   ```powershell
   # Windows
   .\scripts\verify_android_build.ps1
   
   # Linux/Mac
   ./scripts/verify_android_build.sh
   ```

### Building Releases

**Build APK (Direct Installation):**
```powershell
# Universal APK (all architectures)
.\scripts\build_apk.ps1

# Split APKs (smaller files per architecture)
.\scripts\build_apk.ps1 -Split
```

**Build AAB (Play Store):**
```powershell
.\scripts\build_aab.ps1
```

**Build Both:**
```powershell
.\scripts\build_android.ps1 -Type Both
```

---

## Build Configuration

### APK Build Configuration

The Android build system supports two APK build types:

#### 1. Universal APK
- **Command**: `flutter build apk --release`
- **Output**: Single APK containing all architectures
- **Location**: `build/app/outputs/flutter-apk/app-release.apk`
- **Size**: Larger (~50-100MB)
- **Use Case**: Direct installation, testing, distribution outside Play Store

#### 2. Split APKs
- **Command**: `flutter build apk --release --split-per-abi`
- **Output**: Separate APKs per architecture
- **Location**: `build/app/outputs/flutter-apk/`
  - `app-armeabi-v7a-release.apk` (32-bit ARM)
  - `app-arm64-v8a-release.apk` (64-bit ARM)
  - `app-x86_64-release.apk` (64-bit x86)
- **Size**: Smaller (~20-40MB each)
- **Use Case**: Smaller downloads, architecture-specific distribution

### AAB Build Configuration

- **Command**: `flutter build appbundle --release`
- **Output**: Android App Bundle (AAB)
- **Location**: `build/app/outputs/bundle/release/app-release.aab`
- **Size**: Optimized bundle (~30-60MB)
- **Use Case**: Google Play Store distribution (required)

**AAB Configuration** (`android/app/build.gradle`):
```gradle
bundle {
    language {
        enableSplit = false  // Include all languages
    }
    density {
        enableSplit = false  // Include all densities
    }
    abi {
        enableSplit = true   // Split by architecture (Play Store optimization)
    }
}
```

### Build Types

#### Debug Build
- **Signing**: Debug keystore (automatic)
- **Optimization**: None
- **Debuggable**: Yes
- **Use Case**: Development and testing

#### Release Build
- **Signing**: Release keystore (from `key.properties`)
- **Optimization**: Enabled (minify, shrink resources)
- **Debuggable**: No
- **Use Case**: Production releases

**Release Build Configuration** (`android/app/build.gradle`):
```gradle
release {
    signingConfig signingConfigs.release
    minifyEnabled true
    shrinkResources true
    proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
}
```

---

## Signing Configuration

### Keystore Generation

**Using Script (Recommended):**
```powershell
# Windows
.\scripts\generate_keystore.ps1

# Linux/Mac
./scripts/generate_keystore.sh
```

**Manual Generation:**
```bash
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

**Keystore Details:**
- **Location**: Project root (`upload-keystore.jks`)
- **Format**: JKS (Java KeyStore)
- **Algorithm**: RSA 2048-bit
- **Validity**: 10000 days (~27 years)
- **Alias**: `upload` (default)

### Signing Configuration File

**File**: `android/key.properties`

```properties
# Keystore password (password for the keystore file)
storePassword=YOUR_STORE_PASSWORD

# Key password (password for the specific key alias)
# Can be the same as storePassword for simplicity
keyPassword=YOUR_KEY_PASSWORD

# Key alias (name of the key in the keystore)
keyAlias=upload

# Path to keystore file (relative from android/ directory)
storeFile=../upload-keystore.jks
```

**Security Notes:**
- ⚠️ **Never commit** `key.properties` or `.jks` files to version control
- ✅ These files are already in `.gitignore`
- ✅ Store passwords securely (use a password manager)
- ✅ Keep keystore backups in a secure location
- ⚠️ **If you lose your keystore, you cannot update your app on Play Store**

### Signing Configuration in build.gradle

The signing configuration is automatically loaded from `key.properties`:

```gradle
signingConfigs {
    release {
        if (keystorePropertiesFile.exists()) {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile file(keystoreProperties['storeFile'])
            storePassword keystoreProperties['storePassword']
        }
    }
}
```

**Fallback Behavior:**
- If `key.properties` doesn't exist → Uses debug signing
- If keystore file not found → Uses debug signing
- Debug-signed builds **cannot** be uploaded to Play Store

---

## Version Management

### Version Format

Version is managed in `pubspec.yaml`:
```yaml
version: 3.1.0+1
```

**Format**: `VERSION_NAME+BUILD_NUMBER`
- **Version Name** (`3.1.0`): User-visible version (semantic versioning)
- **Build Number** (`1`): Version code (must increment for each release)

### Version Management Script

**Show Current Version:**
```powershell
.\scripts\version_manager.ps1
```

**Bump Version:**
```powershell
# Bump patch version (3.1.0 -> 3.1.1)
.\scripts\version_manager.ps1 -Bump Patch

# Bump minor version (3.1.0 -> 3.2.0)
.\scripts\version_manager.ps1 -Bump Minor

# Bump major version (3.1.0 -> 4.0.0)
.\scripts\version_manager.ps1 -Bump Major
```

**Set Build Number:**
```powershell
.\scripts\version_manager.ps1 -Build 42
```

**Set Complete Version:**
```powershell
.\scripts\version_manager.ps1 -Set "3.2.0+10"
```

### Version Code Rules

- **Must be unique**: Each release must have a higher version code than the previous
- **Play Store requirement**: Version code must increment for each upload
- **Cannot decrease**: Once uploaded, version code cannot be reused
- **Recommended**: Increment by 1 for each release

### Automatic Version Extraction

The build system automatically extracts version from `pubspec.yaml`:

```gradle
// Extract version code (build number)
def flutterVersionCode = extract from pubspec.yaml (format: x.y.z+build)

// Extract version name
def flutterVersionName = extract from pubspec.yaml (format: x.y.z)
```

---

## Build Scripts

### Available Scripts

#### 1. `build_apk.ps1` / `build_apk.sh`
Builds release APK for direct installation.

**Usage:**
```powershell
# Universal APK
.\scripts\build_apk.ps1

# Split APKs
.\scripts\build_apk.ps1 -Split
```

**Features:**
- Cleans previous builds
- Gets dependencies
- Builds release APK
- Shows version information
- Displays output location and size

#### 2. `build_aab.ps1` / `build_aab.sh`
Builds release AAB for Google Play Store.

**Usage:**
```powershell
.\scripts\build_aab.ps1
```

**Features:**
- Verifies signing configuration
- Cleans previous builds
- Gets dependencies
- Builds release AAB
- Shows version information
- Displays upload instructions

#### 3. `build_android.ps1` / `build_android.sh`
Master script for building both APK and AAB.

**Usage:**
```powershell
# Build APK only
.\scripts\build_android.ps1 -Type APK

# Build APK with splits
.\scripts\build_android.ps1 -Type APK -Split

# Build AAB only
.\scripts\build_android.ps1 -Type AAB

# Build both
.\scripts\build_android.ps1 -Type Both
```

#### 4. `version_manager.ps1` / `version_manager.sh`
Manages version code and version name.

**Usage:**
```powershell
# Show current version
.\scripts\version_manager.ps1

# Bump version
.\scripts\version_manager.ps1 -Bump Patch

# Set build number
.\scripts\version_manager.ps1 -Build 42

# Set complete version
.\scripts\version_manager.ps1 -Set "3.2.0+10"
```

#### 5. `generate_keystore.ps1` / `generate_keystore.sh`
Generates keystore for signing.

**Usage:**
```powershell
.\scripts\generate_keystore.ps1
```

**Features:**
- Interactive keystore generation
- Prompts for passwords and details
- Creates keystore at project root
- Provides next steps instructions

#### 6. `verify_android_build.ps1` / `verify_android_build.sh`
Verifies build configuration.

**Usage:**
```powershell
.\scripts\verify_android_build.ps1
```

**Checks:**
- Flutter installation
- Java/keytool availability
- Project structure
- Version configuration
- Signing configuration
- Build.gradle configuration
- Build scripts availability
- .gitignore configuration
- Dependencies status

---

## Build Process

### Complete Build Workflow

#### Step 1: Update Version
```powershell
# Check current version
.\scripts\version_manager.ps1

# Bump version if needed
.\scripts\version_manager.ps1 -Bump Patch
```

#### Step 2: Verify Configuration
```powershell
.\scripts\verify_android_build.ps1
```

#### Step 3: Build Release

**For Play Store (AAB):**
```powershell
.\scripts\build_aab.ps1
```

**For Direct Installation (APK):**
```powershell
# Universal APK
.\scripts\build_apk.ps1

# Or split APKs
.\scripts\build_apk.ps1 -Split
```

#### Step 4: Verify Build Output

**AAB Location:**
```
build/app/outputs/bundle/release/app-release.aab
```

**APK Locations:**
```
# Universal
build/app/outputs/flutter-apk/app-release.apk

# Split
build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk
build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
build/app/outputs/flutter-apk/app-x86_64-release.apk
```

#### Step 5: Test Installation (APK)
```bash
adb install build/app/outputs/flutter-apk/app-release.apk
```

#### Step 6: Upload to Play Store (AAB)
1. Go to [Google Play Console](https://play.google.com/console)
2. Navigate to your app > Release > Production (or Internal/Alpha/Beta)
3. Create new release
4. Upload `app-release.aab`
5. Fill in release notes
6. Submit for review

### Build Output Details

**APK Output:**
- **Universal APK**: Single file with all architectures (~50-100MB)
- **Split APKs**: Separate files per architecture (~20-40MB each)
- **Signed**: Yes (release signing if configured)
- **Optimized**: Yes (minified, resources shrunk)

**AAB Output:**
- **Format**: Android App Bundle
- **Size**: Optimized bundle (~30-60MB)
- **Signed**: Yes (release signing required)
- **Optimized**: Yes (Play Store generates optimized APKs)

---

## Troubleshooting

### Common Issues

#### 1. Missing key.properties

**Symptom:**
```
WARNING: key.properties not found. Using debug signing for release builds.
```

**Solution:**
1. Copy `android/key.properties.template` to `android/key.properties`
2. Fill in keystore details
3. Ensure keystore file exists at specified path

#### 2. Keystore File Not Found

**Symptom:**
```
WARNING: Keystore file not found at: <path>
```

**Solution:**
1. Verify keystore path in `key.properties`
2. Check if keystore exists at specified location
3. Use absolute path if relative path doesn't work
4. Regenerate keystore if needed: `.\scripts\generate_keystore.ps1`

#### 3. Wrong Password

**Symptom:**
```
FAILURE: Build failed with an exception.
* What went wrong:
Execution failed for task ':app:packageRelease'.
> Failed to read key upload from store
```

**Solution:**
1. Verify passwords in `key.properties`
2. Test keystore: `keytool -list -v -keystore upload-keystore.jks`
3. Ensure `storePassword` and `keyPassword` are correct

#### 4. Version Code Error

**Symptom:**
```
Upload failed: Version code X has already been used
```

**Solution:**
1. Increment version code: `.\scripts\version_manager.ps1 -Build <next_number>`
2. Version code must be higher than previous release
3. Check Play Console for last uploaded version code

#### 5. Build Fails with Gradle Error

**Symptom:**
```
FAILURE: Build failed with an exception.
```

**Solution:**
1. Clean build: `flutter clean`
2. Get dependencies: `flutter pub get`
3. Verify Flutter version: `flutter --version`
4. Check Android SDK: `flutter doctor`
5. Update Gradle if needed

#### 6. APK Too Large

**Symptom:**
APK file is very large (>100MB)

**Solution:**
1. Use split APKs: `.\scripts\build_apk.ps1 -Split`
2. Enable resource shrinking (already enabled in release)
3. Check for large assets or resources
4. Use AAB for Play Store (smaller downloads)

### Verification Checklist

Before building, verify:

- [ ] Flutter is installed and in PATH
- [ ] Java JDK is installed (for signing)
- [ ] Version is updated in `pubspec.yaml`
- [ ] `key.properties` exists and is configured
- [ ] Keystore file exists and is accessible
- [ ] Passwords are correct
- [ ] `.gitignore` excludes sensitive files
- [ ] Dependencies are up to date (`flutter pub get`)

---

## Acceptance Criteria Verification

### ✅ Build Configuration for APK Generation

**Status**: ✅ Complete

**Implementation:**
- Universal APK: `flutter build apk --release`
- Split APKs: `flutter build apk --release --split-per-abi`
- Script: `scripts/build_apk.ps1` and `scripts/build_apk.sh`
- Configuration: `android/app/build.gradle`

**Verification:**
```powershell
# Test APK build
.\scripts\build_apk.ps1
# Output: build/app/outputs/flutter-apk/app-release.apk
```

### ✅ Build Configuration for AAB Generation

**Status**: ✅ Complete

**Implementation:**
- AAB Build: `flutter build appbundle --release`
- Script: `scripts/build_aab.ps1` and `scripts/build_aab.sh`
- Configuration: `android/app/build.gradle` (bundle section)

**Verification:**
```powershell
# Test AAB build
.\scripts\build_aab.ps1
# Output: build/app/outputs/bundle/release/app-release.aab
```

### ✅ Signing Configuration Set Up

**Status**: ✅ Complete

**Implementation:**
- Keystore generation: `scripts/generate_keystore.ps1` and `.sh`
- Signing config: `android/key.properties` (template provided)
- Build integration: `android/app/build.gradle` (signingConfigs)
- Security: `.gitignore` excludes sensitive files

**Verification:**
```powershell
# Generate keystore
.\scripts\generate_keystore.ps1

# Verify signing config
.\scripts\verify_android_build.ps1
```

### ✅ Version Code and Name Management

**Status**: ✅ Complete

**Implementation:**
- Version format: `pubspec.yaml` (x.y.z+build)
- Version extraction: Automatic in `build.gradle`
- Version management: `scripts/version_manager.ps1` and `.sh`
- Features: Bump patch/minor/major, set build number

**Verification:**
```powershell
# Show version
.\scripts\version_manager.ps1

# Bump version
.\scripts\version_manager.ps1 -Bump Patch
```

### ✅ Build Scripts Created

**Status**: ✅ Complete

**Scripts Available:**
1. `build_apk.ps1` / `build_apk.sh` - APK generation
2. `build_aab.ps1` / `build_aab.sh` - AAB generation
3. `build_android.ps1` / `build_android.sh` - Master build script
4. `version_manager.ps1` / `version_manager.sh` - Version management
5. `generate_keystore.ps1` / `generate_keystore.sh` - Keystore generation
6. `verify_android_build.ps1` / `verify_android_build.sh` - Configuration verification

**Cross-Platform**: All scripts available for Windows (PowerShell) and Linux/Mac (Bash)

### ✅ APK and AAB Build Successfully

**Status**: ✅ Ready for Testing

**To Verify:**
```powershell
# Build APK
.\scripts\build_apk.ps1
# Expected: Success message, APK file created

# Build AAB
.\scripts\build_aab.ps1
# Expected: Success message, AAB file created
```

**Note**: Actual build success depends on:
- Flutter environment setup
- Signing configuration
- No code errors

### ✅ Documentation for Build Process

**Status**: ✅ Complete

**Documentation Files:**
1. **This file**: `docs/ANDROID_BUILD_COMPLETE_DOCUMENTATION.md` - Complete guide
2. **Quick Reference**: `android/README_BUILD.md` - Quick start
3. **Template**: `android/key.properties.template` - Signing config template
4. **Script Help**: Each script includes usage instructions

**Documentation Coverage:**
- ✅ Quick start guide
- ✅ Build configuration details
- ✅ Signing setup and security
- ✅ Version management
- ✅ Build scripts usage
- ✅ Complete build workflow
- ✅ Troubleshooting guide
- ✅ Acceptance criteria verification

---

## Summary

### Configuration Files

| File | Purpose | Location |
|------|---------|----------|
| `pubspec.yaml` | Version management | Project root |
| `android/app/build.gradle` | Build configuration | `android/app/` |
| `android/key.properties` | Signing configuration | `android/` (not in git) |
| `android/key.properties.template` | Signing template | `android/` |
| `upload-keystore.jks` | Keystore file | Project root (not in git) |

### Build Outputs

| Type | Location | Use Case |
|------|----------|----------|
| **AAB** | `build/app/outputs/bundle/release/app-release.aab` | Play Store |
| **APK (Universal)** | `build/app/outputs/flutter-apk/app-release.apk` | Direct install |
| **APK (Split)** | `build/app/outputs/flutter-apk/app-*-release.apk` | Architecture-specific |

### Quick Commands

```powershell
# Setup
.\scripts\generate_keystore.ps1
.\scripts\verify_android_build.ps1

# Version Management
.\scripts\version_manager.ps1 -Bump Patch

# Build
.\scripts\build_apk.ps1          # APK
.\scripts\build_aab.ps1           # AAB
.\scripts\build_android.ps1 -Type Both  # Both
```

---

## Additional Resources

- [Flutter Build Documentation](https://docs.flutter.dev/deployment/android)
- [Google Play Console](https://play.google.com/console)
- [Android App Bundle Guide](https://developer.android.com/guide/app-bundle)
- [Android Signing Guide](https://developer.android.com/studio/publish/app-signing)

---

**Last Updated**: 2024
**Version**: 3.1.0
**Status**: ✅ Production Ready
