# Book Parsing and Formats E2E Tests

This directory contains comprehensive E2E tests for book parsing and format handling in the Dual Reader app.

## Test Files

### EPUB Parsing (`epub_parsing_test.dart`)
Tests for EPUB file parsing functionality:
- Parse standard EPUB2 file
- Parse standard EPUB3 file
- Extract metadata (title, author, cover)
- Extract all chapters
- Extract chapter content
- Extract images
- Handle EPUB with TOC
- Handle EPUB without TOC
- Handle EPUB with complex formatting
- Handle encrypted EPUB (DRM) - should show error
- EPUB structure variants (embedded fonts, external resources, spine order)
- Metadata edge cases (missing title, missing author, special characters)

**Total test cases**: 16

### MOBI Parsing (`mobi_parsing_test.dart`)
Tests for MOBI file parsing functionality:
- Parse standard MOBI file
- Extract metadata (title, author, cover)
- Extract all chapters
- Extract chapter content
- Handle MOBI with images
- Handle KF8 format
- Handle AZW format
- Handle MOBI without ISBN
- Handle MOBI with complex markup
- MOBI structure (EXTH header, KF8 fallback, inline TOC)
- Image handling (cover extraction, low-res images)
- Platform-specific tests (mobile, web)

**Total test cases**: 16

### Content Processing (`content_processing_test.dart`)
Tests for HTML to text conversion and content handling:
- HTML to plain text conversion
- Preserve formatting markers
- Handle special characters
- Handle unicode characters
- Handle RTL languages (Arabic, Hebrew)
- Handle CJK languages (Chinese, Japanese, Korean)
- Handle code blocks
- Handle tables
- Text processing (HTML tag stripping, paragraph breaks, nested formatting, HTML entities)
- Language-specific tests (Arabic, Chinese, Japanese, Korean)
- Formatting preservation (bold, italic, lists)

**Total test cases**: 20

### Edge Cases (`edge_cases_test.dart`)
Tests for handling unusual and edge case book files:
- Empty book
- Book with one page
- Book with very long chapters
- Book with many short chapters
- Book with no chapters
- Corrupted file
- Invalid file format
- Large books (1000+ pages, 100+ chapters)
- Memory efficient parsing
- No crashes on large files
- Chapter title handling (strip h1-h6, strip titles, prevent duplication)
- Malformed content (malformed HTML, unclosed tags, deeply nested tags)
- File system edge cases (long filenames, special characters, unicode)

**Total test cases**: 19

## Test Coverage Summary

| Feature | Test Files | Test Cases |
|---------|------------|------------|
| EPUB Parsing | 1 | 16 |
| MOBI Parsing | 1 | 16 |
| Content Processing | 1 | 20 |
| Edge Cases | 1 | 19 |
| **Total** | **4** | **71** |

## Running the Tests

### Run all parsing tests:
```bash
flutter test integration_test/features/parsing/
```

### Run specific test file:
```bash
flutter test integration_test/features/parsing/epub_parsing_test.dart
```

### Run with verbose output:
```bash
flutter test integration_test/features/parsing/ --verbose
```

## Test Structure

All tests follow the Arrange-Act-Assert pattern:
1. **Arrange**: Load test book file and set up environment
2. **Act**: Parse the book and extract content
3. **Assert**: Verify expected parsing results

## Test Book Fixtures

The `TestBooks` class in `test_integration/helpers/test_books.dart` provides:

### Predefined Test Books:
- `epub2Basic` - Standard EPUB2 for baseline testing
- `epub3Basic` - Standard EPUB3 for baseline testing
- `epub2WithImages` - EPUB2 with embedded images
- `epub3WithComplexFormatting` - EPUB3 with advanced CSS
- `mobiBasic` - Standard MOBI for testing
- `mobiWithImages` - MOBI with images
- `kf8Basic` - KF8 format testing
- `emptyBook` - Edge case: empty content
- `onePageBook` - Edge case: single page
- `longChaptersBook` - Edge case: very long chapters
- `manyChaptersBook` - Edge case: 100+ chapters
- `largeBook` - Large book: 1000+ pages
- `rtlBook` - Arabic for RTL testing
- `chineseBook` - Chinese for CJK testing
- `japaneseBook` - Japanese for CJK testing
- `koreanBook` - Korean for CJK testing
- `unicodeBook` - Unicode in metadata
- `codeBlocksBook` - Code blocks and monospace
- `tablesBook` - HTML tables
- `malformedHtmlBook` - Malformed HTML content

### Test Book Categories:
- `TestBooks.all` - All available test books
- `TestBooks.epub` - Only EPUB format books
- `TestBooks.mobi` - Only MOBI format books
- `TestBooks.edgeCases` - Edge case books
- `TestBooks.large` - Large books for stress testing
- `TestBooks.languageSpecific` - Language-specific books

## Dependencies

- `flutter_test` - Core Flutter testing framework
- `integration_test` - Integration test support
- `flutter_riverpod` - State management
- `path` - File path operations
- Test helpers from `test_integration/`

## Test Book File Locations

Test books should be placed in:
```
dual_reader/test_assets/books/
├── epub2_basic.epub
├── epub3_basic.epub
├── mobi_basic.mobi
├── arabic_book.epub
├── chinese_book.epub
└── ... (other test books)
```

Or configured via pubspec.yaml:
```yaml
flutter:
  assets:
    - test_assets/books/
```

## Known Limitations

1. **Test Book Files**: Most tests are skipped because they require:
   - Actual EPUB/MOBI test files in the test assets directory
   - Books with specific characteristics (RTL, CJK, large, etc.)
   - Platform-specific format support

2. **Large Book Testing**: Tests for 1000+ page books:
   - Require large test files (10MB+)
   - May need extended timeouts
   - Should run separately for performance

3. **Memory Testing**: Memory efficiency tests require:
   - Platform-specific memory monitoring
   - Controlled test environment
   - May not work in all test runners

4. **Corrupted Files**: Tests for corrupted/malformed files:
   - Need carefully crafted test files
   - Should not crash the test runner
   - May need exception handling verification

## Test Data Requirements

### Essential Test Books:
1. **EPUB2**: Standard, with images, with TOC, without TOC
2. **EPUB3**: Standard, with complex formatting
3. **MOBI**: Standard, with images, KF8 format
4. **Edge Cases**: Empty, one page, long chapters, many chapters
5. **Languages**: Arabic/Hebrew (RTL), Chinese, Japanese, Korean
6. **Content**: Code blocks, tables, special characters, unicode

### Optional Test Books:
1. **Large Books**: 1000+ pages for stress testing
2. **Corrupted**: Various corruption patterns
3. **Malformed**: HTML errors, unclosed tags, deep nesting
4. **DRM**: For error handling verification

## Logging

Tests use `TestLogger` for comprehensive debug output:
- Parsing results
- Content extraction status
- Error messages
- Performance metrics

## Platform-Specific Notes

### Android
- Full EPUB support via epub package
- Full MOBI support via mobi package
- RTL and CJK text support

### iOS
- Full EPUB support via epub package
- Full MOBI support via mobi package
- RTL and CJK text support

### Web
- Full EPUB support via epub package
- Limited MOBI support (browser-based parsing)
- Service Worker for caching large files
- IndexedDB for storage

## Performance Benchmarks

Expected parsing performance:
- Small EPUB (< 1MB): < 1 second
- Medium EPUB (1-10MB): < 5 seconds
- Large EPUB (10-50MB): < 30 seconds
- Small MOBI (< 1MB): < 2 seconds
- Large MOBI (1-10MB): < 20 seconds

## CI/CD Considerations

For CI/CD pipelines:
1. Store test books as artifacts or in external storage
2. Download test books before running tests
3. Cache test books between runs
4. Run large book tests separately
5. Monitor memory usage during parsing tests
6. Track parsing performance over time

## Future Enhancements

1. Add tests for FB2 format
2. Add tests for PDF format
3. Add visual regression tests for rendered content
4. Add performance profiling for large books
5. Add tests for custom EPUB extensions
6. Add tests for accessibility metadata
7. Add tests for embedded fonts and stylesheets
8. Add tests for audio/video content
9. Add tests for interactive content
10. Add tests for MathML and SVG content
