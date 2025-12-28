# Android Build Quick Start Guide

Quick reference for building and signing Android APK and AAB files.

## 🚀 Quick Setup (First Time)

### 1. Generate Keystore

**Linux/Mac:**
```bash
./scripts/generate_keystore.sh
```

**Windows:**
```powershell
.\scripts\generate_keystore.ps1
```

### 2. Configure Signing

```bash
# Copy template
cp android/key.properties.template android/key.properties

# Edit android/key.properties with your keystore details
```

### 3. Verify Setup

```bash
flutter doctor
```

## 📦 Building APK

### Universal APK (All Architectures)

**Linux/Mac:**
```bash
./scripts/build_apk.sh
```

**Windows:**
```powershell
.\scripts\build_apk.ps1
```

**Output:** `build/app/outputs/flutter-apk/app-release.apk`

### Split APK (Per Architecture)

**Linux/Mac:**
```bash
./scripts/build_apk.sh --split
```

**Windows:**
```powershell
.\scripts\build_apk.ps1 -Split
```

**Output:** `build/app/outputs/flutter-apk/app-*-release.apk`

## 📱 Building AAB (Play Store)

**Linux/Mac:**
```bash
./scripts/build_aab.sh
```

**Windows:**
```powershell
.\scripts\build_aab.ps1
```

**Output:** `build/app/outputs/bundle/release/app-release.aab`

## 🔢 Version Management

### Show Current Version
```bash
./scripts/version_manager.sh
```

### Bump Version
```bash
# Patch (3.1.0 -> 3.1.1)
./scripts/version_manager.sh bump patch

# Minor (3.1.0 -> 3.2.0)
./scripts/version_manager.sh bump minor

# Major (3.1.0 -> 4.0.0)
./scripts/version_manager.sh bump major
```

### Set Build Number
```bash
./scripts/version_manager.sh build 10
```

## 📋 Direct Flutter Commands

```bash
# Universal APK
flutter build apk --release

# Split APK
flutter build apk --release --split-per-abi

# AAB
flutter build appbundle --release
```

## 📁 File Locations

| File | Location |
|------|----------|
| Universal APK | `build/app/outputs/flutter-apk/app-release.apk` |
| Split APK | `build/app/outputs/flutter-apk/app-*-release.apk` |
| AAB | `build/app/outputs/bundle/release/app-release.aab` |
| Keystore | `upload-keystore.jks` (project root) |
| Signing Config | `android/key.properties` |

## ⚠️ Common Issues

### Missing key.properties
```bash
cp android/key.properties.template android/key.properties
# Then edit with your keystore details
```

### Build Fails
```bash
flutter clean
flutter pub get
flutter build apk --release
```

### Wrong Password
- Check `android/key.properties` passwords
- Verify keystore: `keytool -list -v -keystore upload-keystore.jks`

## 🔐 Security Reminders

- ❌ **Never commit** `key.properties` or keystore files
- ✅ **Backup** keystore in secure location
- ✅ **Use strong** passwords
- ✅ **Keep** keystore safe (required for updates)

## 📚 Full Documentation

See [ANDROID_BUILD_README.md](./ANDROID_BUILD_README.md) for complete guide.
