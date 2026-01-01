# SimpleNotes - Cross-Platform Note-Taking App

## Overview

SimpleNotes is a lightweight, cross-platform note-taking application built with Flutter. It allows users to create, organize, search, and manage notes across Android, iOS, and Web platforms with maximum code reuse. This project is designed to test parallel development capabilities with multiple developer agents working simultaneously.

## Platform Requirements

- **Primary Targets**: Android, iOS, and Web
- **Framework**: Flutter (latest stable version)
- **Minimum Versions**:
  - Android: API 21 (Android 5.0)
  - iOS: 12.0
  - Web: Modern browsers (Chrome, Firefox, Safari, Edge)

## Core Requirements (10+ Requirements for Parallel Development)

### Requirement 1: Project Setup and Configuration
**Priority**: Critical (Must be done first)
- Initialize Flutter project with proper structure
- Configure `pubspec.yaml` with all required dependencies (hive, hive_flutter, path_provider, provider)
- Set up platform-specific configurations (Android, iOS, Web)
- Create proper folder structure (lib/models, lib/services, lib/providers, lib/screens, lib/widgets)
- Configure build settings for all platforms
- **Parallel Work**: Can be done by 1 developer, but must complete before other requirements

### Requirement 2: Data Models
**Priority**: High (Can start after Requirement 1)
- Create `Note` model with fields: id, title, content, categoryId (optional), createdAt, updatedAt
- Create `Category` model with fields: id, name, color (optional), createdAt
- Implement Hive type adapters for both models
- Add JSON serialization/deserialization methods
- Include validation logic for model data
- **Parallel Work**: Can be developed independently by 1 developer

### Requirement 3: Storage Service Implementation
**Priority**: High (Can start after Requirements 1 and 2)
- Implement abstract `StorageService` interface
- Create Hive-based storage implementation
- Implement initialization and box opening logic
- Implement CRUD operations for notes (create, read, update, delete)
- Implement CRUD operations for categories (create, read, update, delete)
- Add error handling and data migration support
- **Parallel Work**: Can be developed independently by 1 developer after models are ready

### Requirement 4: Note Service (Business Logic)
**Priority**: High (Can start after Requirements 2 and 3)
- Create `NoteService` class with business logic
- Implement note creation with validation
- Implement note update with timestamp management
- Implement note deletion with confirmation logic
- Implement note retrieval (single and list)
- Add note filtering and sorting capabilities
- **Parallel Work**: Can be developed independently by 1 developer after storage service is ready

### Requirement 5: Category Service (Business Logic)
**Priority**: High (Can start after Requirements 2 and 3)
- Create `CategoryService` class with business logic
- Implement category creation with name validation
- Implement category update (rename, change color)
- Implement category deletion with note reassignment logic
- Implement category retrieval and listing
- Add default categories initialization
- **Parallel Work**: Can be developed independently by 1 developer after storage service is ready

### Requirement 6: Search Service
**Priority**: Medium (Can start after Requirements 2, 3, 4)
- Create `SearchService` class for search functionality
- Implement full-text search across note titles and content
- Implement real-time search with debouncing
- Add search result highlighting logic
- Implement search history (optional, can be simplified)
- Add search filtering by category
- **Parallel Work**: Can be developed independently by 1 developer

### Requirement 7: State Management Providers
**Priority**: High (Can start after Requirements 4, 5, 6)
- Create `NoteProvider` using Provider pattern
- Create `CategoryProvider` using Provider pattern
- Create `SearchProvider` using Provider pattern
- Create `ThemeProvider` for dark/light theme management
- Implement reactive state updates
- Add provider initialization and disposal logic
- **Parallel Work**: Can be developed in parallel by multiple developers (one per provider)

### Requirement 8: Reusable UI Widgets
**Priority**: Medium (Can start after Requirements 2, 7)
- Create `NoteCard` widget for displaying notes in lists
- Create `CategoryChip` widget for category display/selection
- Create `SearchBar` widget for search input
- Create `EmptyState` widget for empty list states
- Create `NoteEditor` widget for note creation/editing
- Add proper styling and Material Design 3 theming
- **Parallel Work**: Can be developed in parallel by multiple developers (one widget per developer)

### Requirement 9: Screen Implementations
**Priority**: High (Can start after Requirements 7, 8)
- Create `NoteListScreen` - main screen showing all notes with search and filter
- Create `NoteDetailScreen` - screen for viewing and editing individual notes
- Create `CategoryManagementScreen` - screen for managing categories
- Implement navigation between screens using Flutter Navigator
- Add proper app bar and bottom navigation (if needed)
- **Parallel Work**: Can be developed in parallel by multiple developers (one screen per developer)

### Requirement 10: Theme and Styling
**Priority**: Medium (Can start after Requirement 7)
- Implement dark theme configuration
- Implement light theme configuration
- Create theme switching functionality
- Apply Material Design 3 color scheme
- Ensure consistent styling across all screens and widgets
- Add responsive design for different screen sizes
- **Parallel Work**: Can be developed independently by 1 developer

### Requirement 11: Main App Integration
**Priority**: Critical (Must be done after Requirements 7, 9, 10)
- Create `main.dart` with proper app initialization
- Set up Provider hierarchy in widget tree
- Initialize Hive storage on app start
- Configure app theme and routing
- Add error handling and loading states
- Ensure app runs on all platforms (Android, iOS, Web)
- **Parallel Work**: Can be done by 1 developer, integrates all previous work

### Requirement 12: Testing and Verification
**Priority**: High (Can start after Requirement 11)
- Create unit tests for models (Note, Category)
- Create unit tests for services (NoteService, CategoryService, SearchService)
- Create widget tests for reusable widgets
- Create integration tests for critical user flows
- Verify app runs on Android, iOS, and Web
- Test data persistence across app restarts
- **Parallel Work**: Can be developed in parallel by multiple testers

## Development Guidelines

### Parallel Development Strategy

1. **Phase 1 - Foundation** (Sequential):
   - Requirement 1: Project Setup (1 developer)
   - Requirement 2: Data Models (1 developer, after Requirement 1)

2. **Phase 2 - Core Services** (Parallel):
   - Requirement 3: Storage Service (1 developer, after Requirement 2)
   - Requirement 4: Note Service (1 developer, after Requirements 2, 3)
   - Requirement 5: Category Service (1 developer, after Requirements 2, 3)
   - Requirement 6: Search Service (1 developer, after Requirements 2, 3, 4)

3. **Phase 3 - State Management** (Parallel):
   - Requirement 7: State Management Providers (3-4 developers in parallel, after Requirements 4, 5, 6)

4. **Phase 4 - UI Components** (Parallel):
   - Requirement 8: Reusable Widgets (3-5 developers in parallel, after Requirement 7)
   - Requirement 9: Screen Implementations (3 developers in parallel, after Requirements 7, 8)
   - Requirement 10: Theme and Styling (1 developer, after Requirement 7)

5. **Phase 5 - Integration** (Sequential):
   - Requirement 11: Main App Integration (1 developer, after Requirements 7, 9, 10)

6. **Phase 6 - Testing** (Parallel):
   - Requirement 12: Testing and Verification (2+ testers in parallel, after Requirement 11)

### Code Organization

```
lib/
├── main.dart                 # App entry point (Requirement 11)
├── models/                   # Data models (Requirement 2)
│   ├── note.dart
│   ├── note.g.dart
│   ├── category.dart
│   └── category.g.dart
├── services/                 # Business logic services (Requirements 3, 4, 5, 6)
│   ├── storage_service.dart
│   ├── note_service.dart
│   ├── category_service.dart
│   └── search_service.dart
├── providers/                # State management (Requirement 7)
│   ├── note_provider.dart
│   ├── category_provider.dart
│   ├── search_provider.dart
│   └── theme_provider.dart
├── screens/                  # UI screens (Requirement 9)
│   ├── note_list_screen.dart
│   ├── note_detail_screen.dart
│   └── category_management_screen.dart
└── widgets/                  # Reusable widgets (Requirement 8)
    ├── note_card.dart
    ├── category_chip.dart
    ├── search_bar.dart
    ├── empty_state.dart
    └── note_editor.dart
```

### Dependencies

```yaml
dependencies:
  flutter:
    sdk: flutter
  hive: ^2.2.3
  hive_flutter: ^1.1.0
  path_provider: ^2.1.1
  provider: ^6.1.1
  cupertino_icons: ^1.0.6

dev_dependencies:
  flutter_test:
    sdk: flutter
  hive_generator: ^2.0.1
  build_runner: ^2.4.7
```

## Success Criteria

### Functional Requirements
- ✅ Users can create, edit, and delete notes
- ✅ Notes are persisted locally and survive app restarts
- ✅ Users can create and manage categories
- ✅ Users can assign notes to categories
- ✅ Users can filter notes by category
- ✅ Users can search notes by title and content
- ✅ Dark/light theme switching works
- ✅ App runs on Android, iOS, and Web
- ✅ Navigation between screens works correctly
- ✅ Empty states are user-friendly

### Technical Requirements
- ✅ Code reuse: 90%+ shared code across platforms
- ✅ Test coverage: 70%+ code coverage
- ✅ App starts in < 3 seconds
- ✅ No critical bugs or crashes
- ✅ All dependencies properly configured
- ✅ Build succeeds on all platforms

### Parallel Development Requirements
- ✅ Multiple developers can work simultaneously without conflicts
- ✅ Clear dependency management between requirements
- ✅ Proper code organization for parallel development
- ✅ Final integration results in working app

## Acceptance Criteria

The app is considered complete when:
1. All 12 requirements are implemented
2. App runs successfully on Android, iOS, and Web
3. All core features work as specified
4. Tests pass (unit, widget, integration)
5. No critical bugs remain
6. Code follows Flutter best practices
7. App is ready for deployment/testing
