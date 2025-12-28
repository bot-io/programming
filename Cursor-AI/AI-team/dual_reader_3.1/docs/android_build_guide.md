# Android Build and Signing Guide

This guide provides comprehensive instructions for building and signing Android APK and AAB files for the Dual Reader 3.1 application.

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Initial Setup](#initial-setup)
4. [Signing Configuration](#signing-configuration)
5. [Version Management](#version-management)
6. [Building APK](#building-apk)
7. [Building AAB](#building-aab)
8. [Build Verification](#build-verification)
9. [Troubleshooting](#troubleshooting)
10. [Best Practices](#best-practices)

## Overview

The Android build system supports two distribution formats:

- **APK (Android Package)**: Direct installation format for testing or distribution outside Play Store
  - Universal APK: Single file with all architectures (larger size)
  - Split APK: Separate files per architecture (smaller downloads)
  
- **AAB (Android App Bundle)**: Optimized format for Google Play Store
  - Google generates optimized APKs per device
  - Smaller download sizes for users
  - Required for Play Store distribution

## Prerequisites

Before building, ensure you have:

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

4. **Project Dependencies**
   ```bash
   flutter pub get
   ```

## Initial Setup

### 1. Verify Build Configuration

Run the verification script to check your setup:

**Windows (PowerShell):**
```powershell
.\scripts\verify_android_build.ps1
```

**Linux/Mac:**
```bash
./scripts/verify_android_build.sh
```

This will check:
- Flutter installation
- Java/keytool availability
- Project structure
- Version configuration
- Signing configuration
- Build scripts
- Dependencies

### 2. Project Structure

Ensure your project has the following structure:

```
dual_reader_3.1/
├── android/
│   ├── app/
│   │   ├── build.gradle          # App build configuration
│   │   ├── proguard-rules.pro    # ProGuard rules
│   │   └── src/main/
│   │       └── AndroidManifest.xml
│   ├── build.gradle              # Project build configuration
│   ├── gradle.properties         # Gradle properties
│   └── key.properties.template    # Signing template
├── scripts/
│   ├── build_apk.ps1 / .sh       # APK build script
│   ├── build_aab.ps1 / .sh       # AAB build script
│   ├── build_android.ps1 / .sh   # Master build script
│   ├── generate_keystore.ps1 / .sh
│   ├── version_manager.ps1 / .sh
│   └── verify_android_build.ps1 / .sh
└── pubspec.yaml                  # Version info
```

## Signing Configuration

### Why Signing is Required

- **Release builds** must be signed for Play Store distribution
- **Debug builds** are automatically signed with debug keys
- **Keystore** contains your signing keys (keep secure!)

### Option 1: Generate New Keystore (Recommended)

**Windows (PowerShell):**
```powershell
.\scripts\generate_keystore.ps1
```

**Linux/Mac:**
```bash
./scripts/generate_keystore.sh
```

Follow the prompts to:
1. Enter keystore password (store securely!)
2. Enter key password (can be same as keystore)
3. Enter your details (name, organization, etc.)

This creates `upload-keystore.jks` in the project root.

### Option 2: Use Existing Keystore

If you already have a keystore:

1. Copy `android/key.properties.template` to `android/key.properties`
2. Edit `android/key.properties`:
   ```properties
   storePassword=YOUR_STORE_PASSWORD
   keyPassword=YOUR_KEY_PASSWORD
   keyAlias=upload
   storeFile=../upload-keystore.jks
   ```

### Security Best Practices

- ✅ **DO** keep keystore and passwords secure
- ✅ **DO** backup keystore in secure location
- ✅ **DO** use password manager for passwords
- ❌ **DON'T** commit `key.properties` or `.jks` files
- ❌ **DON'T** share keystore with others
- ❌ **DON'T** lose your keystore (you can't update Play Store app!)

## Version Management

### Version Format

Versions are managed in `pubspec.yaml`:
```yaml
version: 3.1.0+1
#        ^^^^^ ^
#        |     |
#        |     +-- Build number (versionCode)
#        +-------- Version name (versionName)
```

- **Version Name** (3.1.0): User-visible version (major.minor.patch)
- **Build Number** (+1): Internal version code (must increment for each release)

### Managing Versions

**Show current version:**
```powershell
.\scripts\version_manager.ps1
```

**Bump patch version** (3.1.0 → 3.1.1):
```powershell
.\scripts\version_manager.ps1 -Bump Patch
```

**Bump minor version** (3.1.0 → 3.2.0):
```powershell
.\scripts\version_manager.ps1 -Bump Minor
```

**Bump major version** (3.1.0 → 4.0.0):
```powershell
.\scripts\version_manager.ps1 -Bump Major
```

**Set build number:**
```powershell
.\scripts\version_manager.ps1 -Build 42
```

**Set specific version:**
```powershell
.\scripts\version_manager.ps1 -Set "3.2.0+10"
```

### Version Code Rules

- Must be **unique** and **incrementing** for each Play Store release
- Cannot decrease (Play Store rejects lower version codes)
- Automatically extracted from `pubspec.yaml` build number

## Building APK

APK files are used for direct installation (testing, side-loading, or distribution outside Play Store).

### Universal APK (All Architectures)

Single APK containing all architectures (arm64-v8a, armeabi-v7a, x86_64):

**Windows (PowerShell):**
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

**Output:** `build/app/outputs/flutter-apk/app-release.apk`

**Pros:**
- Single file to distribute
- Works on all devices

**Cons:**
- Larger file size (~50-100 MB)

### Split APK (Per Architecture)

Separate APKs per architecture (smaller downloads):

**Windows (PowerShell):**
```powershell
.\scripts\build_apk.ps1 -Split
```

**Linux/Mac:**
```bash
./scripts/build_apk.sh --split
```

**Output:**
- `build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk` (32-bit ARM)
- `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` (64-bit ARM)
- `build/app/outputs/flutter-apk/app-x86_64-release.apk` (64-bit x86)

**Pros:**
- Smaller file sizes (~20-40 MB each)
- Users download only their architecture

**Cons:**
- Multiple files to manage
- Need to identify device architecture

### Installing APK

**Via ADB:**
```bash
# Universal APK
adb install build/app/outputs/flutter-apk/app-release.apk

# Split APK (use appropriate architecture)
adb install build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

**Via Device:**
1. Transfer APK to device
2. Enable "Install from Unknown Sources" in settings
3. Open APK file and install

## Building AAB

AAB (Android App Bundle) is the **required format** for Google Play Store distribution.

### Build AAB

**Windows (PowerShell):**
```powershell
.\scripts\build_aab.ps1
```

**Linux/Mac:**
```bash
./scripts/build_aab.sh
```

**Output:** `build/app/outputs/bundle/release/app-release.aab`

### Uploading to Play Store

1. Go to [Google Play Console](https://play.google.com/console)
2. Select your app
3. Navigate to **Release** → **Production** (or Internal/Alpha/Beta)
4. Click **Create new release**
5. Upload `app-release.aab`
6. Fill in release notes
7. Review and submit

### AAB Benefits

- ✅ Smaller download sizes (Google optimizes per device)
- ✅ Automatic APK generation per device architecture
- ✅ Required for Play Store
- ✅ Better compression and optimization

## Build Verification

### Pre-Build Verification

Before building, verify your configuration:

```powershell
.\scripts\verify_android_build.ps1
```

This checks:
- ✅ Flutter installation
- ✅ Java/keytool availability
- ✅ Project structure
- ✅ Version configuration
- ✅ Signing configuration
- ✅ Build scripts
- ✅ Dependencies

### Post-Build Verification

After building, verify the output:

**Check APK:**
```bash
# List APK contents
unzip -l build/app/outputs/flutter-apk/app-release.apk

# Check signing
jarsigner -verify -verbose -certs build/app/outputs/flutter-apk/app-release.apk
```

**Check AAB:**
```bash
# List AAB contents
unzip -l build/app/outputs/bundle/release/app-release.aab

# Check signing
jarsigner -verify -verbose -certs build/app/outputs/bundle/release/app-release.aab
```

**Check version:**
```bash
# Extract version from APK/AAB
aapt dump badging build/app/outputs/flutter-apk/app-release.apk | grep version
```

## Troubleshooting

### Common Issues

#### 1. "key.properties not found"

**Problem:** Build uses debug signing (not suitable for Play Store)

**Solution:**
```powershell
# Generate keystore
.\scripts\generate_keystore.ps1

# Create key.properties
Copy-Item android\key.properties.template android\key.properties
# Then edit android/key.properties with your keystore details
```

#### 2. "Keystore file not found"

**Problem:** `key.properties` references non-existent keystore

**Solution:**
- Check `storeFile` path in `android/key.properties`
- Use relative path: `../upload-keystore.jks`
- Or absolute path: `C:/path/to/keystore.jks`

#### 3. "Version code must be incremented"

**Problem:** Play Store rejects same or lower version code

**Solution:**
```powershell
# Increment build number
.\scripts\version_manager.ps1 -Build 2
```

#### 4. "Build failed: Gradle error"

**Problem:** Gradle build errors

**Solution:**
```bash
# Clean build
flutter clean
flutter pub get

# Check Gradle version
cd android
./gradlew --version

# Try building again
cd ..
flutter build apk --release
```

#### 5. "Out of memory during build"

**Problem:** Gradle runs out of memory

**Solution:** Edit `android/gradle.properties`:
```properties
org.gradle.jvmargs=-Xmx4096M -XX:MaxMetaspaceSize=1024m
```

#### 6. "Signing config error"

**Problem:** Incorrect signing configuration

**Solution:**
- Verify `android/key.properties` exists
- Check keystore file path is correct
- Verify passwords are correct
- Ensure keystore alias matches `keyAlias`

### Debug Builds

For testing, use debug builds (automatically signed):

```bash
flutter build apk --debug
flutter build appbundle --debug
```

Debug builds:
- ✅ Faster builds
- ✅ Include debug symbols
- ✅ No signing required
- ❌ Cannot upload to Play Store
- ❌ Larger file sizes

## Best Practices

### Build Process

1. **Always verify before building:**
   ```powershell
   .\scripts\verify_android_build.ps1
   ```

2. **Increment version before release:**
   ```powershell
   .\scripts\version_manager.ps1 -Bump Patch
   ```

3. **Test on real devices** before release

4. **Use AAB for Play Store**, APK for direct distribution

5. **Keep keystore secure** and backed up

### Version Management

- **Semantic versioning:** major.minor.patch
- **Build number:** Always increment for releases
- **Version code:** Must be unique and incrementing

### Signing

- **One keystore per app:** Don't reuse across apps
- **Secure storage:** Use password manager
- **Backup keystore:** Store in secure location
- **Never commit:** Keep out of version control

### Performance

- **Use split APKs** for smaller downloads
- **Enable R8/ProGuard** for release builds (already configured)
- **Test on multiple devices** and architectures

### Security

- **Never commit** `key.properties` or `.jks` files
- **Use strong passwords** for keystore
- **Rotate keys** if compromised (requires new app listing)
- **Keep keystore safe** (loss = cannot update app)

## Quick Reference

### Build Commands

```powershell
# Verify configuration
.\scripts\verify_android_build.ps1

# Build universal APK
.\scripts\build_apk.ps1

# Build split APKs
.\scripts\build_apk.ps1 -Split

# Build AAB
.\scripts\build_aab.ps1

# Build both APK and AAB
.\scripts\build_android.ps1 -Type Both

# Version management
.\scripts\version_manager.ps1 -Bump Patch
```

### File Locations

- **APK:** `build/app/outputs/flutter-apk/app-release.apk`
- **AAB:** `build/app/outputs/bundle/release/app-release.aab`
- **Keystore:** `upload-keystore.jks` (project root)
- **Signing Config:** `android/key.properties`
- **Version:** `pubspec.yaml`

### Version Format

```yaml
version: 3.1.0+1
#        ^^^^^ ^
#        |     +-- Build number (versionCode)
#        +-------- Version name (versionName)
```

## Additional Resources

- [Flutter Android Build Documentation](https://docs.flutter.dev/deployment/android)
- [Google Play App Signing](https://support.google.com/googleplay/android-developer/answer/9842756)
- [Android App Bundle Guide](https://developer.android.com/guide/app-bundle)
- [ProGuard Rules](https://developer.android.com/studio/build/shrink-code)

## Support

For issues or questions:
1. Check [Troubleshooting](#troubleshooting) section
2. Run verification script: `.\scripts\verify_android_build.ps1`
3. Review build logs for specific errors
4. Check Flutter documentation

---

**Last Updated:** 2024
**Flutter Version:** Latest Stable
**Android SDK:** API 21+ (Android 5.0+)
