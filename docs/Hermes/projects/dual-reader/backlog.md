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
- **Status:** ready
- **Priority:** P1
- **Acceptance Criteria:**
  1. Night mode theme uses true black background (#000000) for OLED devices
  2. All text, icons, and UI chrome adapt to dark palette with sufficient contrast (WCAG AA minimum)
  3. Smooth transition animation when switching to/from night mode
  4. Existing themes continue to work; no visual regression
  5. Screenshot tests or visual regression tests for key screens in night mode
- **Notes:** Improvements to the existing night mode theme for better readability in low-light conditions.

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
- **Status:** ready
- **Priority:** P1
- **Acceptance Criteria:**
  1. Worker checks CF D1/KV for cached translations before calling Gemini
  2. Cache key: hash(sourceText + targetLang) → translatedText + model
  3. Popular books (same EPUB content) translate once, serve many users
  4. Cache TTL: 90 days for translations, cleaned on read
  5. `/status` endpoint reports cache hit rate
  6. Unit tests for cache lookup, storage, and TTL logic
- **Notes:** Major cost savings at scale. Popular titles could see 80%+ cache hits. CF D1 free tier: 5M reads/day, 100K writes/day.

### DR-009: Per-Device Free Quota
- **Status:** ready
- **Priority:** P1
- **Acceptance Criteria:**
  1. Each installation gets a daily free quota (e.g. 50 pages/day)
  2. Quota tracked via Installation ID (UUID generated on first install)
  3. Worker checks quota before processing translation requests
  4. App shows remaining quota in Settings
  5. When quota exceeded: user-friendly message, option to wait or upgrade
- **Notes:** Prevents abuse, enables freemium model. Requires D1 for quota storage.

### DR-010: Book Context for Translation Quality
- **Status:** ready
- **Priority:** P2
- **Acceptance Criteria:**
  1. First 3 pages of each book extracted as system-level context
  2. Context injected into translation prompt as "book context" (title, author, setting)
  3. Context cached per-book so re-translation doesn't re-extract
  4. Unit tests for context extraction and injection
- **Notes:** Low effort, high quality improvement. Helps with character names, setting, tone consistency from page 1.
