# Dual Reader - Requirements Roadmap

## MVP (Phase 1) - Current Focus
Target: Production-ready bilingual EPUB reader

### Core Reading ✅
- [x] Import EPUB/MOBI books via file picker
- [x] Auto-paginate books on import
- [x] Dual-panel reading (original + translated)
- [x] Touch navigation zones (20/60/20 split)
- [x] Chapter drawer / table of contents
- [x] Text selection on panels
- [x] Full screen immersive mode
- [x] Pagination progress on book cards
- [x] Reading progress tracking

### Settings ✅
- [x] Theme mode (Light / Dark / System)
- [x] 5 color theme presets (Standard, Sepia, Ocean, Forest, Midnight)
- [x] Font family and size
- [x] Line height and margins
- [x] Text alignment
- [x] Panel width ratio
- [x] Settings persist across sessions (Hive)

### Translation ✅
- [x] Client-side translation (Transformers.js on web, ML Kit on mobile)
- [x] 57 languages with emoji flags
- [x] Translation caching
- [x] Multiple translation APIs (LibreTranslate, Google, MyMemory)
- [x] Common phrase preloading
- [x] Language model download management

### Library ✅
- [x] Book grid with covers
- [x] Search/filter books
- [x] Delete books (long press)
- [x] Drag-and-drop import (web)

### Platform ✅
- [x] Web (PWA with custom manifest)
- [x] Android
- [x] Cross-platform architecture (Domain/Data/Presentation)

### Testing ✅
- [x] 1107 tests, 0 failures
- [x] Integration tests covering main flows
- [x] Domain, Data, Presentation layer tests

## Phase 2 - Next
- [ ] Bookmarks for quick access
- [ ] Reading history (recently opened)
- [ ] About page (version, credits, license)
- [ ] Export/import settings
- [ ] DualReaderScreen DI refactoring (unblock widget tests)
- [ ] Custom app icon
- [ ] CI/CD pipeline (GitHub Actions)

## Phase 3 - Future
- [ ] PDF support
- [ ] Cloud sync
- [ ] Reading statistics
- [ ] Vocabulary builder
- [ ] Spaced repetition for new words
- [ ] Audio book support
