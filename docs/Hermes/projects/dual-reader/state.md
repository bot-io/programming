# Dual Reader — Current State

**Last Updated:** 2026-06-10

## Status: Active Development

## Summary
Dual Reader is a functional Android bilingual ebook reader with core reading features complete. 138 unit tests passing. The project is entering a phase focused on translation quality and test coverage.

## What's Working
- EPUB import via SAF
- Split-screen bilingual reader
- Full-text search
- Bookmarks and text selection
- Book cover extraction and display
- 6 reader themes
- Multi-provider translation (Gemini 2.5 Flash primary, GLM-4.7-Flash fallback via Cloudflare Worker)

## Current Focus
- **DR-001:** Context-aware batch translation (P0)
- **DR-002:** Translation test coverage (P0)

## Next Up
- **DR-003:** Night mode improvements (P1)
- **DR-004:** Library management — awaiting user decision on scope (P1)

## Known Issues
- Translation lacks sentence-boundary awareness and cross-page context
- Translation test coverage is insufficient
- Night mode could benefit from OLED-optimized true black and better contrast
