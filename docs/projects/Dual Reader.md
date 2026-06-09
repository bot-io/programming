---
aliases: [Dual Reader, dual-reader]
tags: [project, android, active]
stack: "Kotlin, Jetpack Compose, AGP 9.2.1"
status: active
location: "dual-reader-android/"
---

# 🏗 Dual Reader

Android bilingual ebook reader with multi-provider translation.

## Stack

- **AGP:** 9.2.1 | **Kotlin:** 2.3.21 | **JDK:** 21
- **compileSdk:** 37 | **Compose BOM:** 2026.05.01
- 223 unit tests passing | Release APK ~20MB

## Features

### Core Reading
- SAF import for EPUB files
- Split reader: vertical (phone portrait) or side-by-side (tablet/landscape ≥600dp)
- **Dynamic pagination** — measures actual text panel at runtime, re-paginates when fullscreen toggled
- **Tap navigation** — tap left third for previous page, right third for next page, center to toggle bars
- Text search with highlighted results
- Bookmarks with notes (add, delete, navigate)
- Cover display in library

### Translation
- Multi-provider translation: Gemini 3.5 Flash → Gemini 2.5 Flash → GLM-4.7-Flash
- [[Translation Quality]] — Context-aware batch translation (5 pages/call, 10k chars max)
- Per-language translation cache (Room DB)
- Translation cached locally, survives app restart
- Cloudflare Worker proxy at `dual-reader-translate.dualreader.workers.dev`
- 60s client timeout for slow Gemini free tier

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
- **7-tap debug easter egg** — tap version text in About 7 times to show crash log + logcat

### Technical
- R8/Proguard minification enabled
- Room DB v4 with destructive migration fallback
- Hilt DI, MVVM architecture
- `FallbackTranslationService` — 3-tier cloud → ML Kit on-device fallback

## Key Decisions

- [[Translation Quality]] — Context-aware batch translation architecture
- [[Cloudflare Worker]] — Multi-provider translation API at `dual-reader-translate.dualreader.workers.dev`
- API keys never in APK — Cloudflare Worker proxy holds them server-side
- Pagination uses `StaticLayout` for pixel-accurate page breaks, sentence-boundary splitting
- Android ICU regex: no unbounded lookbehinds (`*` inside `(?<=...)` crashes)
- `file`-level `val`s crash class loading from ANY screen → use lazy or function-local

## Gotchas

- ⚠️ NEVER add `.clickable` to content area — interferes with tap navigation
- WindowInsets: `systemBars` on outermost Box only
- epub4j needs xmlpull + kxml2 excluded
- Gemini free tier 503s VERY often — #1 cause of GLM fallback
- CF Worker has 30s hard timeout — batch with thinking may approach this
- Telegram APK sends: 20MB files often trigger gateway timeout but upload succeeds — do NOT retry
