# Dual Reader 3.2 - Requirements

## Overview

Dual Reader 3.2 is a cross-platform ebook reader application built with Flutter. It displays original and translated text side-by-side, supports multiple languages, and works on Android, iOS, and Web without requiring a backend server.

## Platform Requirements

- **Primary Targets**: Android, iOS, and Web
- **Framework**: Flutter (latest stable version)
- **Distribution**: 
  - Android: Google Play Store + APK for direct installation
  - iOS: Apple App Store
  - Web: Deployable as a web app (PWA support)
- **Minimum Versions**:
  - Android: API 21 (Android 5.0)
  - iOS: 12.0
  - Web: Modern browsers (Chrome, Firefox, Safari, Edge)

## Code Reuse & Shared Architecture

**CRITICAL REQUIREMENT**: This application must maximize code reuse across all platforms (Android, iOS, and Web). Since Flutter is specifically chosen for its cross-platform capabilities, the architecture must be designed to share as much code as possible between platforms.

### Shared Code Strategy
- **Core Business Logic**: All ebook parsing, translation, pagination, and data management logic must be platform-agnostic and shared across all platforms
- **UI Components**: Use Flutter's Material Design widgets that work identically on all platforms
- **State Management**: Implement a single state management solution (Provider/Riverpod) that works across all platforms
- **Services Layer**: Create platform-agnostic service interfaces with platform-specific implementations only when absolutely necessary
- **Data Models**: All data models, DTOs, and entities must be pure Dart classes shared across platforms
- **Utilities**: All helper functions, validators, formatters, and utility classes must be platform-independent

### Platform-Specific Code Minimization
- **Platform Channels**: Use only when native functionality is required (file system access, platform-specific APIs)
- **Platform Checks**: Minimize platform-specific conditionals; prefer abstract interfaces with platform implementations
- **Platform Assets**: Share assets (images, fonts) across platforms; use platform-specific assets only when necessary
- **Build Configuration**: Use Flutter's conditional compilation sparingly; prefer runtime feature detection when possible

### Architecture Principles
- **Single Source of Truth**: Core functionality implemented once, used everywhere
- **Dependency Injection**: Use dependency injection to swap platform-specific implementations without changing core code
- **Abstraction Layers**: Create abstraction layers for platform-specific features (storage, file access, network) with shared interfaces
- **Code Organization**: Structure code to clearly separate shared code from platform-specific code
- **Testing**: Write tests that run on all platforms using shared test code

### Expected Code Reuse Metrics
- **Target**: 85%+ code reuse across platforms
- **Shared Core**: Business logic, models, services, UI components
- **Platform-Specific**: Only native integrations, platform-specific UI adaptations, and build configurations

## Core Features

### 1. Ebook Support
- **Formats**: EPUB and MOBI
- **Parsing**: Client-side parsing using free libraries
  - EPUB: Use `epubx` or `flutter_epub` (free, open-source)
  - MOBI: Use `mobi` or similar free library
- **Metadata Extraction**: Title, author, cover image, chapters
- **Content Extraction**: Full text content with formatting preservation

### 2. Dual-Panel Display
- **Layout**: Side-by-side panels (original and translated)
- **Orientation Support**: 
  - Portrait: Stacked panels (original on top, translated below)
  - Landscape: Side-by-side panels
- **Synchronized Scrolling**: Both panels scroll together
- **Responsive Design**: Adapts to screen size

### 3. Translation
- **Translation Service**: Hybrid approach with client-side and server-side options
  - **Mobile (Android/iOS)**: Google ML Kit On-Device Translation
    - Uses `google_mlkit_translation` package
    - Completely offline - no internet required
    - Supports 50+ languages via `TranslateLanguage` enum
    - Fast, private, and free
  - **Web**: Transformers.js v3
    - Uses NLLB-200 distilled model (600M parameters)
    - Client-side translation in the browser
    - Supports 200+ languages via FLORES-200 codes
    - Loaded via CDN in `web/index.html`
  - **Fallback (Optional)**: Server-based translation APIs
    - Google Translate API (free tier: 500,000 characters/month)
    - LibreTranslate (completely free, open-source)
    - MyMemory Translation API (10,000 words/day free)
  - **Mock Service**: For testing without API calls
- **Supported Languages**:
  - **Mobile (ML Kit)**: 50+ languages including:
    - English, Spanish, Bulgarian, French, German, Italian, Portuguese
    - Chinese, Japanese, Korean, Vietnamese, Thai, Hindi, Indonesian
    - Russian, Ukrainian, Belarusian
    - Arabic, Hebrew, Persian, Turkish
    - Dutch, Polish, Swedish, Danish, Finnish, Norwegian
    - Czech, Greek, Hungarian, Romanian, Slovak
    - Catalan, Croatian, Slovenian, Serbian, Maltese
    - Afrikaans, Albanian, Estonian, Irish, Galician, Georgian
    - Gujarati, Haitian, Icelandic, Kannada, Latvian, Lithuanian
    - Macedonian, Marathi, Swahili, Tamil, Telugu, Urdu, Welsh
    - And more...
  - **Web (Transformers.js)**: 200+ languages via NLLB-200 model
    - All ML Kit languages plus 150+ more
    - Uses FLORES-200 language codes (e.g., `eng_Latn`, `spa_Latn`, `bul_Cyrl`)
  - Default target language: Spanish
  - Full BCP 47 language code support
- **Language Detection**: Automatic detection of source language
  - When source equals target language, automatically translates to first alternative language
  - Pattern-based detection for common languages (Cyrillic, CJK characters, Arabic script)
  - ML Kit and Transformers.js auto-detect during translation
  - Default to English for unknown languages
- **Translation Caching**: Cache translations locally to reduce API calls
  - Uses Hive for persistent caching
  - Cache key based on text + target language
  - Improves performance for repeated translations
- **Text Selection**: Both original and translated text must be selectable and copyable

### 4. Smart Pagination
- **Dynamic Pagination**: Text fits screen without scrolling within a page
- **Page Calculation**: Based on:
  - Screen dimensions
  - Font size
  - Line height
  - Margins
- **Boundary Respect**: Split at paragraph/sentence boundaries
- **Page Navigation**: Previous/Next buttons, page slider, direct page input

### 5. Library Management
- **Local Storage**: Store imported books locally
  - Use `path_provider` for file system access
  - Use `shared_preferences` or `hive` for metadata
- **Book Import**: 
  - File picker for EPUB/MOBI files
  - Drag-and-drop support (web)
  - Import from device storage
- **Library View**: 
  - Grid/list view of all books
  - Book cover thumbnails
  - Title, author, progress display
  - Search and filter functionality
- **Book Management**: 
  - Delete books
  - View book details
  - Export books (optional)

### 6. Progress Tracking
- **Reading Progress**: Track current page for each book
- **Persistence**: Save progress automatically
- **Resume Reading**: Open book at last read position
- **Progress Indicator**: Visual progress bar per book

### 7. Navigation
- **Quick Navigation**: 
  - Page slider (seek to any page)
  - Chapter navigation (if available)
  - Table of contents (if available)
- **Bookmarks**: Save bookmarks for quick access
- **History**: Recent reading history

### 8. Customization
- **Themes**: 
  - Dark theme (default)
  - Light theme
  - Sepia theme
  - Custom color themes
- **Font Options**: 
  - 5-7 font families (system fonts + web fonts)
  - 5 font sizes (adjustable)
  - Line height adjustment
- **Layout Options**: 
  - 5 margin size options
  - Text alignment (left, justify, center)
  - Panel width ratio (adjustable in landscape)

### 9. Settings
- **In-Context Settings**: Settings accessible while reading (settings button in reading screen)
  - Change translation language while reading
  - Adjust font size while reading
  - Change other display settings without leaving the book
- **Language Selection**: Choose translation target language from dropdown
  - Supports all listed languages with emoji flags
  - Settings persist across sessions
- **Default Settings**: Set default theme, font, size
- **Export Settings**: Export/import settings
- **About**: App version, credits, license

## Technical Requirements

### Flutter Dependencies
- **Core**: Flutter SDK (latest stable, SDK ^3.5.4)
- **State Management**: `flutter_riverpod` (free, reliable)
- **Navigation**: `go_router` (free)
- **Local Storage**:
  - `path_provider` - File system access
  - `hive` and `hive_flutter` - Key-value storage
- **File Picker**: `file_picker` - For importing books
- **HTTP Client**: `http` - For translation API calls (fallback)
- **EPUB Parser**: `epubx` (free, open-source)
- **MOBI Parser**: `mobi` or similar free library
- **Translation**:
  - **Mobile**: `google_mlkit_translation: ^0.10.0`
    - On-device translation for Android and iOS
    - Uses `TranslateLanguage` enum with 50+ languages
    - Offline capability, no API key required
  - **Web**: Transformers.js v3 (loaded via CDN in `web/index.html`)
    - `@huggingface/transformers@3.0.0` from CDN
    - JS interop layer in `lib/src/data/services/web/transformers_interop.dart`
    - NLLB-200 distilled model (600M parameters)
    - Supports 200+ languages
  - **Fallback (Optional)**:
    - Direct HTTP calls to Google Translate API, LibreTranslate, or MyMemory
    - `libretranslate_flutter` (if using LibreTranslate)
- **Utilities**:
  - `uuid` - For generating unique identifiers
  - `equatable` - For value equality comparisons
  - `crypto` - For hashing cache keys

### Architecture
- **No Backend Server**: All processing client-side
- **Platform-Specific Translation Services**:
  - Mobile: `ClientSideTranslationDelegateImpl` in `client_side_translation_service_mobile.dart`
    - Uses `OnDeviceTranslator` from `google_mlkit_translation`
    - Language code mapping via `_toTranslateLanguage()` method
    - Translator caching per language pair for efficiency
  - Web: `ClientSideTranslationDelegateImpl` in `client_side_translation_service_web.dart`
    - Uses `TransformersJsService` from `transformers_interop.dart`
    - JS interop with `@staticInterop` classes and extension methods
    - FLORES-200 language code mapping via `_toFloresCode()` method
    - Pipeline loading and caching
- **Offline Support**:
  - **Mobile**: Complete offline capability with ML Kit
    - Translation models downloaded once per language
    - Works completely offline after initial model download
    - No internet connection required for translation
  - **Web**: Client-side translation with Transformers.js
    - Models loaded from CDN and cached in browser
    - Works offline after initial model load (if cached)
    - Translation happens entirely in the browser
  - Books work offline
  - Translations cached in Hive for offline use
  - Progress saved locally
- **PWA Support** (Web): 
  - Service worker for offline functionality
  - Installable as PWA
  - Responsive design
- **Shared Architecture**: Maximum code reuse across platforms with clear separation of shared and platform-specific code

### Performance
- **Fast Loading**: Books load quickly
- **Smooth Scrolling**: 60fps scrolling
- **Efficient Memory**: Handle large books without crashes
- **Lazy Loading**: Load pages on demand

### Security & Privacy
- **No User Data Collection**: No analytics, no tracking
- **Local Storage Only**: All data stays on device
- **Secure File Access**: Proper file permissions
- **Privacy-First**: No external services that collect user data

## User Experience

### Design Principles
- **Intuitive**: Easy to use without instructions
- **Accessible**: Support screen readers, high contrast
- **Responsive**: Works on phones, tablets, desktops
- **Fast**: Quick app startup, instant page turns
- **Consistent**: Same experience across all platforms

### UI/UX Requirements
- **Material Design 3**: Follow Flutter Material Design guidelines
- **Dark Mode**: Default dark theme with proper contrast
- **Animations**: Smooth transitions and animations
- **Feedback**: Visual feedback for all user actions
- **Error Handling**: Clear error messages and recovery options
- **Platform Adaptation**: UI adapts to platform conventions while maintaining shared core

## Testing Requirements

### Unit Tests
- Ebook parsing logic
- Pagination calculations
- Translation service
- Progress tracking
- Settings management
- All shared business logic

### Mock Translation Service
- Client-side translation simulation for testing
- Word-replacement based mock translations
- Language detection testing
- Caching behavior testing
- Avoids CORS issues with external APIs during web testing

### Debug Logging
- Comprehensive debug logging throughout the application
- Settings state changes logged
- Translation service calls and results logged
- UI rebuild cycles logged
- All logs use `debugPrint` for proper Flutter logging

### Integration Tests
- Book import flow
- Reading flow
- Translation flow
- Settings changes
- Cross-platform compatibility

### E2E Tests
- Complete user workflows
- Cross-platform compatibility
- Performance benchmarks
- Platform-specific feature verification

## Build & Deployment

### Android
- Generate APK for direct installation
- Generate AAB for Play Store
- Code signing (optional for testing)

### iOS
- Build for iOS simulator
- Build for physical device
- Prepare for App Store (requires Apple Developer account)

### Web
- Build optimized web app
- Deploy to static hosting (GitHub Pages, Netlify, Vercel)
- PWA manifest and service worker

## Free Services & Libraries

### Translation Services
1. **LibreTranslate** (Recommended)
   - Completely free, open-source
   - Self-hosted or use public instance
   - No API key required
   - Multiple languages supported

2. **Google Translate API** (Free Tier)
   - 500,000 characters/month free
   - Requires API key (free to obtain)
   - Reliable and fast

3. **MyMemory Translation API** (Free Tier)
   - 10,000 words/day free
   - No API key required for basic use
   - Multiple languages

### Ebook Parsing Libraries
1. **epubx** (Flutter)
   - Free, open-source
   - Pure Dart implementation
   - Good performance

2. **flutter_epub** (Flutter)
   - Free, open-source
   - Active maintenance
   - Easy to use

3. **mobi** (Dart/Flutter)
   - Free, open-source
   - MOBI format support

### Storage Libraries
1. **hive** (Flutter)
   - Free, fast, lightweight
   - No native dependencies
   - Good for key-value storage

2. **shared_preferences** (Flutter)
   - Free, official Flutter plugin
   - Simple key-value storage
   - Cross-platform

## Success Criteria

- ✅ App runs on Android, iOS, and Web
- ✅ EPUB and MOBI files can be imported and read
- ✅ Dual-panel display works correctly
- ✅ **Translation works using client-side services (ML Kit on mobile, Transformers.js on web)**
- ✅ Smart pagination fits text to screen
- ✅ Progress tracking persists across sessions
- ✅ All customization options work
- ✅ App works offline (books and cached translations)
- ✅ No backend server required
- ✅ All dependencies are free and reliable
- ✅ App is performant and responsive
- ✅ Comprehensive test coverage
- ✅ **85%+ code reuse across platforms**
- ✅ **Shared architecture with minimal platform-specific code**
- ✅ **Single codebase for core functionality**
- ✅ **Google ML Kit On-Device Translation implemented (Android/iOS)**
- ✅ **Transformers.js v3 client-side translation implemented (Web)**

## Implementation Notes

### Google ML Kit Translation (Mobile)
- **Package**: `google_mlkit_translation: ^0.10.0`
- **API Version**: Uses modern `OnDeviceTranslator` constructor
  - `OnDeviceTranslator({required TranslateLanguage sourceLanguage, required TranslateLanguage targetLanguage})`
  - No longer uses deprecated `OnDeviceTranslatorModel`
- **Language Support**: 50+ languages via `TranslateLanguage` enum
- **Key Files**:
  - `lib/src/data/services/client_side_translation_service_mobile.dart` - Implementation
  - `lib/src/data/services/client_side_translation_service.dart` - Interface

### Transformers.js (Web)
- **Package**: Transformers.js v3.0.0 (loaded via CDN)
- **Model**: Xenova/nllb-200-distilled-600M (600M parameters)
- **Language Support**: 200+ languages via FLORES-200 codes
- **Key Files**:
  - `web/index.html` - CDN script loading
  - `lib/src/data/services/web/transformers_interop.dart` - JS interop layer
  - `lib/src/data/services/client_side_translation_service_web.dart` - Implementation
- **JS Interop Pattern**:
  - Uses `@staticInterop` classes for JavaScript objects
  - Extension methods for accessing JavaScript properties and methods
  - `JSPromise.toDart` for async/await with JavaScript promises
  - Proper type casting between `JSObject` and interop types

### Language Code Mapping
- **Mobile**: BCP 47 codes → `TranslateLanguage` enum values
  - Example: `'bg'` → `TranslateLanguage.bulgarian`
  - Example: `'zh'` → `TranslateLanguage.chinese`
- **Web**: BCP 47 codes → FLORES-200 codes
  - Example: `'en'` → `'eng_Latn'`
  - Example: `'bg'` → `'bul_Cyrl'`
  - Example: `'zh'` → `'zho_Hans'`

### Translation Service Interface
Both platforms implement the same `ClientSideTranslationDelegate` interface:
```dart
abstract class ClientSideTranslationDelegate {
  Future<String> translate({
    required String text,
    required String targetLanguage,
    String? sourceLanguage,
  });

  Future<String> detectLanguage(String text);

  Future<void> close();
}
```

This ensures consistent API across platforms while allowing platform-specific implementations.

## Notes

- All features must work without internet connection (except initial translation)
- Translations should be cached for offline use
- Use only free, open-source libraries when possible
- Ensure all dependencies are actively maintained
- Follow Flutter best practices and Material Design guidelines
- **Maximize code reuse - this is a core requirement, not optional**
- **Design architecture from the start to support maximum code sharing**
- **Platform-specific code should be the exception, not the rule**

