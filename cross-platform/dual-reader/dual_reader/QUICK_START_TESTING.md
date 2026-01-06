# Quick Start - Test ML Kit Translation

## The Easiest Way - One Command!

```bash
tool\test_mlkit.bat
```

That's it! (Make sure Android emulator is running first)

---

## Setup (First Time Only)

### 1. Install Android Studio
Download: https://developer.android.com/studio

### 2. Create Emulator
- Open Android Studio
- **Tools** → **Device Manager**
- **Create Virtual Device**
- Choose **Pixel 6**
- Select **Android 13** (or higher)
- Click **Finish**

### 3. Start Emulator
- In Device Manager, click **Play** button
- Wait for Android to boot

### 4. Test
```bash
tool\test_mlkit.bat
```

---

## What You'll See

```
==================================================
  Google ML Kit Translation Test Runner
==================================================

[1/5] Checking Flutter installation...
✓ Flutter 3.24.5

[2/5] Checking available devices...
✓ emulator-5554 • android

[4/5] Running ML Kit integration tests...

--- Test: English → Spanish ---
Input: "Hello world"
Result: "Hola mundo"
✓ PASS

--- Test: English → French ---
Input: "Thank you"
Result: "Merci"
✓ PASS

--- Test: English → Bulgarian ---
Input: "Hello"
Result: "Здравейте"
✓ PASS

[SUCCESS] All tests passed!
==================================================
```

---

## Manual Testing (Alternative)

```bash
# Run tests manually
flutter test test/integration/mlkit_translation_test.dart

# Or run the app
flutter run -d emulator-5554
```

---

## Expected Results

✅ **9 tests** should pass
✅ **Real translations** in Spanish, French, Bulgarian
✅ **Models downloaded** (first time: 30-50MB)
✅ **Performance**: ~500ms-2s per translation

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| "No connected devices" | Start Android emulator |
| Tests timeout | Wait for model download (first run) |
| "UnsupportedError" | Run on Android, not Windows |

---

## Files Created

- **[test/integration/mlkit_translation_test.dart](test/integration/mlkit_translation_test.dart)** - Real tests
- **[tool/test_mlkit.bat](tool/test_mlkit.bat)** - Test runner
- **[MLKIT_TESTING.md](MLKIT_TESTING.md)** - Full guide
- **[TRANSLATION_IMPLEMENTATION.md](TRANSLATION_IMPLEMENTATION.md)** - Complete docs

---

**That's it!** Run `tool\test_mlkit.bat` and see ML Kit in action.
