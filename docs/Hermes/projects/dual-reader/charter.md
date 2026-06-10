# Dual Reader — Project Charter

## Summary
Android bilingual ebook reader that displays two languages side-by-side, with integrated machine translation for seamless foreign-language reading.

## Repository
`dual-reader-android/` (inside `D:\programming\`)

## Tech Stack
- **Language:** Kotlin 2.3.21 | **JDK:** 21
- **UI:** Jetpack Compose | **DI:** Hilt | **Architecture:** MVVM
- **Build:** AGP 9.2.1, compileSdk 37, Compose BOM 2026.05.01
- **DB:** Room v4 with destructive migration fallback
- **Testing:** 138 unit tests currently passing | Release APK ~20MB
- **Minification:** R8/Proguard enabled

## Current Features

### Core Reading
- SAF import for EPUB files
- Split reader: vertical (phone portrait) or side-by-side (tablet/landscape ≥600dp)
- **Dynamic pagination** — measures actual text panel at runtime, re-paginates on fullscreen toggle
- **Tap navigation** — left third = prev page, right third = next, center = toggle bars
- Text search with highlighted results
- Bookmarks with notes (add, delete, navigate)
- Cover display in library

### Translation
- Multi-provider: Gemini 3.5 Flash (thinking) → Gemini 2.5 Flash → GLM-4.7-Flash
- Context-aware batch translation (3 pages/call, 10k chars max)
- Per-language translation cache (Room DB)
- Cloudflare Worker proxy at `dual-reader-translate.dualreader.workers.dev`
- 60s client timeout for slow Gemini free tier
- `FallbackTranslationService` — 3-tier cloud → ML Kit on-device fallback

### UI & Theming
- 6 built-in themes (Dark, Light, Sepia, Ocean, Forest, Midnight)
- Fullscreen/immersive mode toggle
- Text selection (SelectionContainer)
- Copyable error messages
- Sentence counter with numbered markers (toggle in Settings)

### Settings
- Font size, line height, target language
- Screen wake timeout (0 = disabled, up to 60 min)
- Sentence counter toggle
- **7-tap debug easter egg** — tap version text in About 7× to show crash log + logcat

## Goals
- Deliver a polished bilingual reading experience on Android
- Context-aware, high-quality machine translation
- Rich library management and reading progress tracking
- Export capabilities for annotations and highlights

## Constraints
- Android-only (no iOS/web plans)
- Translation must be resilient across providers (fallback chain)
- All code changes require automated tests; full suite green before merge
- API keys never in APK — Cloudflare Worker holds them server-side

## Gotchas
- ⚠️ NEVER add `.clickable` to content area — interferes with tap navigation
- WindowInsets: `systemBars` on outermost Box only
- epub4j needs xmlpull + kxml2 excluded
- Gemini free tier 503s VERY often — #1 cause of GLM fallback
- CF Worker has 30s hard timeout — batch with thinking may approach this
- Android ICU regex: no unbounded lookbehinds (`*` inside `(?<=...)` crashes)
- `file`-level `val`s crash class loading from ANY screen → use lazy or function-local
- Telegram APK sends: 20MB files often trigger gateway timeout but upload succeeds — do NOT retry

## Related
- Cloudflare Worker project — translation API infrastructure
- Translation Quality decision — context-aware batch architecture
