# Dual Reader — Project Charter

## Summary
Android bilingual ebook reader that displays two languages side-by-side, with integrated machine translation for seamless foreign-language reading. Aiming for Play Store release.

## Repository
`D:\programming\cross-platform\dual-reader\dual-reader-android\` (Android app)
`D:\programming\Tools\translate-proxy\` (Cloudflare Worker)

## Tech Stack
- **Language:** Kotlin 2.3.21 | **JDK:** 21
- **UI:** Jetpack Compose | **DI:** Hilt | **Architecture:** MVVM
- **Build:** AGP 9.2.1, compileSdk 37, Compose BOM 2026.05.01
- **DB:** Room v5 with migration chain (1→5)
- **Testing:** 255 unit tests, all passing | Release APK ~20MB
- **Minification:** R8 + resource shrinking enabled
- **Worker:** Cloudflare Workers (free tier), 757 LOC

## Current Features

### Core Reading
- SAF import for EPUB files
- Split reader: vertical (phone portrait) or side-by-side (tablet/landscape ≥600dp)
- **Single-measurement pagination** — measures once at full-screen area (bars overlay, never affect sizing)
- **Tap navigation** — left third = prev page, right third = next, center = toggle bars
- Overlay top/bottom bars (auto-hidden on book open, tap to toggle)
- Text search with highlighted results
- Bookmarks with notes (add, delete, navigate)
- Cover display in library

### Translation
- Multi-provider: Gemini 3.5 Flash (thinking) → Gemini 2.5 Flash → GLM-4.7-Flash → ML Kit (offline)
- Context-aware batch translation (3 pages/call, 10k chars max)
- Per-language translation cache (Room DB)
- Cloudflare Worker proxy at `dual-reader-translate.dualreader.workers.dev`
- Multi-key Gemini pool (GEMINI_KEYS JSON array or GEMINI_KEY_1..N)
- `/status` endpoint for pool health monitoring
- 120s client timeout, 429 auto-retry with retry_after_ms
- `FallbackTranslationService` — 3-tier cloud → ML Kit on-device fallback
- **Model tracking** — worker returns model name, app logs and stores which model translated each page
- **Translation info screen** — tap "Cached translations" in Settings to see per-page languages + models

### UI & Theming
- 6 built-in themes (Dark, Light, Sepia, Ocean, Forest, Midnight)
- Fullscreen/immersive mode toggle (no re-pagination)
- Text selection (SelectionContainer)
- Copyable error messages
- Sentence counter with numbered markers (toggle in Settings)

### Settings
- Font size, line height, target language
- Screen wake timeout (0 = disabled, up to 60 min)
- Sentence counter toggle
- Translation info dialog (per-page languages + models)
- **7-tap debug easter egg** — tap version text in About 7× to show crash log + logcat

### Infrastructure
- File-based AppLogger (bypasses Huawei HK2 encrypted logcat)
- Room DB migration chain 1→5 (translationsJson, translationModelsJson columns)

## Goals
- Deliver a polished bilingual reading experience on Android
- Context-aware, high-quality machine translation
- Play Store release (targeting initial launch)
- Rich library management and reading progress tracking
- Export capabilities for annotations and highlights

## Constraints
- Android-only (no iOS/web plans)
- Translation must be resilient across providers (fallback chain)
- All code changes require automated tests; full suite green before merge
- API keys never in APK — Cloudflare Worker holds them server-side
- Cost-conscious: prefer free tiers (Gemini free, GLM free, CF Workers free)

## Gotchas
- ⚠️ NEVER add `.clickable` to content area — interferes with tap navigation
- WindowInsets: `systemBars` on outermost Box only
- epub4j needs xmlpull + kxml2 excluded
- Gemini free tier 503s VERY often — #1 cause of GLM fallback
- CF Worker has NO wall-clock timeout — only CPU time limited
- Android ICU regex: no unbounded lookbehinds (`*` inside `(?<=...)` crashes)
- `file`-level `val`s crash class loading from ANY screen → use lazy or function-local
- Telegram APK sends: 20MB files often trigger gateway timeout but upload succeeds — do NOT retry
- `api.z.ai` unreachable from CF Workers edge — must use `open.bigmodel.cn`
- GLM-4.7-Flash must have thinking disabled or burns tokens on reasoning_content

## Related
- Cloudflare Worker project — translation API infrastructure (`D:\programming\Tools\translate-proxy\`)
- Translation Quality decision — context-aware batch architecture
