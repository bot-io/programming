# Android Build and Signing Configuration Guide

This guide covers the complete setup for building and signing Android APK and AAB files for the Dual Reader 3.1 application.

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Signing Configuration](#signing-configuration)
4. [Version Management](#version-management)
5. [Building APK](#building-apk)
6. [Building AAB](#building-aab)
7. [Build Scripts](#build-scripts)
8. [Troubleshooting](#troubleshooting)
9. [Best Practices](#best-practices)

## Overview

The Android build system supports:
- **APK Generation**: For direct installation on Android devices
  - Universal APK (all architectures in one file)
  - Split APKs (separate APK per architecture for smaller downloads)
- **AAB Generation**: Android App Bundle for Google Play Store distribution
- **Signing**: Release signing configuration for Play Store uploads
- **Version Management**: Automatic version code and name management

## Prerequisites

### Required Tools

1. **Flutter SDK** (latest stable version)
   ```bash
   flutter --version
   ```

2. **Java JDK** (for keystore generation and signing)
   ```bash
   java -version
   keytool -help
   ```

3. **Android SDK** (installed with Flutter)
   - Minimum SDK: API 21 (Android 5.0)
   - Target SDK: API 34 (Android 14)

### Verify Installation

Run the verification script:
```powershell
# Windows
.\scripts\verify_android_build.ps1

# Linux/Mac
./scripts/verify_android_build.sh
```

## Signing Configuration

### Why Signing is Required

- **Debug builds**: Automatically signed with debug keystore (not for distribution)
- **Release builds**: Must be signed with a release keystore for:
  - Google Play Store uploads
  - Direct APK installation
  - App updates (must use same keystore)

### Step 1: Generate a Keystore

#### Option A: Using the Script (Recommended)

**Windows:**
```powershell
.\scripts\generate_keystore.ps1
```

**Linux/Mac:**
```bash
./scripts/generate_keystore.sh
```

The script will:
- Prompt for keystore password
- Prompt for key password (can be same as keystore password)
- Prompt for your name and organization details
- Create `upload-keystore.jks` in the project root

#### Option B: Manual Generation

```bash
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

**Parameters:**
- `-keystore`: Keystore file name (typically `upload-keystore.jks`)
- `-keyalg`: Key algorithm (RSA recommended)
- `-keysize`: Key size (2048 bits minimum)
- `-validity`: Validity in days (10000 = ~27 years)
- `-alias`: Key alias (typically "upload")

### Step 2: Configure Signing Properties

1. **Copy the template:**
   ```bash
   # Windows
   copy android\key.properties.template android\key.properties
   
   # Linux/Mac
   cp android/key.properties.template android/key.properties
   ```

2. **Edit `android/key.properties`:**
   ```properties
   storeFile=../upload-keystore.jks
   storePassword=YOUR_STORE_PASSWORD
   keyAlias=upload
   keyPassword=YOUR_KEY_PASSWORD
   ```

   **Important:**
   - Replace `YOUR_STORE_PASSWORD` with your keystore password
   - Replace `YOUR_KEY_PASSWORD` with your key password
   - The `storeFile` path is relative to `android/` directory
   - Use absolute path if keystore is stored elsewhere

### Step 3: Verify Signing Configuration

The build system will automatically:
- Load `key.properties` if it exists
- Use release signing for release builds
- Fall back to debug signing if `key.properties` is missing (with warnings)

**Security Notes:**
- ✅ `key.properties` and `*.jks` files are in `.gitignore`
- ✅ Never commit keystore files or passwords to version control
- ✅ Back up your keystore file securely
- ✅ Store passwords in a secure password manager
- ⚠️ If you lose your keystore, you cannot update your app on Play Store

## Version Management

### Version Format

Versions are managed in `pubspec.yaml`:
```yaml
version: 3.1.0+1
```

Format: `VERSION_NAME+BUILD_NUMBER`
- **Version Name** (`3.1.0`): User-visible version (major.minor.patch)
- **Build Number** (`1`): Version code for Play Store (must increment)

### Version Management Script

**Show current version:**
```powershell
.\scripts\version_manager.ps1
```

**Bump version:**
```powershell
# Bump patch version (3.1.0 -> 3.1.1)
.\scripts\version_manager.ps1 -Bump Patch

# Bump minor version (3.1.0 -> 3.2.0)
.\scripts\version_manager.ps1 -Bump Minor

# Bump major version (3.1.0 -> 4.0.0)
.\scripts\version_manager.ps1 -Bump Major
```

**Set build number:**
```powershell
.\scripts\version_manager.ps1 -Build 42
```

**Set complete version:**
```powershell
.\scripts\version_manager.ps1 -Set "3.2.0+42"
```

### Automatic Version Extraction

The `build.gradle` automatically extracts version from `pubspec.yaml`:
- Version code = Build number
- Version name = Version name

No manual editing of `build.gradle` needed!

## Building APK

### Universal APK (All Architectures)

**Using script:**
```powershell
# Windows
.\scripts\build_apk.ps1

# Linux/Mac
./scripts/build_apk.sh
```

**Using Flutter CLI:**
```bash
flutter build apk --release
```

**Output:**
- Location: `build/app/outputs/flutter-apk/app-release.apk`
- Size: ~50-100 MB (includes all architectures)
- Use case: Direct installation, testing

### Split APKs (Per Architecture)

**Using script:**
```powershell
# Windows
.\scripts\build_apk.ps1 -Split

# Linux/Mac
./scripts/build_apk.sh --split
```

**Using Flutter CLI:**
```bash
flutter build apk --release --split-per-abi
```

**Output:**
- `app-armeabi-v7a-release.apk` (32-bit ARM, ~20-30 MB)
- `app-arm64-v8a-release.apk` (64-bit ARM, ~25-35 MB)
- `app-x86_64-release.apk` (64-bit x86, ~25-35 MB)

**Use case:**
- Smaller downloads per device
- Users only download their architecture
- Not suitable for Play Store (use AAB instead)

### Installing APK

**Via ADB:**
```bash
# Universal APK
adb install build/app/outputs/flutter-apk/app-release.apk

# Split APK (choose correct architecture)
adb install build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

**Via Device:**
1. Transfer APK to device
2. Enable "Install from Unknown Sources" in settings
3. Open APK file and install

## Building AAB

### Android App Bundle (Play Store)

**Using script:**
```powershell
# Windows
.\scripts\build_aab.ps1

# Linux/Mac
./scripts/build_aab.sh
```

**Using Flutter CLI:**
```bash
flutter build appbundle --release
```

**Output:**
- Location: `build/app/outputs/bundle/release/app-release.aab`
- Size: ~30-50 MB (optimized bundle)
- Use case: Google Play Store uploads only

### Uploading to Play Store

1. **Go to Google Play Console:**
   - https://play.google.com/console

2. **Navigate to your app:**
   - Select your app
   - Go to Release > Production (or Internal/Alpha/Beta)

3. **Create new release:**
   - Click "Create new release"
   - Upload `app-release.aab`
   - Fill in release notes
   - Review and submit

**Important:**
- AAB is the only format accepted by Play Store (since August 2021)
- Google generates optimized APKs per device from AAB
- Version code must be higher than previous release

## Build Scripts

### Available Scripts

| Script | Purpose | Platform |
|--------|---------|----------|
| `build_apk.ps1` / `build_apk.sh` | Build APK (universal or split) | Both |
| `build_aab.ps1` / `build_aab.sh` | Build AAB for Play Store | Both |
| `build_android.ps1` / `build_android.sh` | Master script (build APK/AAB/Both) | Both |
| `version_manager.ps1` / `version_manager.sh` | Manage version numbers | Both |
| `generate_keystore.ps1` / `generate_keystore.sh` | Generate signing keystore | Both |
| `verify_android_build.ps1` / `verify_android_build.sh` | Verify build configuration | Both |

### Master Build Script

Build both APK and AAB:
```powershell
.\scripts\build_android.ps1 -Type Both
```

Build only APK:
```powershell
.\scripts\build_android.ps1 -Type APK
```

Build only AAB:
```powershell
.\scripts\build_android.ps1 -Type AAB
```

Build split APKs:
```powershell
.\scripts\build_android.ps1 -Type APK -Split
```

## Troubleshooting

### Common Issues

#### 1. "key.properties not found"

**Symptom:** Build succeeds but uses debug signing

**Solution:**
```bash
# Copy template
cp android/key.properties.template android/key.properties

# Edit and fill in your keystore details
# Or generate new keystore
.\scripts\generate_keystore.ps1
```

#### 2. "Keystore file not found"

**Symptom:** Warning about missing keystore file

**Solution:**
- Check `storeFile` path in `key.properties`
- Use relative path: `../upload-keystore.jks`
- Or absolute path: `C:/path/to/upload-keystore.jks`
- Ensure keystore file exists at specified location

#### 3. "Invalid keystore password"

**Symptom:** Build fails with password error

**Solution:**
- Verify passwords in `key.properties` match keystore
- Check for extra spaces or special characters
- Regenerate keystore if password is lost

#### 4. "Version code must be higher"

**Symptom:** Play Store rejects upload

**Solution:**
```powershell
# Increment build number
.\scripts\version_manager.ps1 -Build 2
```

#### 5. "Build failed: Gradle error"

**Symptom:** Build fails with Gradle errors

**Solution:**
```bash
# Clean build
flutter clean
flutter pub get

# Check Flutter and Android SDK versions
flutter doctor -v

# Verify build.gradle syntax
```

#### 6. "AAB too large"

**Symptom:** AAB exceeds Play Store size limits

**Solution:**
- Enable code shrinking (already enabled in `build.gradle`)
- Enable resource shrinking (already enabled)
- Review assets and remove unused resources
- Use split APKs for direct distribution (not Play Store)

### Build Verification

Always verify your build configuration:
```powershell
.\scripts\verify_android_build.ps1
```

This checks:
- ✅ Flutter installation
- ✅ Java/keytool availability
- ✅ Project structure
- ✅ Version configuration
- ✅ Signing configuration
- ✅ Build.gradle setup
- ✅ Build scripts availability
- ✅ .gitignore configuration
- ✅ Dependencies

## Best Practices

### 1. Version Management

- ✅ Always increment build number for Play Store releases
- ✅ Use semantic versioning (major.minor.patch)
- ✅ Use version manager script for consistency
- ❌ Don't manually edit version in multiple places

### 2. Signing Security

- ✅ Store keystore in secure location (not in project)
- ✅ Back up keystore file (losing it = cannot update app)
- ✅ Use strong passwords (20+ characters)
- ✅ Never commit keystore or passwords to git
- ✅ Use password manager for credentials
- ✅ Rotate keystore if compromised

### 3. Build Process

- ✅ Always verify configuration before building
- ✅ Test APK on device before uploading AAB
- ✅ Use release builds for distribution (not debug)
- ✅ Clean build before release: `flutter clean`
- ✅ Check build output sizes

### 4. Play Store Uploads

- ✅ Use AAB format (required by Play Store)
- ✅ Test AAB using Play Console's internal testing
- ✅ Increment version code for each upload
- ✅ Write clear release notes
- ✅ Test on multiple devices/Android versions

### 5. File Management

- ✅ Keep build outputs organized
- ✅ Archive old builds for reference
- ✅ Document version changes
- ✅ Tag git releases with version numbers

## Build Configuration Details

### build.gradle Features

The `android/app/build.gradle` includes:

1. **Automatic Version Extraction**
   - Reads version from `pubspec.yaml`
   - No manual version code/name editing needed

2. **Signing Configuration**
   - Loads from `key.properties`
   - Graceful fallback to debug signing
   - Supports relative and absolute keystore paths

3. **Build Types**
   - **Debug**: Debug signing, debuggable, no minification
   - **Release**: Release signing, minified, optimized

4. **Code Optimization**
   - ProGuard rules for code shrinking
   - Resource shrinking enabled
   - Obfuscation for release builds

5. **APK/AAB Configuration**
   - Universal APK support
   - Split APK support (per ABI)
   - AAB bundle configuration
   - ABI splitting for smaller downloads

### ProGuard Rules

Located in `android/app/proguard-rules.pro`:
- Flutter classes preserved
- Custom app classes preserved
- Logging removed in release builds
- Line numbers preserved for debugging

## Quick Reference

### Build Commands

```bash
# Verify configuration
.\scripts\verify_android_build.ps1

# Build universal APK
.\scripts\build_apk.ps1

# Build split APKs
.\scripts\build_apk.ps1 -Split

# Build AAB
.\scripts\build_aab.ps1

# Build both
.\scripts\build_android.ps1 -Type Both

# Manage version
.\scripts\version_manager.ps1 -Bump Patch
```

### File Locations

```
project-root/
├── android/
│   ├── key.properties          # Signing config (not in git)
│   ├── key.properties.template  # Template (in git)
│   └── app/
│       └── build.gradle         # Build configuration
├── upload-keystore.jks          # Keystore (not in git)
├── build/
│   └── app/
│       └── outputs/
│           ├── flutter-apk/     # APK outputs
│           └── bundle/           # AAB outputs
└── scripts/                     # Build scripts
```

## Additional Resources

- [Flutter Android Build Documentation](https://docs.flutter.dev/deployment/android)
- [Google Play Console](https://play.google.com/console)
- [Android App Signing](https://developer.android.com/studio/publish/app-signing)
- [Android App Bundle](https://developer.android.com/guide/app-bundle)

---

**Last Updated:** 2024
**Project:** Dual Reader 3.1
**Maintainer:** AI Dev Team
