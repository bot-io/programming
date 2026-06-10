# Dual Reader — Project Charter

## Summary
Android bilingual ebook reader that displays two languages side-by-side, with integrated machine translation for seamless foreign-language reading.

## Repository
`dual-reader-android/`

## Tech Stack
- **Language:** Kotlin
- **UI:** Jetpack Compose
- **Build:** AGP 9.2.1, compileSdk 37, Compose BOM 2026.05.01
- **Testing:** 138 unit tests currently passing

## Current Features
- SAF-based EPUB import
- Split-screen bilingual reader
- Full-text search within books
- Bookmarks
- Book cover extraction and display
- 6 reader themes
- Text selection support
- Multi-provider translation: Gemini 2.5 Flash (primary) + GLM-4.7-Flash (fallback) via Cloudflare Worker

## Goals
- Deliver a polished bilingual reading experience on Android
- Context-aware, high-quality machine translation
- Rich library management and reading progress tracking
- Export capabilities for annotations and highlights

## Constraints
- Android-only (no iOS/web plans currently)
- Translation must be resilient across providers (fallback chain)
- All code changes require automated tests; full suite green before merge
