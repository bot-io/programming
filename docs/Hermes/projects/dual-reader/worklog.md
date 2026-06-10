# Dual Reader — Worklog

<!-- Append-only log. Add entries at the bottom. Never delete or edit existing entries. -->
<!-- Format: ### YYYY-MM-DD — <Session ID> — <Summary> -->

### 2026-06-10 — telegram-session — v1.0.30: overlay bars, model tracking, translation info, test fixes

**Context:** User reported 5 issues: bars push content, bars visible on open, pagination measures minimized area, no model logging, no translation info screen.

**Work done:**
- Restructured `ReaderScreen.kt` from Column layout to Box overlay layout (bars float on top of content)
- Changed `barsVisible` initial value to `false` (bars auto-hide on book open)
- Pagination now measures against full-screen area (bars never affect measurement)
- Added `BatchTranslationResult` data class wrapping `translations: Map<Int, String>` + `model: String`
- Propagated model name through entire flow: Worker → CloudTranslationServiceImpl → TranslatePageUseCase → ReaderViewModel → AppLogger
- Added `translationModels: Map<String, String>` to Page entity (lang→model per page)
- Room DB v5 migration adds `translationModelsJson` column
- Added translation info dialog in Settings (tap "Cached translations" to see per-page languages + models)
- Fixed all test compilation: ReaderViewModelTest, CloudTranslationServiceImplTest, TranslatePageUseCaseTest updated for BatchTranslationResult
- 255/255 unit tests passing
- Built and shipped v1.0.30 APK

**Worker changes:**
- Implemented multi-key Gemini pool in Worker (`resolveGeminiKeys()`)
- Supports GEMINI_KEYS (JSON array), GEMINI_KEY_1..N, or legacy GEMINI_API_KEY
- Deterministic key selection: hash(clientIp + date) % keys.length
- Added `GET /status` endpoint for pool health monitoring
- Deployed to Cloudflare

**Git:** `bc52885` (v1.0.30), `89a8d13` (multi-key pool)

### 2026-06-10 — telegram-session — v1.0.29: fullscreen no-repaginate + 17 tests

- Pagination happens exactly once (first measurement). Fullscreen toggle does NOT re-paginate.
- Added `isRePaginating` flag and `rePaginate()` method tests.
- 17 new tests for translation/pagination flow.
- Git: `603c456`

### 2026-06-09 — telegram-sessions — v1.0.20–v1.0.28: translation pipeline hardening

- v1.0.20: AppLogger (file-based, bypasses Huawei HK2 encrypted logcat)
- v1.0.22: Fixed worker batch index mapping (was sequential 0,1,2 instead of actual page indices)
- v1.0.24: Auto-restore cached translations after re-pagination (content matching)
- v1.0.25: Quality-first timeouts (25s Gemini thinking, 120s device)
- v1.0.26: Per-model timeout config, provider logging
- v1.0.27: 429 retry with retry_after_ms, 3.5s cooldown delay
- v1.0.28: Substring matching restores translations after re-pagination
- Worker: GLM endpoint fix (open.bigmodel.cn), thinking disabled, tighter timeouts

### 2026-06-08 — earlier sessions — v1.0.1–v1.0.19: core app buildout

- EPUB import + parsing (epub4j with xmlpull/kxml2 exclusions)
- Compose UI with split reader (vertical/side-by-side)
- Room DB with migration chain (v1→v4)
- Translation service with 3-tier fallback (Gemini → GLM → ML Kit)
- Cloudflare Worker proxy for API key protection
- 6 themes, bookmarks, text search, tap navigation
- Hilt DI, MVVM architecture
