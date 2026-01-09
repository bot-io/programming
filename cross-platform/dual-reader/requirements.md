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
- **Scrolling Behavior**:
  - **Original Text Panel**: NON-SCROLLABLE - text fits exactly on the page without scrolling
  - **Translated Text Panel**: Independently SCROLLABLE - can scroll to read longer translations
  - No synchronized scrolling - panels operate independently
- **Responsive Design**: Adapts to screen size

### 3. Translation
- **Translation Service**: Hybrid approach with client-side and server-side options
  - **Mobile (Android/iOS)**: Google ML Kit On-Device Translation with LibreTranslate API fallback
    - Uses `google_mlkit_translation` package as primary
    - Falls back to LibreTranslate API if ML Kit fails or times out
    - LibreTranslate endpoints tried sequentially:
      - `https://translate.argosopentech.com/translate`
      - `https://libretranslate.com/translate`
      - `https://translate.terraprint.co/translate`
    - 5-minute timeout for ML Kit model download and translation (increased for emulator performance)
    - 10-second timeout for each LibreTranslate endpoint
    - Completely offline after ML Kit model download - no internet required
    - Supports 50+ languages via `TranslateLanguage` enum
    - Fast, private, and free
  - **Web**: Transformers.js v3
    - Uses NLLB-200 distilled model (600M parameters)
    - Client-side translation in the browser
    - Supports 200+ languages via FLORES-200 codes
    - Loaded via CDN in `web/index.html`
  - **Fallback (Optional)**: Server-based translation APIs
    - LibreTranslate (completely free, open-source) - used as mobile fallback
    - Google Translate API (free tier: 500,000 characters/month)
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
  - Granular caching: each paragraph/sentence cached separately for reuse across pages
- **Translation Strategy**: Paragraph/sentence-based translation for better quality
  - Text split into sentences before translation to maintain sentence structure
  - Each sentence translated as a complete unit (no mid-sentence breaks)
  - Translated sentences rejoined with proper spacing
  - Prevents translation quality issues from page boundaries cutting sentences
- **Text Selection**: Both original and translated text must be selectable and copyable

### 4. Smart Pagination
- **Dynamic Pagination**: Page size calculated dynamically based on actual text area capacity
  - Uses `PaginationService` with `TextPainter` to measure text dimensions
  - Binary search algorithm to find maximum characters that fit on a page
  - Accounts for actual screen dimensions, font size, line height, and margins
  - Page height calculation subtracts: appbar, status bar, margins, bottom nav, panel label
  - Original text pages fit exactly in allocated space (no scrolling)
  - Safety timeout (5 seconds) to prevent infinite loops on malformed content
- **Boundary Respect**: Prefers splitting at sentence boundaries
  - Searches backwards for sentence endings (. ! ?) when breaking content
  - Falls back to word boundaries (spaces) if no sentence boundary found
  - Ensures better readability and translation quality
- **Chapter Title Handling**: Chapter titles removed from content before pagination
  - Heading tags (h1-h6) stripped from HTML
  - Chapter titles (from EPUB metadata) stripped from start of text content
  - Prevents chapter titles from appearing as weird sentences in body text
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
- **Persistent Page Indicator**: Always-visible page number and progress percentage at bottom of reading screen
- **Automatic Progress Saving**: Progress saved on every page navigation

### 7. Full Screen Immersive Mode
- **True Full Screen**: System navigation, status bar, and time/battery indicators hidden when reading
- **Immersive Sticky Mode**: Uses `SystemUiMode.immersiveSticky` for full screen experience
- **Automatic Full Screen**: Enters full screen mode when opening a book
- **Exit Full Screen**: Automatically exits full screen when closing book or leaving app
- **Lifecycle Management**: Restores full screen mode when app is resumed

### 8. Touch Navigation Controls
- **Tap Zones for Navigation**:
  - Left 20% of screen: Previous page
  - Right 20% of screen: Next page
  - Middle 60% of screen: Toggle controls visibility
- **Show/Hide Controls**: Tap middle of screen to show or hide navigation and settings controls
- **Animated Controls**: Smooth slide-in/slide-out animations for controls bar
- **Independent Chapter Drawer**: Separate toggle state for table of contents drawer
- **Overlay Drawer**: Custom drawer implementation that overlays content in full screen mode

### 9. Dynamic Layout Adaptation
- **Repagination on Settings Changes**: When font size, margin, line height, or font family changes:
  - Automatic repagination of entire book
  - Cache invalidated for affected book
  - Reading position restored by finding first character match
  - Current page retranslated with new layout
- **Settings Change Detection**: Tracks layout-related settings changes separately from other settings
- **Position Restoration Algorithm**: Finds page containing first character from previous page after layout change

### 10. Translation Management
- **Clear Translation Cache**: Settings option to clear all cached translations
- **Clear Downloaded Models**: Settings option to clear downloaded language models
- **Translation Timeout**: 5-minute timeout for translation operations (especially for German and emulator performance)
- **Translation Refresh**: Manual refresh button to retranslate current page
- **Progress Dialog**: Shows download progress for language models
- **Background Model Download**: Automatic download of Spanish language model on app startup
  - Downloads Spanish ML Kit model in background when app launches (mobile only)
  - Shows progress banner in library screen during download
  - Non-blocking download - user can browse library while download progresses
  - Model cached after first download - subsequent app launches skip download
  - Improves first translation experience by pre-loading default language model
  - **Implementation**:
    - [library_screen.dart:22-33](dual_reader/lib/src/presentation/screens/library_screen.dart:22-33) - Download trigger and UI banners
    - [library_screen.dart:64-178](dual_reader/lib/src/presentation/screens/library_screen.dart:64-178) - Progress/success/error UI banners
    - [spanish_model_notifier.dart](dual_reader/lib/src/presentation/providers/spanish_model_notifier.dart) - State management
  - **Testing**:
    - [spanish_model_notifier_test.dart](dual_reader/test/src/presentation/providers/spanish_model_notifier_test.dart) - Unit tests for state management (16 tests, all passing)
    - [library_screen_spanish_download_test.dart](dual_reader/test/src/presentation/screens/library_screen_spanish_download_test.dart) - Widget tests for download UI (10 tests)
    - [spanish_model_download_integration_test.dart](dual_reader/test/integration/spanish_model_download_integration_test.dart) - Integration tests for download flow (run on device: `flutter test test/integration/spanish_model_download_integration_test.dart --device-id emulator-5554`)
  - **State Management**: Uses Riverpod StateNotifier with four states (notStarted, inProgress, completed, failed)
  - **Error Handling**: Retry button available if download fails
  - **Platform Detection**: Only activates on Android/iOS using `Platform.isAndroid || Platform.isIOS`
  - **Note**: Integration tests require Android/iOS device due to ML Kit platform dependencies

### 11. Navigation
- **Quick Navigation**: 
  - Page slider (seek to any page)
  - Chapter navigation (if available)
  - Table of contents (if available)
- **Bookmarks**: Save bookmarks for quick access
- **History**: Recent reading history

### 12. Customization
- **Themes**:
  - Dark theme (default)
  - Light theme
  - Sepia theme
  - Custom color themes
  - **Dark Mode Text Fix**: Dark mode text is white (uses `ThemeData.dark().textTheme`)
- **Font Options**:
  - 5-7 font families (system fonts + web fonts)
  - 5 font sizes (adjustable)
  - Line height adjustment
- **Layout Options**:
  - 5 margin size options
  - Text alignment (justified by default for better reading experience)
  - Panel width ratio (adjustable in landscape)

### 13. Settings
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
- **Log Export Feature**: Users can export app logs for debugging
  - Export via Settings → Export Logs
  - Generates timestamped text file with all log entries
  - Shares via system share sheet (email, cloud storage, etc.)
  - Includes timestamps, log levels, components, errors, and stack traces
  - Collects logs from all 5 rotated log files (complete history)

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

