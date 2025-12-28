# Android Build - Quick Reference

Quick reference guide for Android build commands and scripts.

## 🚀 Quick Start

```powershell
# 1. Generate keystore (first time only)
.\scripts\generate_keystore.ps1

# 2. Configure signing
cp android/key.properties.template android/key.properties
# Edit android/key.properties with your keystore details

# 3. Build APK
.\scripts\build_apk.ps1

# 4. Build AAB
.\scripts\build_aab.ps1
```

## 📦 Build Commands

### APK (Direct Installation)

**Universal APK:**
```powershell
.\scripts\build_apk.ps1
# Output: build/app/outputs/flutter-apk/app-release.apk
```

**Split APKs:**
```powershell
.\scripts\build_apk.ps1 -Split
# Output: build/app/outputs/flutter-apk/app-*-release.apk
```

### AAB (Play Store)

```powershell
.\scripts\build_aab.ps1
# Output: build/app/outputs/bundle/release/app-release.aab
```

### Both APK and AAB

```powershell
.\scripts\build_android.ps1 -Type Both
```

## 📝 Version Management

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

# Set complete version
.\scripts\version_manager.ps1 -Set "3.2.0+10"
```

## 🔍 Verification

```powershell
# Verify build configuration
.\scripts\verify_android_build.ps1
```

## 📁 File Locations

| File | Location |
|------|----------|
| **AAB** | `build/app/outputs/bundle/release/app-release.aab` |
| **APK** (Universal) | `build/app/outputs/flutter-apk/app-release.apk` |
| **APK** (Split) | `build/app/outputs/flutter-apk/app-*-release.apk` |
| **Keystore** | `upload-keystore.jks` |
| **Signing Config** | `android/key.properties` |

## 🔐 Signing Setup

```powershell
# Generate keystore
.\scripts\generate_keystore.ps1

# Configure signing
# 1. Copy template
cp android/key.properties.template android/key.properties

# 2. Edit android/key.properties:
#    storeFile=../upload-keystore.jks
#    storePassword=YOUR_PASSWORD
#    keyPassword=YOUR_PASSWORD
#    keyAlias=upload
```

## 🛠️ Direct Flutter Commands

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
```

## 📋 Release Checklist

- [ ] Version bumped in `pubspec.yaml`
- [ ] Signing configuration verified
- [ ] Build configuration verified
- [ ] APK/AAB builds successfully
- [ ] Tested on real device
- [ ] Release notes prepared

## 🚨 Common Issues

**Missing key.properties:**
```powershell
cp android/key.properties.template android/key.properties
# Edit with your keystore details
```

**Version code too low:**
```powershell
.\scripts\version_manager.ps1 -Build <higher_number>
```

**Build fails:**
```bash
flutter clean
flutter pub get
flutter doctor
```

## 📚 Documentation

- [Complete Guide](../docs/ANDROID_BUILD_COMPLETE_GUIDE.md)
- [README](README.md)

---

**For detailed information, see:** [Complete Build Guide](../docs/ANDROID_BUILD_COMPLETE_GUIDE.md)
