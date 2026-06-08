---
aliases: [Dual Reader, dual-reader]
tags: [project, android, active]
stack: "Kotlin, Jetpack Compose, AGP 9.2.1"
status: active
location: "dual-reader-android/"
---

# 🏗 Dual Reader

Android bilingual ebook reader with multi-provider translation.

## Stack

- **AGP:** 9.2.1 | **Kotlin:** 2.3.21 | **JDK:** 21
- **compileSdk:** 37 | **Compose BOM:** 2026.05.01
- 138 unit tests passing | Release APK ~20MB

## Features

- SAF import for epubs
- Split reader (dual-pane)
- Text search, bookmarks, cover display
- 6 built-in themes
- Copyable error messages
- Text selection (SelectionContainer)
- Multi-provider translation: [[Translation Quality|Gemini + GLM]]

## Key Decisions

- [[Translation Quality]] — Context-aware batch translation architecture
- [[Cloudflare Worker]] — Multi-provider translation API at `dual-reader-translate.dualreader.workers.dev`

## Gotchas

- ⚠️ NEVER add `.clickable` to content area
- WindowInsets: `systemBars` on outermost Box only
- epub4j needs xmlpull + kxml2 excluded
