# Android Build Configuration - Complete Setup

This document provides a complete overview of the Android build and signing configuration for Dual Reader 3.1.

## ✅ Configuration Status

All required components are configured and ready for production builds:

- ✅ **Build Configuration**: Complete APK and AAB build setup
- ✅ **Signing Configuration**: Release signing with keystore support
- ✅ **Version Management**: Automatic version extraction from pubspec.yaml
- ✅ **Build Scripts**: PowerShell and Bash scripts for all platforms
- ✅ **Documentation**: Comprehensive guides and quick references
- ✅ **Verification**: Scripts to verify build configuration

## 📁 File Structure

```
project-root/
├── android/
│   ├── key.properties.template    # Signing config template
│   ├── key.properties             # Signing config (create from template)
│   ├── build.gradle               # Root build config
│   └── app/
│       ├── build.gradle           # App build config (complete)
│       └── proguard-rules.pro     # ProGuard rules
├── upload-keystore.jks            # Keystore file (generate)
├── scripts/
│   ├── build_apk.ps1/.sh         # Build APK script
│   ├── build_aab.ps1/.sh         # Build AAB script
│   ├── build_android.ps1/.sh     # Master build script
│   ├── version_manager.ps1/.sh   # Version management
│   ├── generate_keystore.ps1/.sh # Keystore generator
│   └── verify_android_build.ps1/.sh # Verification script
└── docs/
    ├── android_build_and_signing.md  # Complete guide
    ├── android_build_quick_start.md   # Quick reference
    └── ANDROID_BUILD_README.md        # This file
```

## 🚀 Quick Start

### 1. Verify Setup
```powershell
.\scripts\verify_android_build.ps1
```

### 2. Set Up Signing (First Time Only)
```powershell
# Generate keystore
.\scripts\generate_keystore.ps1

# Configure signing
copy android\key.properties.template android\key.properties
# Edit android/key.properties with your passwords
```

### 3. Build
```powershell
# Build APK
.\scripts\build_apk.ps1

# Build AAB
.\scripts\build_aab.ps1

# Build both
.\scripts\build_android.ps1 -Type Both
```

## 📋 Acceptance Criteria Status

| Criteria | Status | Notes |
|----------|--------|-------|
| Build configuration for APK generation | ✅ Complete | Universal and split APK support |
| Build configuration for AAB generation | ✅ Complete | Play Store ready |
| Signing configuration set up | ✅ Complete | Keystore-based signing |
| Version code and name management | ✅ Complete | Auto-extracted from pubspec.yaml |
| Build scripts created | ✅ Complete | PowerShell and Bash versions |
| APK and AAB build successfully | ✅ Ready | Scripts tested and validated |
| Documentation for build process | ✅ Complete | Comprehensive guides |

## 🔧 Build Configuration Details

### APK Build Options

1. **Universal APK** (`flutter build apk --release`)
   - Single APK with all architectures
   - Larger file size (~50-100 MB)
   - Suitable for direct installation

2. **Split APKs** (`flutter build apk --release --split-per-abi`)
   - Separate APK per architecture
   - Smaller downloads (~20-35 MB each)
   - Architecture-specific: arm64-v8a, armeabi-v7a, x86_64

### AAB Build

- **App Bundle** (`flutter build appbundle --release`)
  - Optimized format for Play Store
  - Google generates device-specific APKs
  - Required format for Play Store uploads

### Signing Configuration

- **Release builds**: Signed with keystore from `key.properties`
- **Debug builds**: Automatically signed with debug keystore
- **Fallback**: Graceful fallback to debug signing if keystore missing

### Version Management

- **Source**: `pubspec.yaml` (`version: x.y.z+build`)
- **Extraction**: Automatic from pubspec.yaml in build.gradle
- **Version Code**: Build number (must increment for Play Store)
- **Version Name**: Semantic version (x.y.z)

## 📚 Documentation

### Complete Guides

1. **[Android Build and Signing Guide](./android_build_and_signing.md)**
   - Comprehensive setup instructions
   - Detailed signing configuration
   - Troubleshooting guide
   - Best practices

2. **[Quick Start Guide](./android_build_quick_start.md)**
   - 5-minute setup
   - Common commands
   - Pre-release checklist

### Script Documentation

All scripts include inline documentation and usage examples:
- `build_apk.ps1` / `build_apk.sh`
- `build_aab.ps1` / `build_aab.sh`
- `build_android.ps1` / `build_android.sh`
- `version_manager.ps1` / `version_manager.sh`
- `generate_keystore.ps1` / `generate_keystore.sh`
- `verify_android_build.ps1` / `verify_android_build.sh`

## 🔒 Security

### Files in .gitignore

- `android/key.properties` - Signing credentials
- `*.jks` / `*.keystore` - Keystore files
- `android/local.properties` - Local SDK paths

### Security Best Practices

- ✅ Keystore files never committed to git
- ✅ Passwords stored securely (password manager)
- ✅ Keystore backed up securely
- ✅ Template file provided for configuration

## 🧪 Testing Builds

### Verify Configuration
```powershell
.\scripts\verify_android_build.ps1
```

### Test APK Build
```powershell
.\scripts\build_apk.ps1
adb install build\app\outputs\flutter-apk\app-release.apk
```

### Test AAB Build
```powershell
.\scripts\build_aab.ps1
# Upload to Play Console internal testing track
```

## 📝 Version Management

### Show Current Version
```powershell
.\scripts\version_manager.ps1
```

### Bump Version
```powershell
# Patch: 3.1.0 -> 3.1.1
.\scripts\version_manager.ps1 -Bump Patch

# Minor: 3.1.0 -> 3.2.0
.\scripts\version_manager.ps1 -Bump Minor

# Major: 3.1.0 -> 4.0.0
.\scripts\version_manager.ps1 -Bump Major
```

### Set Build Number
```powershell
.\scripts\version_manager.ps1 -Build 42
```

## 🛠️ Troubleshooting

### Common Issues

1. **"key.properties not found"**
   - Copy template: `copy android\key.properties.template android\key.properties`
   - Fill in keystore details

2. **"Keystore file not found"**
   - Check `storeFile` path in `key.properties`
   - Verify keystore exists at specified location

3. **"Build failed"**
   - Run verification: `.\scripts\verify_android_build.ps1`
   - Clean build: `flutter clean`
   - Check Flutter version: `flutter doctor -v`

4. **"Version code must be higher"**
   - Increment build number: `.\scripts\version_manager.ps1 -Build <number>`

See [Android Build and Signing Guide](./android_build_and_signing.md#troubleshooting) for detailed troubleshooting.

## ✅ Pre-Release Checklist

Before releasing to Play Store:

- [ ] Run `verify_android_build.ps1` - all checks pass
- [ ] Bump version number using version manager
- [ ] Build and test APK on device
- [ ] Build AAB for Play Store
- [ ] Verify signing (not debug)
- [ ] Check file sizes
- [ ] Review release notes
- [ ] Upload to Play Console internal testing
- [ ] Test on multiple devices
- [ ] Submit for review

## 📞 Support

For issues or questions:
1. Check [Android Build and Signing Guide](./android_build_and_signing.md)
2. Run verification script: `.\scripts\verify_android_build.ps1`
3. Review build logs for specific errors
4. Check Flutter documentation: https://docs.flutter.dev/deployment/android

## 📄 License

This configuration is part of the Dual Reader 3.1 project.

---

**Last Updated**: 2024  
**Project**: Dual Reader 3.1  
**Maintainer**: AI Dev Team
