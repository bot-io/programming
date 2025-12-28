# Android Build Quick Start Guide

## 🚀 Quick Start

### Prerequisites
- Flutter SDK installed
- Java JDK installed (for signing)
- Android SDK configured

### 1. Verify Setup
```powershell
# Windows
.\scripts\verify_android_build.ps1

# Linux/Mac
./scripts/verify_android_build.sh
```

### 2. Set Up Signing (First Time Only)

**For Play Store releases, you need a keystore:**

```powershell
# Windows
.\scripts\generate_keystore.ps1
# Then edit android/key.properties with your keystore details

# Linux/Mac
./scripts/generate_keystore.sh
# Then edit android/key.properties with your keystore details
```

**Note:** For testing, you can skip signing (debug builds work fine).

### 3. Build APK (Direct Installation)

```powershell
# Windows - Universal APK (all architectures)
.\scripts\build_apk.ps1

# Windows - Split APKs (smaller files per architecture)
.\scripts\build_apk.ps1 -Split

# Linux/Mac - Universal APK
./scripts/build_apk.sh

# Linux/Mac - Split APKs
./scripts/build_apk.sh --split
```

**Output:** `build/app/outputs/flutter-apk/app-release.apk`

### 4. Build AAB (Play Store)

```powershell
# Windows
.\scripts\build_aab.ps1

# Linux/Mac
./scripts/build_aab.sh
```

**Output:** `build/app/outputs/bundle/release/app-release.aab`

---

## 📋 Version Management

### Check Current Version
```powershell
# Windows
.\scripts\version_manager.ps1

# Linux/Mac
./scripts/version_manager.sh
```

### Bump Version
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

### Set Build Number
```powershell
# Windows
.\scripts\version_manager.ps1 -Build 42

# Linux/Mac
./scripts/version_manager.sh build 42
```

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

## 🔐 Signing Configuration

### Setup Signing

1. **Generate keystore:**
   ```powershell
   .\scripts\generate_keystore.ps1
   ```

2. **Configure signing:**
   - Copy `android/key.properties.template` to `android/key.properties`
   - Edit `android/key.properties` with your keystore details:
     ```properties
     storeFile=../upload-keystore.jks
     storePassword=your-store-password
     keyPassword=your-key-password
     keyAlias=upload
     ```

3. **Verify:**
   ```powershell
   .\scripts\verify_android_build.ps1
   ```

⚠️ **Never commit `key.properties` or keystore files to git!**

---

## 🛠️ Build Scripts

### Available Scripts

**PowerShell (Windows):**
- `build_apk.ps1` - Build APK
- `build_aab.ps1` - Build AAB
- `build_android.ps1` - Master script (APK/AAB/Both)
- `version_manager.ps1` - Version management
- `generate_keystore.ps1` - Generate keystore
- `verify_android_build.ps1` - Verify configuration

**Bash (Linux/Mac):**
- `build_apk.sh` - Build APK
- `build_aab.sh` - Build AAB
- `build_android.sh` - Master script (APK/AAB/Both)
- `version_manager.sh` - Version management
- `generate_keystore.sh` - Generate keystore
- `verify_android_build.sh` - Verify configuration
- `setup_permissions.sh` - Make scripts executable

---

## ✅ Verification Checklist

Before building for production:

- [ ] Run `scripts/verify_android_build.ps1` / `scripts/verify_android_build.sh`
- [ ] Signing configured (if releasing to Play Store)
- [ ] Version numbers are correct
- [ ] Test APK installation on device
- [ ] Test AAB (if releasing to Play Store)

---

## 🐛 Troubleshooting

### Build fails with signing error
- Check `android/key.properties` exists and is configured
- Verify keystore file path is correct
- Run verification script to diagnose

### Version code error
- Increment version code: `scripts/version_manager.ps1 -Build <number>`
- Version code must be higher than previous release

### Scripts not executable (Linux/Mac)
- Run: `scripts/setup_permissions.sh`

---

## 📚 Documentation

For detailed documentation, see:
- **Complete Guide:** `docs/ANDROID_BUILD_COMPLETE_GUIDE.md`
- **Quick Reference:** `android/README_BUILD.md`
- **Acceptance Criteria:** `docs/ANDROID_BUILD_ACCEPTANCE_CRITERIA_COMPLETE.md`

---

## 🎯 Common Commands

```powershell
# Verify everything is set up
.\scripts\verify_android_build.ps1

# Build APK for testing
.\scripts\build_apk.ps1

# Build AAB for Play Store
.\scripts\build_aab.ps1

# Bump version before release
.\scripts\version_manager.ps1 -Bump Patch
```

---

**Ready to build!** 🚀
