# Dual Reader Android — Lessons Learned from Flutter Version

## What Went Wrong with Flutter

1. **epubx package API kept breaking** — Dart EPUB ecosystem is tiny and fragile. One package, one maintainer. Breaking changes between minor versions required significant rework.

2. **MOBI support was impossible** — No viable Dart MOBI parser exists. `dart_mobi` is a personal project with API incompatibilities. Had to abandon the feature entirely.

3. **ML Kit translation quality was terrible for books** — On-device models are designed for short phrases, not literary text. Sentence-by-sentence translation loses all context and produces robotic output.

4. **Text sanitizer regex bug** — `r' *'` (zero-or-more spaces) matched between every character, inserting spaces into all book text. Took a while to diagnose because test fixtures were tiny.

5. **Dart 3.x breaking changes** — Null safety enforcement, const restrictions, and API signature changes across the ecosystem caused compilation failures across many files.

6. **Slow build/iterate cycle** — Flutter's build times on Windows were slow. Hot reload helped but full builds were painful.

## What We're Doing Differently

### Architecture
- **Kotlin + Jetpack Compose** — First-class Android support, unlimited library ecosystem
- **Clean Architecture** — Same layered approach (domain/data/ui) but with Kotlin best practices
- **Room for structured data, DataStore for settings** — Lesson: don't use a database for key-value preferences
- **Hilt DI** — Standard Android DI, better than manual or Koin for larger apps
- **Kotlin coroutines + Flow** — Reactive data, structured concurrency

### Translation (Critical Improvement)
- **LLM-first approach** — GLM-4.7-Flash is FREE and produces dramatically better literary translation
- **Paragraph-level context** — LLMs see surrounding text, maintain narrative flow
- **Tiered fallback** — Free LLM → Cheap LLM → Best LLM → On-device (offline only)
- **Batch translation** — Multiple paragraphs in one API call for efficiency
- **Translation caching** — Every translation cached locally, works offline after first read

### EPUB Parsing
- **epub4j-kotlin** — Mature JVM library, stable API, no breakage risk
- **Jsoup for HTML** — Industry standard, handles malformed HTML gracefully
- **Lazy chapter loading** — Don't load all chapters at import time, load on demand

### Testing
- **Test with real EPUBs from day 1** — Not just tiny fixtures
- **Robolectric for unit tests** — Run Android tests without emulator
- **MockK** — Better Kotlin mocking than Mockito
- **Turbine for Flow testing** — Clean async test assertions

### File Structure
- New sibling directory (dual-reader-android), not inside the Flutter project
- Clean package structure: domain/entities, domain/services, domain/usecases, data/, ui/

## Translation Strategy Detail

### Cost Analysis (per book, ~120K words)
| Provider | Quality | Cost | Speed |
|----------|---------|------|-------|
| GLM-4.7-Flash | Excellent | $0.00 | ~30s |
| GLM-4.7-FlashX | Excellent | $0.07 | ~20s |
| GLM-4.5 | Best | $0.30 | ~60s |
| ML Kit On-device | Poor | $0.00 | ~10s |

### Why LLMs are Better for Books
- Understand context across sentences
- Maintain character name consistency
- Preserve literary style and tone
- Handle idioms and metaphors correctly
- Can be given translation instructions ("translate this 19th century English novel to Bulgarian, maintaining the formal register")
