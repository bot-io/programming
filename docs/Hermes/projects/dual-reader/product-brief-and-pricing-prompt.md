# Dual Reader — Product Brief & Commercial Analysis Prompt

*Prepared for: Commercial Strategy AI Expert*
*Date: August 2026*

---

## 1. Product Overview

**Dual Reader** is an Android application designed for language learners and bilingual readers. Users import EPUB ebooks, and the app translates them page-by-page using AI, displaying the original text and translation side-by-side or interleaved. It also features text-to-speech for both the translated and original text, configurable display layouts, and offline translation support.

**Target audience:**
- Language learners (intermediate to advanced) who read foreign-language books
- Bilingual readers who want to compare original and translated texts
- Students and self-learners studying literature in original languages
- Expatriates and immigrants maintaining literacy in their native language

**Platform:** Android (min SDK 26 / Android 8.0, target SDK 37)
**Distribution:** Google Play Store
**Architecture:** Native Kotlin + Jetpack Compose, MVVM with Hilt DI, Room database, Cloudflare Worker backend

---

## 2. Feature Set

### Core Reading
- **EPUB import**: Users import any EPUB file from their device storage
- **Bilingual display modes**: SPLIT (original + translation side-by-side) and INTERLEAVED (paragraph-by-paragraph)
- **Configurable translation position**: Translation above or below the original text (default: above, to aid language learning)
- **7 reading themes**: Multiple dark/light color schemes with smooth color transitions
- **Pagination**: Native paginated reading (not scroll-based) with configurable font size and display density
- **Navigation slider**: Bottom slider with snap marks for quick page navigation, with position history (back/forward)
- **Bookmarks**: Save and jump to specific pages
- **Library management**: Organize books with tags, search, sort

### Translation Engine
- **AI-powered translation** via cloud proxy (Cloudflare Worker):
  - Primary: Google Gemini 2.5 Flash (high quality, fast)
  - Fallback 1: Gemini 2.0 Flash (cheaper, reliable)
  - Fallback 2: Z.AI GLM-4.7-Flash (free, unlimited, China-based)
  - Multi-key pooling: Rotates across multiple Gemini API keys to maximize free tier usage
- **Offline translation** via Google ML Kit: On-device neural translation, zero API cost, zero internet required. Supports downloading language models for offline use.
- **Book context injection**: Extracts title, author, and opening pages as context to improve translation consistency (character names, setting, tone)
- **Per-paragraph translation**: Users can translate individual paragraphs or entire pages. Re-translate buttons allow trying alternative translations.
- **Cross-user translation cache** (D1 database): When any user translates a page, the result is cached. If another user translates the same page in the same language pair, the cached result is served instantly at zero API cost.

### Text-to-Speech (Read Aloud)
- **Per-paragraph TTS**: Tap a speaker icon on any translated paragraph to hear it spoken
- **Continuous read-through**: Top-bar play button starts continuous playback from the current position, progressing through the entire book automatically
- **Alternating languages**: Optional setting to read both the translation AND the original text for each paragraph (translation → original → next paragraph). Aids immersion learning.
- **Auto-scroll**: The reader auto-scrolls to keep the paragraph being read centered on screen during playback
- **Adjustable reading speed**: Slider from 0.5× to 2.0× (default 1.0×)
- **No delay between languages**: Original text reads immediately after translation when alternating mode is enabled

### Settings & Customization
- Font size, line spacing, display density
- 7 reading color themes (Sepia, Dark, Light, etc.)
- Translation position (above/below original)
- Translation display mode (split/interleaved)
- TTS speech rate
- TTS read-original toggle
- Daily translation quota display with progress bar and color-coded warnings

### Monetization (Freemium)
- **FREE tier**: 10 pages/day AI translation quota, 1 book in library, unlimited offline ML Kit translation (no daily limit)
- **PRO tier** (one-time purchase, product ID `pro_unlock`): 50 pages/day, unlimited books in library
- **PREMIUM tier** (subscription, product IDs `premium_monthly` / `premium_yearly`): Unlimited AI translation, priority model access (Gemini 3.5 Flash with thinking), translation history & export, cloud sync (coming soon)

### Legal & Compliance
- Comprehensive Terms of Service covering: freemium model, on-device vs cloud translation distinction, subscription terms, liability
- Privacy Policy covering: ML Kit usage, billing data handling, zero personal data collection
- Both documents bundled in-app (Settings → links) and designed for public URL hosting

---

## 3. Technical Architecture & Cost Structure

### Translation API Costs (the primary variable cost)

**Provider pricing at paid rates:**

| Provider | Model | Input Cost | Output Cost | Notes |
|----------|-------|-----------|-------------|-------|
| Google Gemini | 2.5 Flash | $0.075 / 1M tokens | $0.30 / 1M tokens | Primary, high quality |
| Google Gemini | 2.0 Flash | $0.015 / 1M tokens | $0.06 / 1M tokens | Cheaper fallback |
| Z.AI GLM | 4.7 Flash | Free (currently) | Free | Unlimited, but higher latency |
| Google ML Kit | On-device | $0 | $0 | Offline, no API call |

**Per-page cost estimate (paid Gemini 2.5 Flash rates):**
- Average page: ~300 words ≈ ~400 input tokens + ~400 output tokens
- Cost per page: (400 × $0.075 + 400 × $0.30) / 1,000,000 = **~$0.00018/page**
- A 300-page book: ~**$0.054** in API costs (first read, no cache)
- With D1 cache hit (same page translated by any user before): **$0.00** (cache lookup is free)

**Current free tier utilization:**
- Gemini free tier: ~250 requests/day per API key, multi-key pooling implemented
- GLM: Free, unlimited
- Effective free capacity: **~750-1000 pages/day** across all users combined (Gemini pool) + unlimited via GLM fallback

### Infrastructure Costs

| Component | Free Tier | Paid Tier | When Needed |
|-----------|-----------|-----------|-------------|
| Cloudflare Workers | 100K req/day | $5/mo → 10M req/day | At ~3,000+ active daily users |
| Cloudflare D1 (cache DB) | 5M reads/day, 100K writes/day | $0.75/GB stored beyond free | Very generous; unlikely needed soon |
| Google ML Kit | Unlimited (on-device) | N/A | Never costs anything |

### Google Play Fees
- 15% on first $1M revenue per year
- 30% above $1M/year
- Applies to both one-time purchases and subscriptions

### Key Cost Insight
**The D1 cross-user cache is the critical margin protector.** Popular books (e.g., Harry Potter in Spanish→English, common classics) will have near-zero API cost after the first user translates them. Niche/rare books cost full API rates on first read. The cache also makes the free tier sustainable — popular content is served from cache at zero cost.

---

## 4. Current Freemium Model Details (as implemented in code)

| Feature | FREE | PRO (one-time) | PREMIUM (subscription) |
|---------|------|-----------------|----------------------|
| AI pages/day | 10 | 50 | Unlimited |
| Offline ML Kit | Unlimited | Unlimited | Unlimited |
| Library books | 1 | Unlimited | Unlimited |
| Translation quality | Standard (Gemini 2.5/2.0/GLM) | Standard | Priority (Gemini 3.5 Flash) |
| Translation cache | ✓ (shared) | ✓ (shared) | ✓ (shared) |
| TTS (read aloud) | ✓ | ✓ | ✓ |
| Translation history & export | ✗ | ✗ | ✓ |
| Cloud sync | ✗ | ✗ | Coming soon |
| Per-device quota tracking | Installation ID | Installation ID | Installation ID |

**Quota enforcement**: Each installation gets a UUID (Installation ID). Daily quota is tracked per-installation in the D1 database (device_quota table, installation_id + date composite primary key). Resets at midnight UTC.

---

## 5. Competitor Landscape

| App | Model | Price Range | Key Differentiator |
|-----|-------|------------|-------------------|
| **BookTranslator** | Per-book translation | ~$3-5/book | Translation-only, not a reader |
| **Interlinear Books** | Per-book purchase | $5-10/book | Pre-translated books, limited catalog |
| **Beelinguapp** | Freemium + ads | Free / ~$30/year premium | Karaoke-style reading, large content library (not user's own books) |
| **LingQ** | Subscription | $13-40/month | Full language learning platform, not focused on book reading |
| **Readlang** | Freemium | Free / $5/month | Browser-based, flashcards |
| **Dual Reader** (us) | Freemium | TBD | User's own EPUBs, high-quality AI translation, bilingual TTS, cross-user cache, offline support |

---

## 6. Prompt for Commercial Strategy AI Expert

> I'm launching an Android app called "Dual Reader" on Google Play. It's a bilingual book reader for language learners — users import their own EPUB books, and the app translates them page-by-page using AI, displays original text + translation side-by-side (or interleaved paragraph-by-paragraph), and features text-to-speech for both languages with adjustable speed and alternating playback modes. It also has offline translation via Google ML Kit as a zero-cost fallback.
>
> **The full product brief, technical architecture, cost structure, competitor analysis, and current freemium model are detailed above in sections 1-5. Please read those sections before answering.**
>
> **What I need from you:**
>
> 1. **Price recommendations** for each tier:
>    - `pro_unlock` (one-time purchase): What's the sweet spot? The user gets 50 pages/day forever. Consider that it's a lifetime purchase — no recurring revenue, but the user's ongoing API cost is capped at 50 pages/day × $0.00018 = ~$0.009/day = ~$3.29/year worst case (likely much less with cache hits).
>    - `premium_monthly`: Monthly subscription for unlimited translation + priority model. This is where recurring revenue lives.
>    - `premium_yearly`: Annual subscription (typically 15-20% discount vs monthly to incentivize commitment).
>
> 2. **Unit economics analysis**: At what user scale do API costs become significant? How many free users can one paying user subsidize? Model scenarios at 1K, 10K, 50K, and 100K daily active users. Factor in D1 cache hit rates (estimate: 40-60% for popular languages, 10-20% for rare language pairs).
>
> 3. **Free tier strategy**: Is 10 pages/day AI translation too generous or too restrictive for conversion? Currently free users also get unlimited offline ML Kit translation (lower quality, but free forever). Should I gate offline translation behind a tier? Should I offer a free trial of Premium features?
>
> 4. **Pricing psychology & positioning**: How should I frame this against competitors? BookTranslator charges $3-5 per book — we charge once for unlimited books. Beelinguapp is $30/year but doesn't let users read their own books. How do I communicate this value proposition?
>
> 5. **Regional pricing**: Google Play supports per-country pricing. What should pricing look like in emerging markets (India, Brazil, Southeast Asia, Eastern Europe) vs developed markets (US, Western Europe, Japan)?
>
> 6. **Launch strategy**: Should I offer introductory/early-adopter pricing? A lifetime deal? A 7-day free trial of Premium? What creates urgency without devaluing the product?
>
> 7. **Alternative revenue models worth considering**: Educational/institutional licensing? Translation credits instead of subscriptions? A "pay what you want" book translation model? Partnerships with language schools?
>
> 8. **Risk assessment**: What are the biggest risks with the current model? API cost spikes? Free tier abuse? Google Play policy changes? How do I mitigate?
>
> Please provide specific price points in USD with rationale, sensitivity analysis on API costs, and a recommended 12-month pricing roadmap (launch → growth → maturity).

---

*End of document.*
