---
aliases: [Cloudflare Worker, Translation API]
tags: [project, cloudflare, infrastructure]
url: "https://dual-reader-translate.dualreader.workers.dev"
account: "baivulcho@gmail.com"
account_id: "9b322c861e21f2ccd1d0b152e8371e0d"
---

# ☁️ Cloudflare Worker

Multi-provider translation API deployed on Cloudflare Workers.

## Endpoint

`https://dual-reader-translate.dualreader.workers.dev`

## Providers

| Priority | Provider | Model | Cost |
|----------|----------|-------|------|
| Primary | Gemini | 2.5 Flash | Free (250 RPD) |
| Fallback | GLM | 4.7-Flash | Free |

## Secrets

- `GEMINI_API_KEY` (optional)
- `GLM_API_KEY` (required)

## Notes

- ⚠️ Don't assume keys expired — 429 rate limit is far more common
- See [[Translation Quality]] for full architecture
