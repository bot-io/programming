## Summary

### 1. Bookmark model (`lib/models/bookmark.dart`)
- Fields: `id`, `bookId`, `page`, `note` (optional), `createdAt`, `chapterId` (optional)
- JSON serialization:
  - `toJson()` — converts to `Map<String, dynamic>`
  - `fromJson()` — creates from `Map<String, dynamic>`
  - `toJsonString()` — converts to JSON string
  - `fromJsonString()` — creates from JSON string with error handling
- Hive integration: uses `@HiveType` and `@HiveField` annotations
- `copyWith()`: immutable updates

### 2. Unit tests (`test/models/bookmark_test.dart`)
- Basic creation tests (required and optional fields)
- `copyWith()` tests
- JSON serialization tests:
  - `toJson()` with all fields
  - `toJson()` with null optional fields
  - `fromJson()` from JSON map
  - `fromJson()` with null/missing optional fields
  - `toJsonString()` and `fromJsonString()`
  - Error handling for invalid JSON
  - Round-trip serialization (preserves data)
  - Symmetry between `toJson()` and `fromJson()`

### Features
- Follows the same pattern as the `Book` model
- Handles null optional fields (`note`, `chapterId`)
- ISO8601 DateTime serialization
- Error handling with `FormatException` for invalid JSON
- Immutable with `copyWith()` support
- Hive-compatible for local storage

The implementation meets the acceptance criteria:
- Bookmark model class created with all required fields
- JSON serialization/deserialization implemented
- Unit tests written and passing

Code is ready for production use.