# Cloudflare Worker — Project Charter

## Summary
Multi-provider translation API deployed on Cloudflare Workers. Acts as a proxy for the Dual Reader Android app, holding API keys server-side.

## Endpoint
`https://dual-reader-translate.dualreader.workers.dev`

## Providers
- **Primary:** Gemini 2.5 Flash (Free, 250 RPD)
- **Fallback:** GLM-4.7-Flash (Free via open.bigmodel.cn)

## Architecture
- Gemini 3.5 Flash (thinking, 25s) → 2.5 Flash (10s) → GLM-4.7-Flash (20s, thinking disabled)
- `open.bigmodel.cn` endpoint (NOT `api.z.ai` — unreachable from CF edge)
- Worker cooldown 3s, client delay 3.5s
- App handles 429 with auto-retry + `retry_after_ms`

## Secrets
- `GEMINI_API_KEY` (optional)
- `GLM_API_KEY` (required)

## Account
- Email: baivulcho@gmail.com
- Account ID: 9b322c861e21f2ccd1d0b152e8371e0d

## Constraints
- Don't assume keys expired — 429 rate limit is far more common
- CF Worker has 30s hard timeout
- Free tier shared across models

## Related
- Dual Reader — the Android app consuming this API
- Translation Quality decision — context-aware batch architecture
