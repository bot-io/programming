# Test Data Directory

This directory contains test fixtures for E2E testing.

## Structure

```
test_data/
├── books/          # Test ebook files
├── fixtures/       # Test data fixtures
└── generated/      # Auto-generated test data
```

## Test Books

### Small Test EPUB
A minimal EPUB file for quick testing. Contains:
- Single chapter
- < 5KB in size
- Basic formatting

### Test Book EPUB
A standard EPUB for comprehensive testing. Contains:
- Multiple chapters
- Images
- Various text formatting
- ~50KB in size

## Fixtures

### Translation Fixtures
Pre-defined text samples for translation testing:
- Simple phrases
- Paragraphs
- Multi-line text
- Special characters
- Right-to-left text (when applicable)

### Settings Fixtures
Pre-configured settings states for testing:
- Default settings
- Custom font sizes
- Various theme modes
- Different target languages

## Generating Test Data

To generate new test data:

```bash
# Create a small test EPUB
dart test_integration/helpers/generate_test_epub.dart

# Create test fixtures
dart test_integration/helpers/generate_fixtures.dart
```

## Notes

- All test data should be small enough for quick CI/CD runs
- Use public domain or CC-licensed content
- Keep test books under 100KB when possible
- Test data should be platform-independent
