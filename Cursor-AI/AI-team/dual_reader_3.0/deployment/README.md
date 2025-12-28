# Dual Reader 3.0 - Deployment Artifacts

## Android
- APK: See android-build-instructions.txt or check android/app/build/outputs/apk/release/
- AAB: Build with `./gradlew bundleRelease`

## iOS
- IPA: See ios-build-instructions.txt
- Requires macOS and Xcode

## Windows
- MSIX/EXE: See windows-build-instructions.txt
- Requires Visual Studio and Windows 10 SDK

## Build Commands

### Android
```bash
cd android
./gradlew assembleRelease  # APK
./gradlew bundleRelease    # AAB
```

### iOS
```bash
cd ios
xcodebuild -workspace DualReader.xcworkspace -scheme DualReader -configuration Release archive
```

### Windows
```bash
npx react-native run-windows
# Then use Visual Studio to create MSIX package
```
