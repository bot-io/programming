## Summary

Implemented the Chapter data model with the required fields.

### 1. **Chapter Model Updates** (`lib/models/chapter.dart`)
   - Added `bookId` (String, required) — references the book
   - Added `startPage` (int, required) — starting page number
   - Added `endPage` (int, required) — ending page number
   - Updated JSON serialization/deserialization to include the new fields
   - Updated `copyWith` to support the new fields
   - Maintained backward compatibility with existing `startIndex` and `endIndex` fields

### 2. **Parser Updates**
   - Updated `lib/services/ebook_parser.dart` to include `bookId`, `startPage`, and `endPage` when creating chapters
   - Updated `lib/services/mobi_parser.dart` to include the new fields
   - Set `startPage` and `endPage` to 0 initially (to be calculated during pagination)

### 3. **Unit Tests** (`test/models/chapter_test.dart`)
   - Updated all existing tests to include the new required fields
   - Added tests for:
     - Page range validation
     - Book ID references
     - JSON serialization with new fields
     - Round-trip JSON serialization

### 4. **Verification**
   - All tests pass
   - No linter errors
   - Code compiles successfully
   - All Chapter instantiations updated

The Chapter model now includes:
- `id` (String)
- `title` (String)
- `startPage` (int) — new
- `endPage` (int) — new
- `bookId` (String) — new
- `startIndex` (int) — kept for backward compatibility
- `endIndex` (int) — kept for backward compatibility
- `href` (String?, optional)

All acceptance criteria are met.