# Dual Reader — Backlog

### DR-001: Context-Aware Batch Translation
- **Status:** done
- **Priority:** P0
- **Acceptance Criteria:**
  1. Translation splits source text at sentence boundaries before sending to API
  2. Previous page context (last 2–3 sentences) is included with each translation request to improve coherence
  3. Translation processes pages in batches of up to 3 pages per API call
  4. Unit tests cover sentence boundary detection, batch assembly, and context injection
  5. Existing translation tests continue to pass; no regression
- **Notes:** Completed in v1.0.22–v1.0.26. Batch translation with collectBatch, sentence-boundary splitting, context propagation across pages.

### DR-002: Translation Test Coverage
- **Status:** done
- **Priority:** P0
- **Acceptance Criteria:**
  1. Translation module has ≥80% line coverage (measured by JaCoCo or equivalent)
  2. Tests cover: provider selection, fallback logic, batch assembly, sentence boundary detection, error handling (timeouts, invalid responses)
  3. Integration test verifies end-to-end translation with a mock API returning realistic responses
  4. Coverage report can be generated via `./gradlew task` and results are documented
- **Notes:** Done. Added 178 new tests across 4 test classes. Suite: 316 tests, 0 failures. Commit: 10757f2.

### DR-003: Night Mode Reading Experience
- **Status:** done
- **Priority:** P1
- **Acceptance Criteria:**
  1. Night mode theme uses true black background (#000000) for OLED devices
  2. All text, icons, and UI chrome adapt to dark palette with sufficient contrast (WCAG AA minimum)
  3. Smooth transition animation when switching to/from night mode
  4. Existing themes continue to work; no visual regression
  5. Screenshot tests or visual regression tests for key screens in night mode
- **Branch:** `feat/DR-003-night-mode` pushed (PR creation blocked by token scope)
- **Notes:** Implemented NIGHT enum value, NightColorScheme Material3 theme, animatedReaderColors() with 400ms cross-fade, colorSchemeForTheme mapping for all 7 themes. 30 new tests all passing. WCAG AAA contrast (12.4:1) on true black.

### DR-004: Library Management (Tags, Collections, Sorting)
- **Status:** needs-decision
- **Priority:** P1
- **Acceptance Criteria:**
  1. User can assign custom tags to books and filter library by tag
  2. User can create named collections and add/remove books from them
  3. Library supports sorting by: title, author, date added, last read, completion percentage
  4. Tag and collection data persists across app restarts (Room DB migration if needed)
  5. UI follows Material Design 3 patterns; Compose previews for key components
- **Notes:** Needs user input on scope — full collections or simple tags-first approach? Also need to decide on DB schema changes.

### DR-005: Reading Progress Tracking with Persistence
- **Status:** ready
- **Priority:** P1
- **Acceptance Criteria:**
  1. App remembers last-read position per book and reopens to that position
  2. Progress percentage is displayed in library view for each book
  3. Progress data persists across app restarts and survives app updates
  4. Progress syncs correctly when switching between devices (if applicable — needs decision)
  5. Unit tests for progress calculation, persistence, and restoration logic
- **Notes:** Basic feature expectation. May need cloud sync scope clarification.

### DR-006: Export Annotations and Highlights
- **Status:** ready
- **Priority:** P2
- **Acceptance Criteria:**
  1. User can select one or more annotations/highlights and export them
  2. Export formats: plain text and Markdown (initially); JSON as option
  3. Export uses SAF (Storage Access Framework) so user chooses destination
  4. Exported file includes: book title, author, page/location, highlighted text, any user notes
  5. Unit tests for export formatting logic and SAF integration
- **Notes:** Lower priority but straightforward to implement. Depends on having annotations/highlights data model in place.

### DR-007: Play Store Launch Preparation
- **Status:** ready
- **Priority:** P0
- **Acceptance Criteria:**
  1. App icon designed and integrated (adaptive icon for all densities)
  2. Splash screen / launch screen implemented
  3. Privacy policy URL hosted and linked in app
  4. Content rating questionnaire completed
  5. Play Store listing: description, screenshots (phone + tablet), feature graphic
  6. Signing config finalized (release keystore backed up securely)
  7. ProGuard/R8 rules verified — no runtime crashes from obfuscation
- **Notes:** Blocking release. Items 1–5 are user-facing creative work; items 6–7 are technical.

### DR-008: D1 Translation Cache (Cross-User Sharing)
- **Status:** done
- **Priority:** P1
- **Acceptance Criteria:**
  1. Worker checks CF D1 for cached translations before calling Gemini ✅ getCachedTranslation / getCachedTranslations
  2. Cache key: hash(sourceText + targetLang) → translatedText + model ✅ SHA-256 via Web Crypto API
  3. Popular books (same EPUB content) translate once, serve many users ✅ Same text + lang = same cache key
  4. Cache TTL: 90 days for translations, cleaned on read ✅ Lazy cleanup on lookup
  5. `/status` endpoint reports cache hit rate ✅ getCacheStats returns total_entries, expired_entries, languages
  6. Unit tests for cache lookup, storage, and TTL logic ✅ 35 new tests
- **Notes:** D1 database needs to be created via `wrangler d1 create dual-reader-cache` and migration applied. database_id placeholder in wrangler.toml needs updating.

### DR-009: Per-Device Free Quota
- **Status:** done
- **Priority:** P1
- **Acceptance Criteria:**
  1. Each installation gets a daily free quota (e.g. 50 pages/day) ✅ Default 50 pages/device/day
  2. Quota tracked via Installation ID (UUID generated on first install) ✅ InstallationIdProvider stores UUID in DataStore
  3. Worker checks quota before processing translation requests ✅ checkDeviceQuota / incrementDeviceQuota in src/quota.js
  4. App shows remaining quota in Settings ✅ Daily Translation Quota section with progress bar, color-coded warnings
  5. When quota exceeded: user-friendly message, option to wait or upgrade ✅ Error message + "resumes tomorrow at midnight UTC"
- **Notes:** Prevents abuse, enables freemium model. D1 table device_quota with installation_id+date composite PK. Worker: quota.js (153 LOC, 30 tests). Android: InstallationIdProvider, QuotaApi, quota UI in SettingsScreen. All builds pass.

### DR-010: Book Context for Translation Quality
- **Status:** ready
- **Priority:** P2
- **Acceptance Criteria:**
  1. First 3 pages of each book extracted as system-level context
  2. Context injected into translation prompt as "book context" (title, author, setting)
  3. Context cached per-book so re-translation doesn't re-extract
  4. Unit tests for context extraction and injection
- **Notes:** Low effort, high quality improvement. Helps with character names, setting, tone consistency from page 1.
