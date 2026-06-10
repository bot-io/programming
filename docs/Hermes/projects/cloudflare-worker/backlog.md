# Cloudflare Worker — Backlog

### CW-001: Add Gemini 3.5 Flash Thinking to Fallback Chain
- **Status:** done
- **Priority:** P0
- **Acceptance Criteria:**
  1. Worker tries Gemini 3.5 Flash with thinking enabled as first provider
  2. Falls back to Gemini 2.5 Flash on timeout/error
  3. Falls back to GLM-4.7-Flash as last resort
- **Notes:** Implemented. Quality over speed per user preference.

### CW-002: GLM-4.7-Flash Thinking Disabled
- **Status:** done
- **Priority:** P1
- **Acceptance Criteria:**
  1. GLM-4.7-Flash requests include `thinking:{type:'disabled'}` to prevent burning tokens on reasoning
- **Notes:** Implemented. Without this, GLM burns tokens on chain-of-thought.
