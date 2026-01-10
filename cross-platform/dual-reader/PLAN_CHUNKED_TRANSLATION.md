# Chunk-Based Translation Implementation Plan

## Objective
Improve translation quality by sending larger text chunks to the translation model while maintaining strict display parity between original and translated pages.

## Key Requirements
1. **Send larger chunks** (3000-5000 characters) to translation model for better context
2. **Display parity**: Each page of original text must show corresponding translation
3. **Non-blocking UI**: Show current page immediately, translate in background
4. **Natural boundaries**: Respect chapter/paragraph boundaries when possible
5. **Structure preservation**: Maintain paragraph breaks in translated output

## Architecture: Two-Layer Translation

### Core Concept
Separate **translation units** (chunks) from **display units** (pages):
- **Translation Layer**: Translate multi-page chunks (3-5 pages)
- **Display Layer**: Extract page-specific translations from chunks
- **Mapping Layer**: Maintain metadata to map pages to chunks

### Data Model

```dart
class TranslationChunk {
  final String chunkId;           // {bookId}_chunk_{startPage}_{endPage}_{lang}
  final String bookId;
  final int startPageIndex;        // First page in chunk
  final int endPageIndex;          // Last page in chunk (inclusive)
  final String originalText;       // Combined text from all pages
  String? translatedText;          // Cached translation
  final List<int> pageBreakOffsets; // Character offsets where pages break
  final String targetLanguage;
  DateTime? translatedAt;
}
```

## Implementation Steps

### Step 1: Create Domain Entity

**File**: `dual_reader/lib/src/domain/entities/translation_chunk.dart`

Create the `TranslationChunk` entity class.

### Step 2: Create Chunk Cache Service

**File**: `dual_reader/lib/src/data/services/chunk_cache_service.dart`

Cache chunk translations with keys: `{bookId}_chunk_{startPage}_{endPage}_{language}`
Store page-to-chunk mappings for efficient lookup.

### Step 3: Create Chunk Translation Service

**File**: `dual_reader/lib/src/data/services/chunk_translation_service.dart`

Key method:
```dart
Future<String> getPageTranslation({
  required String bookId,
  required int pageIndex,
  required String originalPageText,
  required String targetLanguage,
  required List<String> allPages,
}) async {
  // 1. Find or create chunk for this page
  // 2. Ensure chunk is translated
  // 3. Extract page translation from chunk
}
```

**Chunk creation**:
- Target: 3000-5000 characters (3-5 pages)
- Hard limit: 8000 characters
- Respect chapter boundaries first, paragraph boundaries second

**Segment extraction** (display parity):
- Primary: Paragraph-based (count paragraphs in original, extract same count from translation)
- Fallback: Proportional character-based (use offsets as percentages)

### Step 4: Modify Dual Reader Screen

**File**: `dual_reader/lib/src/presentation/screens/dual_reader_screen.dart`

Replace `_translatePageByParagraphs()` with chunk-based approach. Update cache clearing on language change.

### Step 5: Update DI Container

**File**: `dual_reader/lib/src/core/di/injection_container.dart`

Register `ChunkCacheService` and `ChunkTranslationService`.

## Display Parity Strategy

### Primary: Paragraph-Based Extraction
1. Count paragraphs in original page segment
2. Find paragraph position within full chunk
3. Extract same number of paragraphs from translation
4. Rejoin with `\n\n`

### Fallback: Proportional Character-Based
1. Calculate start/end offsets as percentage of chunk
2. Apply same percentages to translated text
3. Extract segment

## Pre-Translation Strategy

Background translation of nearby chunks (non-blocking):
- When user opens page N, translate its chunk
- Pre-translate next chunk (pages N+3 to N+7)
- Pre-translate previous chunk (pages N-3 to N+1)

## Critical Files

1. `dual_reader/lib/src/domain/entities/translation_chunk.dart` - NEW
2. `dual_reader/lib/src/data/services/chunk_cache_service.dart` - NEW
3. `dual_reader/lib/src/data/services/chunk_translation_service.dart` - NEW
4. `dual_reader/lib/src/presentation/screens/dual_reader_screen.dart` - MODIFY
5. `dual_reader/lib/src/core/di/injection_container.dart` - MODIFY

## Success Criteria

1. Translation chunks are 3000-5000 characters
2. Chunk boundaries respect chapter/paragraph boundaries
3. Each page shows correct corresponding translation
4. UI remains responsive (no blocking)
5. Translation quality improved (more context)
