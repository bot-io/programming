# Android Build Quick Start Guide

Quick reference for building and signing Android APK and AAB files.

## 🚀 Quick Start (5 Minutes)

### Step 1: Verify Setup (30 seconds)

```powershell
.\scripts\verify_android_build.ps1
```

### Step 2: Set Up Signing (2 minutes)

**First time only:**

```powershell
# Generate keystore
.\scripts\generate_keystore.ps1

# Configure signing (edit android/key.properties)
# Copy template if needed:
copy android\key.properties.template android\key.properties
# Then edit android/key.properties with your passwords
```

### Step 3: Build (2 minutes)

**For direct installation (APK):**
```powershell
.\scripts\build_apk.ps1
```

**For Play Store (AAB):**
```powershell
.\scripts\build_aab.ps1
```

**Build both:**
```powershell
.\scripts\build_android.ps1 -Type Both
```

## 📦 Build Outputs

### APK Outputs
- **Universal APK**: `build/app/outputs/flutter-apk/app-release.apk`
- **Split APKs**: `build/app/outputs/flutter-apk/app-*-release.apk`

### AAB Output
- **App Bundle**: `build/app/outputs/bundle/release/app-release.aab`

## 🔢 Version Management

**Show current version:**
```powershell
.\scripts\version_manager.ps1
```

**Bump version before release:**
```powershell
# Patch: 3.1.0 -> 3.1.1
.\scripts\version_manager.ps1 -Bump Patch

# Minor: 3.1.0 -> 3.2.0
.\scripts\version_manager.ps1 -Bump Minor

# Major: 3.1.0 -> 4.0.0
.\scripts\version_manager.ps1 -Bump Major
```

## ✅ Pre-Release Checklist

- [ ] Run `verify_android_build.ps1` - all checks pass
- [ ] Bump version number
- [ ] Build APK and test on device
- [ ] Build AAB for Play Store
- [ ] Verify signing (not debug)
- [ ] Check file sizes
- [ ] Upload to Play Console

## 🆘 Common Commands

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

# Show version
.\scripts\version_manager.ps1

# Bump patch version
.\scripts\version_manager.ps1 -Bump Patch

# Generate keystore
.\scripts\generate_keystore.ps1
```

## 📚 Full Documentation

For detailed information, see: [Android Build and Signing Guide](./android_build_and_signing.md)
