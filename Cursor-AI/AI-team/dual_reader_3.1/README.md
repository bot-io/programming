# Dual Reader 3.1

A cross-platform ebook reader application built with Flutter that displays original and translated text side-by-side. Works on Android, iOS, and Web without requiring a backend server.

## Features

- 📚 **Ebook Support**: EPUB and MOBI formats
- 🌐 **Dual-Panel Display**: Side-by-side original and translated text
- 🔄 **Translation**: Free translation APIs (LibreTranslate, MyMemory)
- 📄 **Smart Pagination**: Dynamic pagination that fits text to screen
- 💾 **Local Storage**: All books and progress stored locally
- 🎨 **Customization**: Themes, fonts, margins, and more
- 📊 **Progress Tracking**: Automatic progress saving and resume reading
- 🔖 **Bookmarks**: Save bookmarks for quick access
- 🌙 **Dark Mode**: Default dark theme with light and sepia options

## Requirements

- Flutter SDK (latest stable version)
- Dart SDK >=3.0.0 <4.0.0
- Android: API 21+ (Android 5.0+)
- iOS: 12.0+
- Web: Modern browsers (Chrome, Firefox, Safari, Edge)

## Setup

1. **Install Flutter dependencies:**
   ```bash
   flutter pub get
   ```

2. **Generate Hive adapters:**
   ```bash
   flutter pub run build_runner build --delete-conflicting-outputs
   ```

3. **Run the app:**
   ```bash
   flutter run
   ```

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── models/                   # Data models
│   ├── book.dart
│   ├── reading_progress.dart
│   ├── bookmark.dart
│   ├── app_settings.dart
│   └── page_content.dart
├── services/                 # Business logic services
│   ├── storage_service.dart
│   ├── ebook_parser.dart
│   └── translation_service.dart
├── providers/                # State management
│   ├── book_provider.dart
│   ├── settings_provider.dart
│   └── reader_provider.dart
├── screens/                  # UI screens
│   ├── library_screen.dart
│   ├── reader_screen.dart
│   └── settings_screen.dart
├── widgets/                  # Reusable widgets
│   ├── dual_panel_reader.dart
│   ├── reader_controls.dart
│   └── book_card.dart
└── utils/                    # Utilities
    └── pagination.dart
```

## Usage

1. **Import Books**: Tap the "Import Book" button and select an EPUB or MOBI file
2. **Read**: Tap on a book to open it in the reader
3. **Translate**: Pages are automatically translated if auto-translate is enabled
4. **Navigate**: Use the page slider or navigation buttons to move between pages
5. **Customize**: Access settings to change theme, font, margins, and more

## Translation Services

The app supports multiple free translation services:

- **LibreTranslate** (Default): Completely free, open-source, no API key required
- **MyMemory**: Free tier with 10,000 words/day

Translations are cached locally for offline use.

## Building for Production

### Android

**Quick Start:**
```bash
# Build APK (direct installation)
.\scripts\build_apk.ps1              # Windows
./scripts/build_apk.sh                 # Linux/Mac

# Build AAB (Play Store)
.\scripts\build_aab.ps1                # Windows
./scripts/build_aab.sh                 # Linux/Mac
```

**First-Time Setup:**
1. Generate keystore: `.\scripts\generate_keystore.ps1` (Windows) or `./scripts/generate_keystore.sh` (Linux/Mac)
2. Configure signing: Copy `android/key.properties.template` to `android/key.properties` and fill in values
3. Verify configuration: `.\scripts\verify_android_build.ps1` (Windows) or `./scripts/verify_android_build.sh` (Linux/Mac)

**Manual Build Commands:**
```bash
# Universal APK (all architectures)
flutter build apk --release

# Split APK (per architecture, smaller files)
flutter build apk --release --split-per-abi

# App Bundle (for Play Store)
flutter build appbundle --release
```

**Documentation:**
- 📖 [Complete Android Build Guide](docs/ANDROID_BUILD_AND_SIGNING_GUIDE.md)
- 🚀 [Quick Start Guide](android/README_BUILD.md)
- 📋 [Production Guide](docs/ANDROID_BUILD_AND_SIGNING_PRODUCTION_GUIDE.md)
- ✅ [Acceptance Verification](ANDROID_BUILD_AND_SIGNING_ACCEPTANCE_VERIFICATION.md)

### iOS
```bash
flutter build ios --release
```

### Web
```bash
flutter build web --release
```

## Dependencies

- **provider**: State management
- **go_router**: Navigation
- **hive**: Local storage
- **epubx**: EPUB parsing
- **file_picker**: File selection
- **http**: HTTP requests for translation
- **path_provider**: File system access

## License

This project is open source and available for use.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
