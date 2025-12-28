# Android Build - Quick Reference Card

## 🚀 Quick Commands

### Setup (First Time)
```powershell
# Generate keystore
.\scripts\generate_keystore.ps1

# Configure signing (edit android/key.properties)
# Copy from android/key.properties.template
```

### Build APK
```powershell
# Universal APK
.\scripts\build_apk.ps1

# Split APKs (smaller files)
.\scripts\build_apk.ps1 -Split
```

### Build AAB (Play Store)
```powershell
.\scripts\build_aab.ps1
```

### Version Management
```powershell
# Show version
.\scripts\version_manager.ps1

# Bump patch (3.1.0 -> 3.1.1)
.\scripts\version_manager.ps1 -Bump Patch

# Bump minor (3.1.0 -> 3.2.0)
.\scripts\version_manager.ps1 -Bump Minor

# Bump major (3.1.0 -> 4.0.0)
.\scripts\version_manager.ps1 -Bump Major

# Set build number
.\scripts\version_manager.ps1 -Build 42
```

### Verify Configuration
```powershell
.\scripts\verify_android_build.ps1
```

---

## 📁 Output Locations

| Type | Location |
|------|----------|
| **APK (Universal)** | `build/app/outputs/flutter-apk/app-release.apk` |
| **APK (Split)** | `build/app/outputs/flutter-apk/app-*-release.apk` |
| **AAB** | `build/app/outputs/bundle/release/app-release.aab` |

---

## 🔐 Signing Configuration

**File:** `android/key.properties` (create from template)

```properties
storeFile=../upload-keystore.jks
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
```

⚠️ **Never commit this file to git!**

---

## 📝 Version Format

**Source:** `pubspec.yaml`

```yaml
version: 3.1.0+1
#         ^^^^^^ Version name
#                ^ Build number (versionCode)
```

---

## 🛠️ Direct Flutter Commands

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
```

---

## ✅ Acceptance Criteria Status

- ✅ APK generation configured
- ✅ AAB generation configured
- ✅ Signing configuration set up
- ✅ Version management automated
- ✅ Build scripts created
- ✅ APK and AAB build successfully
- ✅ Documentation complete

---

## 📚 Documentation

- **Quick Start:** `android/BUILD_QUICK_START.md`
- **Complete Guide:** `docs/ANDROID_BUILD_COMPLETE_GUIDE.md`
- **Production Ready:** `ANDROID_BUILD_AND_SIGNING_PRODUCTION_READY.md`

---

**Status:** ✅ **PRODUCTION READY**
