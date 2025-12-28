# Dual Reader 3.1 - Requirements

## Overview

Dual Reader 3.1 is a cross-platform ebook reader application built with Flutter. It displays original and translated text side-by-side, supports multiple languages, and works on Android, iOS, and Web without requiring a backend server.

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
- **Translation Service**: Use free translation APIs
  - Primary: Google Translate API (free tier available)
  - Alternative: LibreTranslate (completely free, open-source)
  - Fallback: Client-side translation using `flutter_translate` or similar
- **Supported Languages**: 
  - Minimum: English, Spanish, French, German, Italian, Portuguese
  - Extensible: Support for 50+ languages
- **Language Detection**: Automatic detection of source language
- **Translation Caching**: Cache translations locally to reduce API calls

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
- **Language Selection**: Choose translation target language
- **Default Settings**: Set default theme, font, size
- **Export Settings**: Export/import settings
- **About**: App version, credits, license

## Technical Requirements

### Flutter Dependencies
- **Core**: Flutter SDK (latest stable)
- **State Management**: Provider or Riverpod (free, reliable)
- **Navigation**: `go_router` or `flutter_navigation` (free)
- **Local Storage**: 
  - `path_provider` - File system access
  - `shared_preferences` or `hive` - Key-value storage
- **File Picker**: `file_picker` - For importing books
- **HTTP Client**: `http` or `dio` - For translation API calls
- **EPUB Parser**: `epubx` or `flutter_epub` (free, open-source)
- **MOBI Parser**: `mobi` or similar free library
- **Translation**: 
  - `libretranslate_flutter` (if using LibreTranslate)
  - Or direct HTTP calls to free translation APIs

### Architecture
- **No Backend Server**: All processing client-side
- **Offline Support**: 
  - Books work offline
  - Translations cached for offline use
  - Progress saved locally
- **PWA Support** (Web): 
  - Service worker for offline functionality
  - Installable as PWA
  - Responsive design

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

### UI/UX Requirements
- **Material Design 3**: Follow Flutter Material Design guidelines
- **Dark Mode**: Default dark theme with proper contrast
- **Animations**: Smooth transitions and animations
- **Feedback**: Visual feedback for all user actions
- **Error Handling**: Clear error messages and recovery options

## Testing Requirements

### Unit Tests
- Ebook parsing logic
- Pagination calculations
- Translation service
- Progress tracking
- Settings management

### Integration Tests
- Book import flow
- Reading flow
- Translation flow
- Settings changes

### E2E Tests
- Complete user workflows
- Cross-platform compatibility
- Performance benchmarks

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
- ✅ Translation works using free services
- ✅ Smart pagination fits text to screen
- ✅ Progress tracking persists across sessions
- ✅ All customization options work
- ✅ App works offline (books and cached translations)
- ✅ No backend server required
- ✅ All dependencies are free and reliable
- ✅ App is performant and responsive
- ✅ Comprehensive test coverage

## Notes

- All features must work without internet connection (except initial translation)
- Translations should be cached for offline use
- Use only free, open-source libraries when possible
- Ensure all dependencies are actively maintained
- Follow Flutter best practices and Material Design guidelines

