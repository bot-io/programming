# Dual Reader — Requirements Document

> **Dual Reader** is a dual-language EPUB reader for Android that displays original text alongside a real-time translation, enabling immersive foreign-language reading.

---

## 1. Project Overview

| Field | Value |
|---|---|
| **App Name** | Dual Reader |
| **Package** | `com.dualreader.app` |
| **Min SDK** | 26 (Android 8.0) |
| **Target / Compile SDK** | 37 |
| **Architecture** | Clean Architecture (Domain → Data → UI) |
| **UI Framework** | Jetpack Compose + Material 3 |

---

## 2. Tech Stack

### 2.1 Language & Build

| Component | Version |
|---|---|
| Kotlin | 2.3.21 |
| Android Gradle Plugin (AGP) | 9.2.1 |
| Gradle | 9.4.1 |
| JDK | 21 |

### 2.2 Core Libraries

| Library | Version | Purpose |
|---|---|---|
| Jetpack Compose BOM | 2026.05.01 | Declarative UI |
| Material 3 | (BOM-managed) | Design system |
| Hilt | 2.59.2 | Dependency injection |
| Room | 2.8.4 | Local SQLite database |
| Retrofit | 3.0.0 | HTTP client |
| OkHttp | 5.3.2 | HTTP transport |
| Coil | 3.4.0 | Image loading |
| epub4j | — | EPUB parsing |
| Jsoup | — | HTML → plain-text extraction |
| ML Kit Translate | 17.0.3 | On-device translation |

### 2.3 Backend / Cloud

| Component | Details |
|---|---|
| Translation proxy | Cloudflare Worker |
| Worker URL | `https://dual-reader-translate.dualreader.workers.dev` |
| LLM (primary) | GLM-4.7-Flash (free tier) |
| Fallback | ML Kit offline translation |

---

## 3. Architecture

The app follows **Clean Architecture** with three clearly separated layers and unidirectional data flow.

```
┌─────────────────────────────────────────────────┐
│                    UI Layer                      │
│  Compose Screens · ViewModels · Navigation      │
├─────────────────────────────────────────────────┤
│                  Domain Layer                    │
│  Entities · Repository Interfaces · Use Cases   │
│  Service Interfaces                             │
├─────────────────────────────────────────────────┤
│                  Data Layer                      │
│  Room DAOs · Repository Impls · EPUB Parser     │
│  Pagination · Translation Services · DataStore  │
└─────────────────────────────────────────────────┘
```

### 3.1 Domain Layer

- **Entities**: `Book`, `Bookmark`, `Page`, `ReadingSettings`, `ReaderTheme`
- **Repositories**: interfaces defining data contracts
- **Use Cases**: single-responsibility business logic units
- **Services**: interfaces for translation, pagination, etc.

### 3.2 Data Layer

- **Room Database**: entities, DAOs, type converters
- **Repository Implementations**: concrete implementations of domain repository interfaces
- **EPUB Parser**: extracts metadata, chapters, and full text using epub4j + Jsoup
- **Pagination Engine**: `StaticLayout`-based page splitting
- **Translation Services**: Cloudflare Worker client + ML Kit offline
- **DataStore**: persisted user settings (preferences, not DB)

### 3.3 UI Layer

- **Screens**: Library, Reader, Settings
- **ViewModels**: state holders for each screen
- **Navigation**: Compose Navigation graph

---

## 4. Domain Entities

### 4.1 Book

```
data class Book(
    id: Long,
    title: String,
    author: String,
    filePath: String,
    coverPath: String?,
    language: String,
    totalPages: Int,
    currentPage: Int,
    lastOpened: Long,
    isImported: Boolean,
    chapters: List<BookChapter>
)
```

### 4.2 Page

```
data class Page(
    index: Int,
    bookId: Long,
    chapterIndex: Int,
    originalText: String,
    translatedText: String?
)
```

### 4.3 Bookmark

```
data class Bookmark(
    id: Long,
    bookId: Long,
    pageIndex: Int,
    chapterIndex: Int,
    textSnippet: String,
    note: String?,
    createdAt: Long
)
```

### 4.4 ReadingSettings

```
data class ReadingSettings(
    fontSize: Float,
    lineHeight: Float,
    fontFamily: String,
    theme: ReaderTheme,
    sourceLang: String,
    targetLang: String,
    showParallel: Boolean,
    brightness: Float,
    isImmersiveMode: Boolean,
    margins: Margins
)
```

### 4.5 ReaderTheme

```
enum class ReaderTheme {
    LIGHT, DARK, SEPIA, OCEAN, FOREST, MIDNIGHT
}
```

---

## 5. Features

### 5.1 Implemented Features

#### 5.1.1 EPUB Import

- Uses Android **Storage Access Framework (SAF)** file picker
- Copies selected EPUB to internal app storage
- Parses metadata (title, author, language) and full text
- Extracts chapter structure

#### 5.1.2 Library

- Grid display of imported books with cover images
- **Search** across book titles and authors
- **Delete** books (removes file + database records)
- **Import FAB** for adding new books
- **Empty state** placeholder when no books are present

#### 5.1.3 Reader — Dual-Panel Layout

- **Left panel**: original EPUB text
- **Right panel**: translated text
- Side-by-side parallel reading experience
- Configurable via `showParallel` setting

#### 5.1.4 Pagination

- Custom `StaticLayout`-based engine
- Respects: screen dimensions, font size, line height, page margins
- Pre-computes page breaks per chapter
- Consistent page numbering across the book

#### 5.1.5 Translation

- **Primary**: Cloudflare Worker proxy → GLM-4.7-Flash
- **Fallback**: ML Kit on-device offline translation
- User-configurable source and target languages
- Translations cached per page in Room database

#### 5.1.6 Cloudflare Worker (Translation Proxy)

| Property | Value |
|---|---|
| URL | `https://dual-reader-translate.dualreader.workers.dev` |
| Rate Limit | 200 requests/day/IP |
| Cooldown | 2 seconds between requests |
| API Key | Stored as Cloudflare secret (never in APK) |
| Model | GLM-4.7-Flash (free tier) |

#### 5.1.7 Bookmarks

- Add bookmark at current page with optional text note
- View all bookmarks in a **bottom sheet** overlay
- Navigate directly to any bookmark
- Delete individual bookmarks

#### 5.1.8 Settings

- **Font size** (adjustable)
- **Line spacing** (adjustable)
- **Page margins** (adjustable)
- **Reader theme** (6 built-in themes)
- **Translation provider** (Cloudflare Worker / ML Kit)
- **Target language** selection

#### 5.1.9 Reader Themes

| Theme | Description |
|---|---|
| Light | Standard light background |
| Dark | Dark background, light text |
| Sepia | Warm, paper-like tones |
| Ocean | Cool blue tones |
| Forest | Calming green tones |
| Midnight | Deep dark for night reading |

#### 5.1.10 Immersive Mode

- Hides status bar and navigation bar
- Distraction-free, full-screen reading experience
- Toggle via `isImmersiveMode` setting

#### 5.1.11 Navigation

- **Swipe** gestures for next/previous page
- **Arrow key** support (physical keyboards)
- **Slider** control for jumping to any page

#### 5.1.12 Data Persistence

| Storage | Data |
|---|---|
| Room Database | Books, Pages, Bookmarks |
| DataStore (Preferences) | Reading settings, theme choice, language prefs |

---

### 5.2 Polish Features (In Progress)

These features are currently being added to raise the app to production quality:

#### 5.2.1 App Icon

- Adaptive icon (foreground + background layers)
- Compliant with Android 8.0+ adaptive icon spec

#### 5.2.2 EPUB Cover Image Display

- Extract cover image from EPUB metadata
- Display cover art in library grid

#### 5.2.3 Import Progress Indicator

- Show progress bar or percentage during EPUB import
- Feedback for large books being parsed

#### 5.2.4 Text Search Within Book

- Full-text search across the current book
- Highlight matching results
- Navigate to search result positions

#### 5.2.5 Landscape / Tablet Optimization

- Responsive layouts for landscape orientation
- Optimized dual-panel layout for larger screens (tablets)
- Proper window size class handling

---

## 6. Security Requirements

| Requirement | Implementation |
|---|---|
| **No API keys in APK** | Translation API key stored as Cloudflare Worker secret |
| **Proxy architecture** | All translation requests go through Cloudflare Worker; client never contacts LLM API directly |
| **Rate limiting** | Enforced server-side: 200 req/day/IP, 2 s cooldown |
| **Local storage only** | No user data sent to external servers (except text for translation) |
| **No analytics/telemetry** | App does not collect or transmit usage data |

---

## 7. Data Flow

### 7.1 Book Import Flow

```
SAF File Picker → Copy to Internal Storage
        → EPUB Parser (epub4j + Jsoup)
            → Extract Metadata + Chapters + Full Text
                → Pagination Engine (compute page breaks)
                    → Store in Room DB (Book, Pages entities)
                        → Library UI refreshes
```

### 7.2 Reading Flow

```
User opens book → Load current page from Room
    → Display original text (left panel)
        → Request translation (if not cached)
            → Cloudflare Worker → GLM-4.7-Flash
            OR
            → ML Kit offline fallback
                → Display translated text (right panel)
                    → Cache translation in Room
```

### 7.3 Settings Flow

```
User changes setting → Update DataStore
    → ViewModel observes DataStore flow
        → UI recomposes with new settings
```

---

## 8. Screen Inventory

| Screen | Description |
|---|---|
| **Library** | Home screen. Grid of imported books, search, import FAB, empty state. |
| **Reader** | Dual-panel reading view. Page navigation, bookmarks, immersive mode. |
| **Settings** | Reading preferences: font, theme, margins, translation, language. |

---

## 9. Navigation Graph

```
Library
  ├── → Reader(bookId)
  └── → Settings

Reader(bookId)
  ├── BookmarkBottomSheet
  └── ← back → Library

Settings
  └── ← back → Library
```

---

## 10. Dependencies Summary

```kotlin
// Build configuration highlights
compileSdk = 37
targetSdk  = 37
minSdk     = 26

kotlin     = "2.3.21"
agp        = "9.2.1"
composeBom = "2026.05.01"
hilt       = "2.59.2"
room       = "2.8.4"
retrofit   = "3.0.0"
okhttp     = "5.3.2"
coil       = "3.4.0"
mlKitTranslate = "17.0.3"
```

---

## 11. Non-Functional Requirements

| Category | Requirement |
|---|---|
| **Performance** | EPUB import completes within seconds for typical books (< 10 MB). Page transitions are smooth (60 fps). |
| **Offline** | App is fully functional offline after initial book import. ML Kit provides offline translation fallback. |
| **Accessibility** | Support for system font scaling. High-contrast themes available (Dark, Midnight). |
| **Storage** | EPUBs copied to internal storage. Translations cached in Room. User can delete books to reclaim space. |
| **Compatibility** | Supports Android 8.0+ (API 26+). Targets latest stable SDK (37). |

---

## 12. Future Considerations

These items are **not** in scope for the current release but are noted for future development:

- Cloud sync for books and reading progress
- Additional translation providers (DeepL, Google Translate API)
- Annotation / highlight support
- PDF support
- Audiobook-style TTS integration
- Bookmarks export / import
- Multiple book collections / shelves
- Reading statistics and streaks

---

*Document generated: June 2026*
*Project: Dual Reader — `com.dualreader.app`*
