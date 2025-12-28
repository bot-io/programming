# Android Build and Signing Configuration

Complete guide for building and signing Android releases for Dual Reader 3.1.

## 🚀 Quick Start

### 1. First-Time Setup

```powershell
# Generate keystore (Windows)
.\scripts\generate_keystore.ps1

# Or on Linux/Mac
./scripts/generate_keystore.sh
```

### 2. Configure Signing

```powershell
# Copy template
cp android/key.properties.template android/key.properties

# Edit android/key.properties with your keystore details
```

### 3. Verify Configuration

```powershell
.\scripts\verify_android_build.ps1
```

### 4. Build

```powershell
# Build APK for direct installation
.\scripts\build_apk.ps1

# Build AAB for Play Store
.\scripts\build_aab.ps1
```

---

## 📦 Build Types

### APK (Direct Installation)

**Universal APK** - Single file with all architectures:
```powershell
.\scripts\build_apk.ps1
# Output: build/app/outputs/flutter-apk/app-release.apk
```

**Split APKs** - Separate files per architecture (smaller downloads):
```powershell
.\scripts\build_apk.ps1 -Split
# Output: build/app/outputs/flutter-apk/app-*-release.apk
```

### AAB (Play Store)

**Android App Bundle** - Optimized for Google Play Store:
```powershell
.\scripts\build_aab.ps1
# Output: build/app/outputs/bundle/release/app-release.aab
```

---

## 🔐 Signing Configuration

### Generate Keystore

```powershell
.\scripts\generate_keystore.ps1
```

This creates `upload-keystore.jks` in the project root.

### Configure Signing

Create `android/key.properties`:

```properties
storeFile=../upload-keystore.jks
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
```

⚠️ **Never commit `key.properties` or keystore files to git!**

---

## 📝 Version Management

### Show Current Version

```powershell
.\scripts\version_manager.ps1
```

### Bump Version

```powershell
# Patch version (3.1.0 -> 3.1.1)
.\scripts\version_manager.ps1 -Bump Patch

# Minor version (3.1.0 -> 3.2.0)
.\scripts\version_manager.ps1 -Bump Minor

# Major version (3.1.0 -> 4.0.0)
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

Version format: `x.y.z+build` (e.g., `3.1.0+1`)

---

## 📁 File Locations

| File Type | Location |
|-----------|----------|
| **AAB** (Play Store) | `build/app/outputs/bundle/release/app-release.aab` |
| **APK** (Universal) | `build/app/outputs/flutter-apk/app-release.apk` |
| **APK** (Split) | `build/app/outputs/flutter-apk/app-*-release.apk` |
| **Keystore** | `upload-keystore.jks` (project root) |
| **Signing Config** | `android/key.properties` (not in git) |

---

## 🛠️ Build Scripts

### Windows (PowerShell)

- `scripts/build_apk.ps1` - Build APK
- `scripts/build_aab.ps1` - Build AAB
- `scripts/build_android.ps1` - Master build script
- `scripts/generate_keystore.ps1` - Generate keystore
- `scripts/version_manager.ps1` - Version management
- `scripts/verify_android_build.ps1` - Verify configuration

### Linux/Mac (Bash)

- `scripts/build_apk.sh` - Build APK
- `scripts/build_aab.sh` - Build AAB
- `scripts/build_android.sh` - Master build script
- `scripts/generate_keystore.sh` - Generate keystore
- `scripts/version_manager.sh` - Version management
- `scripts/verify_android_build.sh` - Verify configuration

---

## 📚 Documentation

- **[Quick Reference](BUILD_QUICK_REFERENCE.md)** - Command reference
- **[Quick Start](BUILD_QUICK_START.md)** - Getting started guide
- **[Complete Guide](../docs/ANDROID_BUILD_COMPLETE_GUIDE.md)** - Comprehensive documentation
- **[Acceptance Criteria](../ANDROID_BUILD_ACCEPTANCE_CRITERIA_COMPLETE.md)** - Verification checklist

---

## 🔍 Verification

Run the verification script to check your setup:

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
- ✅ Security settings

---

## ⚙️ Build Configuration

### Build Types

- **Debug**: Development builds with debug signing
- **Release**: Production builds with release signing (if configured)

### Release Build Features

- ✅ Code shrinking (minifyEnabled)
- ✅ Resource shrinking (shrinkResources)
- ✅ ProGuard obfuscation
- ✅ Multi-DEX support
- ✅ Vector drawables

### Supported Architectures

- `armeabi-v7a` (32-bit ARM)
- `arm64-v8a` (64-bit ARM)
- `x86_64` (64-bit x86)

---

## 🚨 Troubleshooting

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

---

## 🔒 Security Best Practices

1. ✅ **Never commit keystore files** - Already in `.gitignore`
2. ✅ **Never commit key.properties** - Already in `.gitignore`
3. ✅ **Backup keystore** - Store in secure location
4. ✅ **Use strong passwords** - For keystore and key
5. ✅ **Keep keystore safe** - Loss means you can't update app

---

## 📋 Common Commands

```powershell
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

---

## ✅ Acceptance Criteria Status

All acceptance criteria have been met:

- ✅ Build configuration for APK generation
- ✅ Build configuration for AAB generation
- ✅ Signing configuration set up
- ✅ Version code and name management
- ✅ Build scripts created
- ✅ APK and AAB build successfully
- ✅ Documentation for build process

See [Acceptance Criteria Verification](../ANDROID_BUILD_ACCEPTANCE_CRITERIA_COMPLETE.md) for details.

---

## 📞 Support

For issues or questions:
1. Check [Troubleshooting](#-troubleshooting) section
2. Run verification script: `.\scripts\verify_android_build.ps1`
3. Review [Complete Guide](../docs/ANDROID_BUILD_COMPLETE_GUIDE.md)

---

**Last Updated:** 2024  
**Status:** ✅ Production Ready
