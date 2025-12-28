# Android Build Verification Checklist

Use this checklist to verify that Android build and signing are properly configured.

## ✅ Prerequisites

- [ ] Flutter SDK installed and in PATH
- [ ] Java JDK installed (for keystore generation)
- [ ] Android SDK configured (via Flutter)
- [ ] `flutter doctor` shows no critical issues

## ✅ Signing Configuration

- [ ] Keystore file generated (`upload-keystore.jks`)
- [ ] `android/key.properties` file exists
- [ ] `key.properties` contains:
  - [ ] `storeFile` path (relative or absolute)
  - [ ] `storePassword` (keystore password)
  - [ ] `keyAlias` (usually "upload")
  - [ ] `keyPassword` (key password)
- [ ] Keystore file exists at specified path
- [ ] Keystore passwords are correct (test with `keytool -list -v -keystore upload-keystore.jks`)
- [ ] `key.properties` and keystore are NOT committed to git (check `.gitignore`)

## ✅ Version Management

- [ ] `pubspec.yaml` contains version in format `x.y.z+build`
- [ ] Version code increments for each release
- [ ] Version name follows semantic versioning
- [ ] Version manager scripts work correctly

## ✅ Build Configuration

- [ ] `android/app/build.gradle` exists and is properly configured
- [ ] Signing configs section references `key.properties`
- [ ] Build types (debug/release) are configured
- [ ] Version code and name are read from `pubspec.yaml`
- [ ] ProGuard rules are configured (`proguard-rules.pro`)
- [ ] Minimum SDK is 21 (Android 5.0)
- [ ] Target SDK is 34

## ✅ Build Scripts

- [ ] `scripts/build_apk.sh` exists and is executable (Linux/Mac)
- [ ] `scripts/build_apk.ps1` exists (Windows)
- [ ] `scripts/build_aab.sh` exists and is executable (Linux/Mac)
- [ ] `scripts/build_aab.ps1` exists (Windows)
- [ ] `scripts/generate_keystore.sh` exists and is executable (Linux/Mac)
- [ ] `scripts/generate_keystore.ps1` exists (Windows)
- [ ] `scripts/version_manager.sh` exists and is executable (Linux/Mac)
- [ ] `scripts/version_manager.ps1` exists (Windows)

## ✅ Build Testing

### APK Build Test
- [ ] Universal APK builds successfully: `flutter build apk --release`
- [ ] Split APK builds successfully: `flutter build apk --release --split-per-abi`
- [ ] APK is signed with release key (check with `apksigner verify --print-certs app-release.apk`)
- [ ] APK installs on test device
- [ ] APK runs correctly on device

### AAB Build Test
- [ ] AAB builds successfully: `flutter build appbundle --release`
- [ ] AAB is signed with release key
- [ ] AAB can be uploaded to Play Console (internal test track)
- [ ] AAB generates APKs correctly in Play Console

## ✅ Documentation

- [ ] `ANDROID_BUILD_README.md` exists and is complete
- [ ] `ANDROID_BUILD_QUICK_START.md` exists
- [ ] `android/key.properties.template` exists
- [ ] Documentation covers:
  - [ ] Signing setup
  - [ ] Version management
  - [ ] APK building
  - [ ] AAB building
  - [ ] Troubleshooting

## ✅ Security

- [ ] Keystore file is backed up securely
- [ ] Keystore passwords are stored securely (password manager)
- [ ] `key.properties` is in `.gitignore`
- [ ] Keystore files (`*.jks`, `*.keystore`) are in `.gitignore`
- [ ] No sensitive data committed to repository

## ✅ Production Readiness

- [ ] Release build uses release signing (not debug)
- [ ] Version code is appropriate for release
- [ ] Version name follows semantic versioning
- [ ] ProGuard/R8 obfuscation is enabled for release
- [ ] App is tested on multiple devices/Android versions
- [ ] AAB is tested in Play Console internal track before production

## Quick Verification Commands

```bash
# Check Flutter setup
flutter doctor

# Verify keystore
keytool -list -v -keystore upload-keystore.jks

# Test APK build
flutter build apk --release

# Test AAB build
flutter build appbundle --release

# Verify APK signing
apksigner verify --print-certs build/app/outputs/flutter-apk/app-release.apk

# Check version
./scripts/version_manager.sh
```

## Issues Found?

If any items are unchecked:

1. **Signing Issues**: See "Signing Configuration" section in `ANDROID_BUILD_README.md`
2. **Build Failures**: See "Troubleshooting" section in `ANDROID_BUILD_README.md`
3. **Version Issues**: See "Version Management" section in `ANDROID_BUILD_README.md`
4. **Script Issues**: Ensure scripts are executable (Linux/Mac): `chmod +x scripts/*.sh`

---

**Last Verified:** [Date]
**Verified By:** [Name]
**Status:** ⬜ Complete / ⬜ In Progress / ⬜ Issues Found
