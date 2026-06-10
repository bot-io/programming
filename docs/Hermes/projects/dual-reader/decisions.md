# Dual Reader — Decisions

<!-- Append-only log. Add new decisions at the bottom. Never delete or edit existing entries. -->
<!-- Format: ### D-NNN: Title — YYYY-MM-DD -->
<!-- Context: ... Decision: ... Rationale: ... -->

### D-001: Cloudflare Worker proxy for translation — 2026-06-08
- **Context:** API keys must not be embedded in the APK for security.
- **Decision:** Use a Cloudflare Worker as a server-side proxy. App calls Worker, Worker calls Gemini/GLM with server-side keys.
- **Rationale:** CF Workers free tier (100K req/day) is sufficient. Zero infrastructure, zero cost. Keys never leave the server.

### D-002: 3-tier translation fallback chain — 2026-06-08
- **Context:** Free-tier providers have rate limits and reliability issues. Need resilience.
- **Decision:** Gemini 3.5 Flash (thinking) → Gemini 2.5 Flash → GLM-4.7-Flash → ML Kit (offline). Each tier has independent timeout.
- **Rationale:** Best quality first. GLM is free unlimited backup. ML Kit works offline. User explicitly prefers quality over speed.

### D-003: Context-aware batch translation — 2026-06-09
- **Context:** Page-by-page translation loses context across page breaks, producing disjointed results.
- **Decision:** Batch up to 3 pages per API call with previous-page context injected into prompt. Sentence-boundary splitting.
- **Rationale:** Literary translation quality is the top priority. Batching reduces round-trips and improves context continuity.

### D-004: File-based AppLogger — 2026-06-09
- **Context:** Huawei HK2 devices encrypt logcat output, making debug logging impossible.
- **Decision:** Custom AppLogger writes to app-specific file instead of logcat. Debug easter egg reads the log file.
- **Rationale:** User's device is Huawei. Must have reliable logging for debugging translation issues.

### D-005: Single-measurement pagination — 2026-06-10
- **Context:** Fullscreen toggle triggered re-pagination, causing translations to disappear.
- **Decision:** Paginate exactly once on first measurement. Fullscreen toggle only hides/shows bars as overlays. No re-pagination ever.
- **Rationale:** Pagination is expensive and disruptive. Translations are keyed to page indices; re-pagination invalidates them.

### D-006: Overlay bar layout — 2026-06-10
- **Context:** Top/bottom bars inside a Column pushed content area smaller. Pagination measured the minimized area.
- **Decision:** Box layout with bars as overlays (align TopStart/BottomStart). Content always fills full screen. Bars auto-hide on book open.
- **Rationale:** Bars should never affect text layout or pagination measurement. Overlay pattern is standard for reader apps.

### D-007: BatchTranslationResult with model tracking — 2026-06-10
- **Context:** Worker already returns model name in response, but app ignores it. Users want to know which model translated their pages.
- **Decision:** `BatchTranslationResult(val translations: Map<Int, String>, val model: String)` propagated through entire chain. Model stored per-page per-language in Room DB.
- **Rationale:** Transparency for users. Useful for debugging quality issues. Minimal overhead (one extra string per page).

### D-008: Multi-key Gemini pool — 2026-06-10
- **Context:** Gemini free tier is 250 RPD per key, shared across ALL users. Single key is the bottleneck for scaling.
- **Decision:** Worker rotates through N Gemini keys deterministically (hash(clientIp + date) % N). Supports GEMINI_KEYS JSON array or GEMINI_KEY_1..N secrets.
- **Rationale:** Zero cost, immediate Nx capacity. Same user gets same key all day (even distribution). Different users spread across keys.

### D-009: GLM uses open.bigmodel.cn, not api.z.ai — 2026-06-09
- **Context:** `api.z.ai` is unreachable from Cloudflare Workers edge nodes.
- **Decision:** Use `open.bigmodel.cn` endpoint for GLM calls. Z.AI key works on both endpoints.
- **Rationale:** Tested and confirmed. CF Workers can reach `open.bigmodel.cn` but not `api.z.ai`.

### D-010: GLM-4.7-Flash thinking disabled — 2026-06-09
- **Context:** GLM with thinking enabled produces `reasoning_content` that burns tokens and sometimes overshadows the actual translation.
- **Decision:** Send `thinking: { type: 'disabled' }` in GLM requests.
- **Rationale:** Saves tokens, faster responses, cleaner output. Quality is sufficient without reasoning for translation.
