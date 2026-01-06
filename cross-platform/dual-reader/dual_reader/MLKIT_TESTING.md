# Google ML Kit Testing Guide - Windows

## Easiest Way to Test on Windows

The **easiest and best way** to test Google ML Kit on Windows is using **Android Emulator** in Android Studio. It's free, works perfectly, and provides a real Android environment.

## Quick Start (5 minutes)

### Step 1: Install Android Studio (if not already installed)

1. Download: https://developer.android.com/studio
2. Install with default settings
3. Open Android Studio

### Step 2: Create an Android Emulator

In Android Studio:

1. Click **Tools** → **Device Manager** (or **AVD Manager**)
2. Click **Create Virtual Device**
3. Choose a phone (e.g., **Pixel 6**)
4. Click **Next**
5. Select a system image (recommended: **Android 13.0 or higher**)
   - If not downloaded, click **Download** next to the image
6. Click **Finish** to create the emulator

### Step 3: Start the Emulator

1. In Android Studio **Device Manager**, find your emulator
2. Click the **Play** button to start it
3. Wait for Android to boot up (30-60 seconds first time)

### Step 4: Run the ML Kit Tests

Open a terminal in your project directory:

```bash
# Make sure emulator is running, then:
flutter devices

# You should see your emulator listed, e.g., "emulator-5554"

# Run the tests
flutter test test/integration/mlkit_translation_test.dart
```

That's it! The tests will run on the emulator and test **real** ML Kit translation.

## Alternative: Test the App Manually

If you prefer to test in the app UI:

```bash
# With emulator running
flutter run -d emulator-5554

# Or let Flutter choose the device
flutter run
```

Then:
1. Open a book in the app
2. Translation will happen automatically using ML Kit
3. Check the console for detailed logs

## One-Command Test Script

I've created a script to automate everything: `tool/test_mlkit.bat`

Just run:
```bash
tool\test_mlkit.bat
```

This script will:
1. Check if emulator is running
2. Start it if needed
3. Run the ML Kit tests
4. Show results

## Troubleshooting

### Emulator not appearing in `flutter devices`

```bash
# Cold boot the emulator
flutter emulators
flutter emulators --launch <emulator_id>

# Then run tests
flutter test test/integration/mlkit_translation_test.dart
```

### Tests fail with "UnsupportedError: ML Kit translation is only supported on Android and iOS"

Make sure you're running tests on an Android/iOS device, not on Windows:

```bash
# WRONG - runs on Windows
flutter test test/integration/mlkit_translation_test.dart --platform windows

# CORRECT - runs on Android emulator
flutter test test/integration/mlkit_translation_test.dart
```

### Models take too long to download

First run downloads 30-50MB per language pair. This is normal. Subsequent runs use cached models and are much faster.

### "No connected devices" error

1. Make sure emulator is running in Android Studio
2. Run `flutter devices` to verify
3. Try:
   ```bash
   flutter emulators --launch <emulator_id>
   ```

## Expected Test Results

When tests run successfully, you'll see:

```
==================================================
GOOGLE ML KIT - REAL INTEGRATION TESTS
==================================================

Platform: dart:io
Note: These tests use REAL ML Kit - no mocks!
First run will download models (can take 30-60 seconds)

--- Test: English → Spanish Translation ---
Input: "Hello world"
Result: "Hola mundo"
Duration: 1s (1234ms)
✓ Translation successful and contains Spanish

--- Test: English → French Translation ---
...
✓ French translation successful

==================================================
ML KIT INTEGRATION TESTS COMPLETE
==================================================

Summary:
  ✓ ML Kit translation working
  ✓ Multiple languages supported (es, fr, bg)
  ✓ Translator caching functional
  ✓ Performance acceptable
```

## What's Being Tested

The tests verify:

1. **Service Availability** - ML Kit is initialized
2. **English → Spanish** - Basic translation works
3. **English → French** - Multiple languages work
4. **English → Bulgarian** - Cyrillic languages work
5. **Long Text** - Longer translations work
6. **Sequential Translations** - Multiple requests in sequence
7. **Translator Caching** - Models are reused (faster)
8. **Performance** - Translation speed is acceptable

## Model Storage

ML Kit models are stored in the app's data directory on the device/emulator:

- **Location:** `/data/data/com.example.dual_reader/files/`
- **Size:** ~30-50MB per language pair
- **Caching:** Automatic, persists across app restarts

## Next Steps

Once tests pass:
1. ✓ ML Kit integration verified
2. ✓ Models downloaded and cached
3. ✓ Translation working on device
4. Integrate into production app

## Additional Resources

- [Google ML Kit Translation](https://developers.google.com/ml-kit/language-translation)
- [Flutter Testing](https://docs.flutter.dev/testing)
- [Android Emulator](https://developer.android.com/studio/run/emulator)
