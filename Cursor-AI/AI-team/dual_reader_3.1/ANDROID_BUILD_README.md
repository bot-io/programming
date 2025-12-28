# Android Build and Signing Guide

This guide covers the complete process of building and signing Android APK and AAB files for the Dual Reader app.

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

The Android build process supports two distribution formats:

- **APK (Android Package)**: Direct installation format
  - Universal APK: Single file with all architectures (larger size)
  - Split APK: Separate files per architecture (smaller downloads)
  
- **AAB (Android App Bundle)**: Google Play Store format (recommended)
  - Optimized format where Google generates APKs per device
  - Smaller download sizes for end users
  - Required for Play Store distribution

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

3. **Android SDK** (via Flutter)
   - Minimum SDK: 21 (Android 5.0)
   - Target SDK: 34
   - Compile SDK: 34

### Verify Installation

```bash
flutter doctor
```

Ensure all Android-related checks pass.

## Signing Configuration

### Why Signing is Required

- **Release builds** must be signed for distribution
- **Play Store** requires signed AAB files
- **APK updates** require the same signing key
- **Security** ensures app integrity

### Setting Up Signing

#### Step 1: Generate a Keystore

**Linux/Mac:**
```bash
./scripts/generate_keystore.sh
```

**Windows:**
```powershell
.\scripts\generate_keystore.ps1
```

This will:
- Create `upload-keystore.jks` in the project root
- Prompt for keystore password, key password, and organization details
- Generate a key valid for 10,000 days (~27 years)

**Manual Keystore Generation:**
```bash
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

#### Step 2: Configure key.properties

1. Copy the template:
   ```bash
   cp android/key.properties.template android/key.properties
   ```

2. Edit `android/key.properties` with your keystore details:
   ```properties
   storeFile=../upload-keystore.jks
   storePassword=your-keystore-password
   keyAlias=upload
   keyPassword=your-key-password
   ```

3. **IMPORTANT**: Never commit `key.properties` or keystore files to version control!

#### Step 3: Verify Configuration

The build scripts will automatically detect and use your signing configuration. If `key.properties` is missing, builds will use debug signing (not suitable for production).

### Keystore Security

- **Backup**: Store keystore backups in multiple secure locations
- **Passwords**: Use strong, unique passwords
- **Access**: Limit access to keystore files
- **Loss**: If keystore is lost, you cannot update your app on Play Store

## Version Management

### Version Format

Versions are managed in `pubspec.yaml`:
```yaml
version: 3.1.0+1
```

Format: `versionName+versionCode`
- **versionName** (3.1.0): User-visible version (major.minor.patch)
- **versionCode** (+1): Internal build number (must increment for each release)

### Version Management Scripts

**Linux/Mac:**
```bash
# Show current version
./scripts/version_manager.sh

# Bump patch version (3.1.0 -> 3.1.1)
./scripts/version_manager.sh bump patch

# Bump minor version (3.1.0 -> 3.2.0)
./scripts/version_manager.sh bump minor

# Bump major version (3.1.0 -> 4.0.0)
./scripts/version_manager.sh bump major

# Set build number
./scripts/version_manager.sh build 5

# Set complete version
./scripts/version_manager.sh set 3.2.0+10
```

**Windows:**
```powershell
# Show current version
.\scripts\version_manager.ps1

# Bump versions (same commands as Linux/Mac)
.\scripts\version_manager.ps1 bump patch
.\scripts\version_manager.ps1 build 5
.\scripts\version_manager.ps1 set 3.2.0+10
```

### Manual Version Update

Edit `pubspec.yaml`:
```yaml
version: 3.1.0+1  # Change to desired version
```

The build system automatically reads version from `pubspec.yaml`.

## Building APK

### Universal APK (All Architectures)

**Linux/Mac:**
```bash
./scripts/build_apk.sh
# or
./scripts/build_apk.sh --universal
```

**Windows:**
```powershell
.\scripts\build_apk.ps1
# or
.\scripts\build_apk.ps1 -Universal
```

**Output:** `build/app/outputs/flutter-apk/app-release.apk`

**Size:** ~50-100 MB (includes all architectures)

### Split APK (Per Architecture)

**Linux/Mac:**
```bash
./scripts/build_apk.sh --split
```

**Windows:**
```powershell
.\scripts\build_apk.ps1 -Split
```

**Output:** Multiple APKs in `build/app/outputs/flutter-apk/`:
- `app-armeabi-v7a-release.apk` (32-bit ARM)
- `app-arm64-v8a-release.apk` (64-bit ARM) - **Most common**
- `app-x86_64-release.apk` (64-bit x86)

**Size:** ~20-40 MB each (users download only their architecture)

### Direct Flutter Commands

```bash
# Universal APK
flutter build apk --release

# Split APK
flutter build apk --release --split-per-abi
```

### Installing APK

```bash
# Universal APK
adb install build/app/outputs/flutter-apk/app-release.apk

# Split APK (use appropriate architecture)
adb install build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

## Building AAB

### App Bundle for Play Store

**Linux/Mac:**
```bash
./scripts/build_aab.sh
```

**Windows:**
```powershell
.\scripts\build_aab.ps1
```

**Output:** `build/app/outputs/bundle/release/app-release.aab`

**Size:** ~30-60 MB (Google generates optimized APKs per device)

### Direct Flutter Command

```bash
flutter build appbundle --release
```

### Uploading to Play Store

1. Go to [Google Play Console](https://play.google.com/console)
2. Select your app
3. Navigate to **Release** > **Production** (or Internal/Alpha/Beta)
4. Click **Create new release**
5. Upload `app-release.aab`
6. Fill in release notes
7. Review and submit

## Build Scripts

### Available Scripts

| Script | Platform | Purpose |
|--------|----------|---------|
| `build_apk.sh` / `build_apk.ps1` | Both | Build release APK |
| `build_aab.sh` / `build_aab.ps1` | Both | Build release AAB |
| `generate_keystore.sh` / `generate_keystore.ps1` | Both | Generate signing keystore |
| `version_manager.sh` / `version_manager.ps1` | Both | Manage app version |

### Script Features

All build scripts:
- ✅ Check Flutter installation
- ✅ Verify signing configuration
- ✅ Clean previous builds
- ✅ Get dependencies
- ✅ Build release artifacts
- ✅ Display version information
- ✅ Show output locations

## Troubleshooting

### Common Issues

#### 1. "key.properties not found"

**Solution:**
- Copy `android/key.properties.template` to `android/key.properties`
- Fill in your keystore details
- Ensure keystore file path is correct

#### 2. "Keystore file not found"

**Solution:**
- Verify `storeFile` path in `key.properties`
- Use relative path: `../upload-keystore.jks`
- Or absolute path: `/full/path/to/upload-keystore.jks`

#### 3. "Wrong password"

**Solution:**
- Double-check passwords in `key.properties`
- Ensure no extra spaces or special characters
- Test keystore manually: `keytool -list -v -keystore upload-keystore.jks`

#### 4. "Version code must be incremented"

**Solution:**
- Increment build number in `pubspec.yaml`
- Use version manager: `./scripts/version_manager.sh build <number>`
- Each Play Store upload requires a higher version code

#### 5. Build fails with "Gradle error"

**Solution:**
```bash
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
flutter build apk --release
```

#### 6. "Out of memory" during build

**Solution:**
- Increase Gradle memory in `android/gradle.properties`:
  ```properties
  org.gradle.jvmargs=-Xmx4096m -XX:MaxMetaspaceSize=1024m
  ```

### Debugging Build Issues

1. **Check Flutter doctor:**
   ```bash
   flutter doctor -v
   ```

2. **Clean build:**
   ```bash
   flutter clean
   flutter pub get
   ```

3. **Build with verbose output:**
   ```bash
   flutter build apk --release --verbose
   ```

4. **Check Gradle logs:**
   ```bash
   cd android
   ./gradlew build --stacktrace
   ```

## Best Practices

### 1. Version Management

- ✅ Always increment version code for new releases
- ✅ Use semantic versioning (major.minor.patch)
- ✅ Keep version in sync across platforms

### 2. Signing

- ✅ Use release signing for production builds
- ✅ Keep keystore backups secure
- ✅ Never commit keystore or passwords
- ✅ Use strong passwords

### 3. Build Process

- ✅ Always test APK/AAB before distribution
- ✅ Use AAB for Play Store (smaller downloads)
- ✅ Use split APK for direct distribution (if needed)
- ✅ Clean build before release builds

### 4. Testing

- ✅ Test on multiple devices/emulators
- ✅ Test on different Android versions
- ✅ Verify signing before upload
- ✅ Test installation from APK

### 5. Play Store

- ✅ Use AAB format (required)
- ✅ Increment version code for each upload
- ✅ Test internal track before production
- ✅ Keep release notes updated

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

### Version Commands

```bash
# Show version
./scripts/version_manager.sh

# Bump patch
./scripts/version_manager.sh bump patch

# Set build number
./scripts/version_manager.sh build 10
```

### File Locations

- **APK (Universal):** `build/app/outputs/flutter-apk/app-release.apk`
- **APK (Split):** `build/app/outputs/flutter-apk/app-*-release.apk`
- **AAB:** `build/app/outputs/bundle/release/app-release.aab`
- **Keystore:** `upload-keystore.jks` (project root)
- **Signing Config:** `android/key.properties`

## Additional Resources

- [Flutter Build Documentation](https://docs.flutter.dev/deployment/android)
- [Android App Signing](https://developer.android.com/studio/publish/app-signing)
- [Google Play Console](https://play.google.com/console)
- [App Bundle Format](https://developer.android.com/guide/app-bundle)

---

**Last Updated:** 2024
**Flutter Version:** Latest Stable
**Minimum Android:** API 21 (Android 5.0)
**Target Android:** API 34
