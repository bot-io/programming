# Translation Quality Requirements

## Problem Statement

Translating page-by-page produces poor results because:
1. Pages split mid-sentence, so the LLM gets incomplete input
2. No narrative context from surrounding pages — pronouns, references, and tone get lost
3. Each page is an isolated API call — the LLM has no memory of previous translations

## Requirements

### TR-1: Sentence-boundary pagination
Pages must NOT split mid-sentence. The paginator must:
- Split at paragraph boundaries first (`\n\n`)
- When a paragraph is too tall for remaining space, split at sentence boundaries (`.`, `!`, `?`, `…` followed by space or end-of-string)
- Only split at line boundaries as last resort for extremely long sentences

### TR-2: Context-aware translation
When translating a page, the LLM must receive surrounding context:
- **Previous page's text** (original) — so pronouns and references resolve correctly
- **Previous page's translation** (if available) — so style/tone carries over
- The prompt must clearly separate "context for reference only" from "text to translate"

### TR-3: Batch translation with continuity
When translating multiple pages (e.g., whole book or chapter):
- Group pages into batches of 3–5 pages per API call
- Each batch includes: [last translated paragraph from previous batch] as context
- The LLM translates the batch as a coherent unit
- Results are split back into individual pages
- Batches are processed sequentially with 1s delay between them (rate limiting)

### TR-4: Translation prompt engineering
The LLM system prompt must:
- Specify the literary translation task clearly
- Indicate source and target languages
- Tell the LLM to maintain consistent tone, character names, and terminology
- For context-mode: clearly mark what is context vs what needs translation
- Output format: plain translated text, no explanations, no markdown

### TR-5: Paragraph-level alignment
When possible, preserve paragraph structure in translations:
- Each paragraph in the original should correspond to a paragraph in the translation
- This enables side-by-side or top-bottom display alignment
- For batch mode, use `[P1]`, `[P2]` etc. markers to align paragraphs

## Architecture

```
User taps "Translate" on page N
  → ViewModel.translateCurrentPage()
    → ContextAwareTranslateUseCase
      → Gets page N text + page N-1 text + page N-1 translation
      → Sends to FallbackTranslationService with context
        → CloudTranslationService (GLM-4.7-Flash)
          → Prompt: "Context: {prev} \n\n Translate: {current}"
        → OR ML Kit fallback (no context, best-effort)

User taps "Translate All"
  → ViewModel.translateAllPages()
    → ContextAwareTranslateUseCase
      → Groups pages into batches of 3-5
      → For each batch:
        → Gets previous batch's last paragraph as context
        → Sends batch with context to FallbackTranslationService
        → Splits response back into per-page translations
        → 1s delay before next batch
      → Updates all pages with translations
```

## Fallback Tiers

| Tier | Provider | Cost | Quality | Context Support |
|------|----------|------|---------|-----------------|
| 1 | GLM-4.7-Flash (cloud) | Free | Best | ✓ Full context |
| 2 | ML Kit (on-device) | Free | Basic | ✗ No context |

Future tiers (not yet wired):
| 3 | GLM-4.7-FlashX | ~$0.07/book | Better | ✓ Full context |
| 4 | GLM-4.5 | ~$0.30/book | Best | ✓ Full context |
