# Android Build Quick Reference Card

## 🚀 Quick Commands

### Build APK
```powershell
# Universal APK (all architectures)
.\scripts\build_apk.ps1

# Split APKs (per architecture)
.\scripts\build_apk.ps1 -Split
```

### Build AAB (Play Store)
```powershell
.\scripts\build_aab.ps1
```

### Version Management
```powershell
# Show current version
.\scripts\version_manager.ps1

# Bump version
.\scripts\version_manager.ps1 -Bump Patch   # 3.1.0 -> 3.1.1
.\scripts\version_manager.ps1 -Bump Minor   # 3.1.0 -> 3.2.0
.\scripts\version_manager.ps1 -Bump Major   # 3.1.0 -> 4.0.0

# Set build number
.\scripts\version_manager.ps1 -Build 42
```

### Verification
```powershell
.\scripts\verify_android_build.ps1
```

### Generate Keystore
```powershell
.\scripts\generate_keystore.ps1
```

---

## 📁 Output Locations

| File Type | Location |
|-----------|----------|
| **AAB** (Play Store) | `build/app/outputs/bundle/release/app-release.aab` |
| **APK** (Universal) | `build/app/outputs/flutter-apk/app-release.apk` |
| **APK** (Split) | `build/app/outputs/flutter-apk/app-*-release.apk` |
| **Keystore** | `upload-keystore.jks` (project root) |
| **Signing Config** | `android/key.properties` (not in git) |

---

## ⚙️ Configuration Files

| File | Purpose |
|------|---------|
| `android/app/build.gradle` | Main build configuration |
| `android/key.properties` | Signing configuration (create from template) |
| `pubspec.yaml` | Version source (`version: x.y.z+build`) |
| `.gitignore` | Excludes sensitive files |

---

## 🔐 Signing Setup (First Time)

1. **Generate keystore**:
   ```powershell
   .\scripts\generate_keystore.ps1
   ```

2. **Configure signing**:
   ```powershell
   Copy-Item android\key.properties.template android\key.properties
   # Edit android/key.properties with your keystore details
   ```

3. **Verify**:
   ```powershell
   .\scripts\verify_android_build.ps1
   ```

---

## 📋 Version Format

**Format**: `x.y.z+build` (e.g., `3.1.0+1`)

- **Version Name** (`x.y.z`): User-visible version
- **Build Number** (`build`): Play Store version code (must increment)

**Location**: `pubspec.yaml`

---

## ✅ Pre-Build Checklist

- [ ] Run `.\scripts\verify_android_build.ps1`
- [ ] Check version numbers
- [ ] Verify signing (if releasing to Play Store)
- [ ] Clean build: `flutter clean`
- [ ] Get dependencies: `flutter pub get`

---

## 🐛 Common Issues

### Missing key.properties
```powershell
Copy-Item android\key.properties.template android\key.properties
# Edit with keystore details
```

### Wrong password
```powershell
keytool -list -v -keystore upload-keystore.jks
# Verify passwords in key.properties
```

### Version code error
```powershell
.\scripts\version_manager.ps1 -Build <next_number>
```

---

## 📚 Documentation

- **Complete Guide**: `docs/ANDROID_BUILD_COMPLETE_GUIDE.md`
- **Quick Start**: `android/BUILD_QUICK_START.md`
- **Acceptance Verification**: `docs/ANDROID_BUILD_ACCEPTANCE_VERIFICATION.md`

---

## 🔗 Direct Flutter Commands

```powershell
# APK (Universal)
flutter build apk --release

# APK (Split)
flutter build apk --release --split-per-abi

# AAB
flutter build appbundle --release
```

---

**Tip**: Use scripts for better error handling and output formatting!
