# Global Cross-Project Decisions

<!-- Append-only log. Add new decisions at the bottom. Never delete or edit existing entries. -->

## ADR Index

| Decision | Project | Date |
|----------|---------|------|
| [Translation Quality](translation-quality.md) | dual-reader | 2026-06-04 |

---

## ADR-001: Context-Aware Batch Translation
- **Project:** dual-reader
- **Context:** Page-by-page translation produces poor results — no context, mid-sentence splits
- **Decision:** Sentence-boundary pagination + batch translation (3-5 pages/call) with previous-page context
- **Consequences:** Better translation quality at the cost of slightly higher latency per batch
- **Alternatives:** Simple page-by-page (rejected — low quality), full-chapter context (rejected — token limits)
- **See:** [translation-quality.md](translation-quality.md) for full spec

## ADR-002: Cloudflare Worker as Translation Proxy
- **Project:** dual-reader, cloudflare-worker
- **Context:** API keys must not be embedded in APK
- **Decision:** Cloudflare Worker at `dual-reader-translate.dualreader.workers.dev` holds keys server-side
- **Consequences:** Keys secure; adds network hop latency; free tier rate limits shared
- **Alternatives:** Firebase Functions (rejected — more setup), direct API calls (rejected — key exposure)

## ADR-003: GLM via open.bigmodel.cn
- **Project:** cloudflare-worker
- **Context:** `api.z.ai` unreachable from Cloudflare edge nodes
- **Decision:** Use `open.bigmodel.cn` endpoint for GLM API calls from the Worker
- **Consequences:** Z.AI key works on both; no separate key needed

## ADR-004: Quality Over Speed
- **Project:** dual-reader
- **Context:** User explicitly prefers waiting for better Gemini 3.5 Flash output vs fast fallbacks
- **Decision:** Gemini 3.5 Flash with thinking as primary provider despite 25s latency
- **Consequences:** Higher quality translations; user accepts wait
