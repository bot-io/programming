# Dual Reader 3.0 - Complete Requirements

## Overview
Dual Reader 3.0 is a mobile ebook reader application that displays books in two panels side-by-side: one showing the original text and the other showing a translated version. The application supports EPUB and MOBI formats, multiple languages, and provides a modern reading experience with customizable themes, fonts, and smart pagination.

## Platform Requirements
- **Primary Targets**: Android, iOS, and Windows
- **Distribution**: 
  - Android: Google Play Store + APK for direct installation
  - iOS: Apple App Store
  - Windows: Microsoft Store + standalone installer (EXE/MSIX)
- **Minimum Versions**:
  - Android: API Level 24 (Android 7.0)
  - iOS: iOS 13.0
  - Windows: Windows 10 (version 1809 or later)

## Core Features

### 1. Ebook Format Support
- Support for EPUB format (primary)
- Support for MOBI format (secondary)
- Automatic format detection
- Error handling for unsupported or corrupted files

### 2. Dual-Panel Display
- Split-screen view: original text (left/main) and translated text (right)
- Horizontal orientation support (side-by-side display)
- Vertical orientation support (stacked panels)
- Synchronized scrolling between panels
- Responsive layout that adapts to screen size

### 3. Multi-Language Translation
- Support for at least 10 languages:
  - English (en)
  - Spanish (es)
  - French (fr)
  - German (de)
  - Italian (it)
  - Portuguese (pt)
  - Russian (ru)
  - Chinese (zh)
  - Japanese (ja)
  - Korean (ko)
- Automatic language detection for source text
- Manual language selection for translation target
- Real-time translation with retry logic for connection resilience
- Offline translation support (if possible) or graceful degradation

### 4. Library Management
- Library page showing all imported books
- Book metadata display: title, author, cover image (if available)
- Book progress indicator (page X of Y)
- Last read timestamp
- Delete book functionality
- Search/filter books in library
- Sort books by: title, author, last read, date added

### 5. Reading Progress
- Automatic progress tracking
- Resume from last read position when reopening book
- Progress saved locally (persistent storage)
- Progress sync across devices (optional future feature)

### 6. Navigation
- Quick navigation slider for fast page seeking
- Previous/Next page buttons
- Page number display (Page X of Y)
- Chapter navigation (if available in book)
- Table of contents (if available in book)
- Bookmark support (optional)

### 7. Smart Pagination
- Text automatically paginated to fit screen size
- Pages fit exactly in visible area (no scrolling within page)
- Page breaks at natural points (sentence/paragraph boundaries)
- Recalculates pagination when:
  - Font size changes
  - Margin settings change
  - Screen orientation changes
  - Screen size changes (different devices)

### 8. Customization Options

#### Themes
- Dark theme (default): white text on black background
- Light theme: black text on white background
- Additional theme options (optional): sepia, high contrast, etc.

#### Fonts
- 5 font options:
  1. System Default
  2. Serif (e.g., Times New Roman)
  3. Sans-serif (e.g., Arial)
  4. Monospace (e.g., Courier)
  5. Custom font (user-selected)

#### Text Size
- 5 size options:
  1. Extra Small
  2. Small
  3. Medium (default)
  4. Large
  5. Extra Large

#### Margins
- 5 margin options:
  1. Narrow (minimal margins)
  2. Small
  3. Medium (default)
  4. Wide
  5. Extra Wide

### 9. User Interface
- Modern, clean design
- Intuitive navigation
- Touch-friendly controls
- Gesture support:
  - Swipe left/right for page navigation
  - Pinch to zoom (optional)
  - Long press for context menu (optional)
- Settings accessible from reader view
- Back button to return to library

## Technical Requirements

### Mobile App Framework
- **Recommended**: React Native or Flutter for cross-platform development
- **Alternative**: Native development (Kotlin for Android, Swift for iOS, C#/.NET for Windows)
- Must support Android, iOS, and Windows from single codebase (if using cross-platform)
- For Windows: React Native Windows or Flutter Windows support required

### Backend Services
- Ebook parsing library (native or JavaScript-based)
- Translation service integration:
  - Primary: Google Translate API or similar
  - Fallback: Deep Translator library
  - Retry logic with exponential backoff
  - Timeout protection (15-20 seconds)
  - Connection error handling

### Data Storage
- Local file storage for:
  - Imported book files
  - Book metadata
  - Reading progress
  - User preferences (theme, font, size, margins)
- Use platform-native storage:
  - Android: SQLite or Room Database
  - iOS: Core Data or SQLite
- Secure storage for sensitive data

### Performance
- Fast book loading (< 2 seconds for typical book)
- Smooth scrolling and page transitions
- Efficient memory usage
- Background processing for translation
- Lazy loading for large books

### Testing
- Unit tests for core functionality
- Integration tests for user flows
- E2E tests for critical paths
- Test coverage: minimum 70%
- Automated test execution in CI/CD

### Build & Distribution

#### Android
- Generate APK for direct installation
- Generate AAB (Android App Bundle) for Google Play Store
- Signing configuration for release builds
- ProGuard/R8 for code obfuscation and optimization
- Minimum SDK: 24 (Android 7.0)
- Target SDK: Latest stable

#### iOS
- Generate IPA for App Store distribution
- Code signing with Apple Developer account
- App Store Connect configuration
- Minimum iOS: 13.0
- Target iOS: Latest stable

#### Windows
- Generate MSIX package for Microsoft Store distribution
- Generate standalone EXE installer for direct installation
- Code signing certificate for release builds
- Windows App Certification Kit (WACK) compliance
- Minimum Windows: Windows 10 (version 1809)
- Target Windows: Latest stable

### Security & Privacy
- No user data collection without consent
- Secure storage of user books
- Privacy policy compliance
- GDPR compliance (if applicable)
- Secure API communication (HTTPS)

## User Experience Requirements

### Onboarding
- Welcome screen for first-time users
- Quick tutorial (optional)
- Permission requests (file access, if needed)

### Error Handling
- Clear error messages for users
- Graceful handling of:
  - Network failures
  - Translation service unavailability
  - Corrupted book files
  - Storage space issues
- Retry mechanisms where appropriate

### Accessibility
- Support for screen readers
- High contrast mode support
- Adjustable text sizes
- VoiceOver/TalkBack compatibility

## Acceptance Criteria

### Must Have (MVP)
1. ✅ Import EPUB/MOBI books
2. ✅ Display books in library
3. ✅ Open book and display in dual-panel view
4. ✅ Translate text to selected language
5. ✅ Navigate between pages
6. ✅ Save and resume reading progress
7. ✅ Dark and light themes
8. ✅ Font, size, and margin customization
9. ✅ Smart pagination that fits screen
10. ✅ Build APK for Android
11. ✅ Build IPA for iOS (or prepare for App Store)

### Should Have
- Chapter navigation
- Bookmarks
- Search within book
- Multiple theme options
- Offline translation support

### Nice to Have
- Cloud sync
- Reading statistics
- Social sharing
- Annotation support
- Export highlights

## Development Phases

### Phase 1: Core Infrastructure
- Set up mobile app project structure
- Implement ebook parsing
- Implement basic library view
- Implement basic reader view
- Local storage setup

### Phase 2: Core Features
- Dual-panel display
- Translation integration
- Smart pagination
- Progress tracking
- Navigation controls

### Phase 3: Customization
- Theme system
- Font options
- Text size options
- Margin options

### Phase 4: Polish & Distribution
- UI/UX improvements
- Performance optimization
- Comprehensive testing
- Build configuration for stores
- App Store assets (icons, screenshots, descriptions)

## Success Metrics
- App installs and active users
- User retention rate
- Average reading session duration
- Translation accuracy and speed
- App store ratings (target: 4.0+ stars)
- Crash-free rate (target: >99%)

