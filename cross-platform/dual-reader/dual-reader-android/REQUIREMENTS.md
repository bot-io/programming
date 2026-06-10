# Dual Reader — Requirements & Design Decisions

## Core Requirements

### Pagination
- **Pagination must happen exactly once** when the reader layout is first measured.
- **Fullscreen toggle must NOT trigger re-pagination.** Page count, page boundaries, and page indices stay fixed regardless of whether the top/bottom bars are visible.
- The content area scrolls within the current page; it does NOT re-paginate when the usable area grows or shrinks due to bar visibility.

### Translation
- **API keys must NEVER be in the APK.** All LLM calls go through the Cloudflare Worker proxy.
- Translation quality is a top priority. Context-aware, sentence-boundary splitting, batch of 3 pages per call.
- **Quality over speed** — user explicitly prefers waiting for better Gemini output vs fast fallback to weaker models.
- 3-tier fallback chain: Gemini 3.5 Flash (thinking) → Gemini 2.5 Flash → GLM-4.7-Flash → ML Kit (offline last resort).
- Translations are cached locally per language. Re-translating the same text updates the cache.
- **Re-pagination must preserve translations.** If pagination does change (e.g., font size change), translations are restored via exact cache match + substring fallback from old pages.
- App must handle 429 (rate limit) gracefully: read `retry_after_ms` from worker response, wait, retry (up to 3×).
- Batch translation: max 3 pages per request, max 10000 chars total input.

### UI
- **No hardcoded pixel dimensions.** All sizing must be fluid and responsive via dp/sp.
- **Top bar and bottom bar OVERLAY on top of content.** They must never resize the text area.
  - Bars use semi-transparent backgrounds with shadow elevation.
  - Slide in/out from top/bottom with expand/shrink animation.
  - Hidden by default when a book is opened. Tap center of screen to toggle.
- Sentence numbering: inline superscript AnnotatedString (not two-column layout).
- Translation display: original text with inline superscript numbers, translated text with matching numbers below.
- About section shows version; version does NOT appear in visible UI titles.
- **Cached translations info**: accessible via settings menu, shows per-page list of translated languages and models used.

### Error Handling
- Every bug fix must have test coverage before shipping.
- Huawei HK2 encrypts logcat output — use file-based AppLogger, not logcat.
- When crash cause is unknown: add crash reporter, don't guess.

### Data
- Room DB with `fallbackToDestructiveMigration()`.
- Per-language translation cache (TranslationCacheRepository, keyed by text hash + language).
- Pages carry translations via `translations: Map<String, String>` on the Page entity.

### Build & Release
- Version numbering: increment patch primarily. Format: `v1.0.X`.
- APK filenames must include version number (e.g., `dual-reader-v1.0.29.apk`).
- R8/minification enabled.
- Telegram APK sends: send once, notify, let user confirm receipt. Do NOT retry on timeout.

### Cloudflare Worker
- Worker at `https://dual-reader-translate.dualreader.workers.dev`
- GLM endpoint: `open.bigmodel.cn` (NOT `api.z.ai` — unreachable from CF Workers edge).
- GLM-4.7-Flash requires `thinking: { type: 'disabled' }` or it burns all tokens on reasoning.
- Gemini free tier: 250 RPD per API key. Both Gemini models share same key quota.
- Worker has no wall-clock timeout — only CPU time is limited. I/O wait does not count.
- Diagnostic endpoint: `GET /test/glm`.
