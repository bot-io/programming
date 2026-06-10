# Cloudflare Worker — Decisions

<!-- Append-only. Newest at top. -->

## 2026-06-10 — GLM via open.bigmodel.cn not api.z.ai
- **Context:** api.z.ai unreachable from Cloudflare edge nodes
- **Decision:** Use open.bigmodel.cn endpoint for GLM API calls
- **Consequence:** Z.AI key works on both endpoints; no separate key needed

## 2026-06-10 — Quality over speed for translation
- **Context:** User explicitly prefers waiting for better Gemini 3.5 Flash output
- **Decision:** Keep thinking-enabled model as primary despite longer latency
- **Consequence:** Higher quality translations; user accepts 25s wait for primary
