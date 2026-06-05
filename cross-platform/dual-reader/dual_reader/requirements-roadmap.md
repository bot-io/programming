# Dual Reader - Requirements Roadmap

## Phase 1: MVP (COMPLETE)
Core reading functionality for a bilingual EPUB/MOBI reader.

- [x] EPUB/MOBI file import and parsing
- [x] Dual-panel layout (original + translation)
- [x] Settings (theme, font, language, etc.)
- [x] Library with search and pagination status
- [x] Auto-pagination on import
- [x] 5 color theme presets (Standard, Sepia, Ocean, Forest, Midnight)
- [x] 57 languages with emoji flags
- [x] Drag-and-drop file import (web)
- [x] Custom PWA manifest
- [x] Client-side translation (Transformers.js web, ML Kit mobile)

## Phase 2: Production Polish (COMPLETE)
Features for production readiness.

- [x] DI refactoring (ChunkTranslationService uses TranslationService interface)
- [x] Bookmarks (entity, repository, use cases, Hive typeId 3)
- [x] Reading history (entity, repository, screen with date grouping, Hive typeId 4)
- [x] About page (version, credits, license, GitHub)
- [x] Settings export/import via clipboard (JSON serialization)
- [x] DualReaderScreen DI fix - 9/12 widget tests now pass

## Phase 3: Next Steps
Features for growth and polish.

- [ ] Bookmark UI in reader screen (add/remove/navigate bookmarks while reading)
- [ ] Reading history recording (hook into DualReaderScreen page navigation)
- [ ] DualReaderScreen full DI refactor (remove direct epubx access)
- [ ] URL launcher for GitHub link on About page
- [ ] Onboarding / first-run experience
- [ ] Analytics / usage tracking
- [ ] Offline mode improvements
- [ ] Accessibility audit (screen readers, high contrast)

## Known Technical Debt
- SettingsEntity.fontlFamily typo (Hive field, needs migration)
- DualReaderScreen still imports epubx directly (EpubReader.readBook)
- flutter pub get fails on MSYS/Git Bash (temp dir issue)
- 42 skipped tests (3 DualReaderScreen timing, remainder need device/emulator/real data)
