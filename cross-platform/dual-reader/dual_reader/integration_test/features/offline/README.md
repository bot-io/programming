# Offline Functionality E2E Tests

This directory contains comprehensive E2E tests for offline functionality of the Dual Reader app.

## Test Files

### Offline Reading (`offline_reading_test.dart`)
Tests for reading books without internet connection:
- Import book while online, read offline
- Navigate pages while offline
- Jump to specific page while offline
- Table of contents works while offline
- Bookmarks work while offline
- Reading progress saves while offline
- Font changes apply while offline
- Search works while offline
- Multiple books accessible while offline
- Edge cases (app launch offline, offline indicator, library display)
- Platform-specific tests (Android, iOS, Web)

**Total test cases**: 12

### Offline Translation (`offline_translation_test.dart`)
Tests for translation functionality without internet:

#### Mobile - ML Kit Offline:
- Download language model while online
- Translate page while offline with ML Kit
- Translation works without internet
- Cache persists while offline
- Multiple languages work offline

#### Web - Transformers.js Offline:
- Load Transformers.js model while online
- Browser caches model for offline use
- Translate page while offline with Transformers.js

#### Shared Offline Translation:
- Language detection works offline
- Translation quality is consistent offline
- Translation history works offline
- Sentence splitting works offline

#### Error Handling:
- Handle translation without downloaded model
- Offer model download when offline fails

**Total test cases**: 14

### Offline Pagination (`offline_pagination_test.dart`)
Tests for pagination functionality without internet:
- Paginate new book while offline
- Pagination progress shows while offline
- Book becomes readable after offline pagination
- Repagination works while offline
- Multiple books can be paginated offline
- Pagination data persists across app restarts offline
- Large book pagination works offline
- Chapter breaks work in offline pagination
- Images are processed during offline pagination
- Table of contents generated offline
- Offline pagination completes within reasonable time
- Offline pagination does not block UI
- Platform-specific tests (Android, iOS, Web)

**Total test cases**: 15

### Network Transition (`network_transition_test.dart`)
Tests for app behavior during network state changes:
- Start online then go offline
- Start offline then go online
- Handle network loss gracefully while reading
- Resume functionality when reconnecting
- Ongoing operations handle network loss
- Network state indicator updates correctly
- Rapid network toggling handled gracefully

#### Data Sync:
- Reading progress syncs when reconnected
- Settings sync when reconnected
- Bookmarks sync when reconnected

#### Platform Specific:
- Android network transition handling
- iOS network transition handling
- Web network transition handling

#### Edge Cases:
- Handle network instability
- Slow network detection works
- Recovery from network error

**Total test cases**: 16

### PWA Offline (`pwa_offline_test.dart`)
Tests for Progressive Web App offline features (Web only):
- PWA can be installed
- Service worker registers successfully
- Service worker caches app assets
- App launches offline
- All features work offline
- Translation model cached for offline use
- Books stored in IndexedDB offline
- Progress saved to IndexedDB offline
- PWA manifest is valid
- PWA has offline-capable service worker

#### Cache Management:
- View cache size
- Clear cache and rebuild
- Cache rebuilds when online

#### PWA UI Features:
- Install prompt appears for eligible users
- PWA runs in standalone mode
- PWA icon displays correctly

**Total test cases**: 16

## Test Coverage Summary

| Feature | Test Files | Test Cases |
|---------|------------|------------|
| Offline Reading | 1 | 12 |
| Offline Translation | 1 | 14 |
| Offline Pagination | 1 | 15 |
| Network Transitions | 1 | 16 |
| PWA Offline | 1 | 16 |
| **Total** | **5** | **73** |

## Running the Tests

### Run all offline tests:
```bash
flutter test integration_test/features/offline/
```

### Run specific test file:
```bash
flutter test integration_test/features/offline/offline_reading_test.dart
```

### Run web-specific PWA tests:
```bash
flutter test integration_test/features/offline/pwa_offline_test.dart --platform chrome
```

### Run with verbose output:
```bash
flutter test integration_test/features/offline/ --verbose
```

## Test Structure

All tests follow the Arrange-Act-Assert pattern:
1. **Arrange**: Set up network state and app
2. **Act**: Perform action (offline)
3. **Assert**: Verify expected offline behavior

## Dependencies

- `flutter_test` - Core Flutter testing framework
- `integration_test` - Integration test support
- `flutter_riverpod` - State management
- Test helpers from `test_integration/`

## Network Simulation

Tests require network simulation capabilities:

### Mobile (Android/iOS):
- Airplane mode toggling
- Network state monitoring via Connectivity package

### Web:
- Browser offline simulation via Chrome DevTools
- Service worker testing
- IndexedDB verification

## Known Limitations

1. **Network Simulation**: Most tests are skipped because they require:
   - Platform-specific network simulation tools
   - Test environment with network control
   - Service worker inspection capabilities

2. **Test Data**: Tests assume availability of test books:
   - Small test book (< 100 pages)
   - Large test book (> 100 pages)
   - Multi-chapter book
   - Book with images

3. **Async Operations**: Long-running operations (model downloads, pagination) may need:
   - Extended timeout configurations
   - Background operation monitoring

4. **Browser APIs**: Some web tests require:
   - Service Worker API access
   - IndexedDB inspection
   - Cache Storage API access

## Test Data Requirements

Tests use the following test data:
- `test_book.epub` - Basic EPUB for offline reading
- `large_book.epub` - For pagination performance tests
- `multi_chapter_book.epub` - For chapter/TOC tests
- `book_with_images.epub` - For image processing tests

## Logging

Tests use `TestLogger` for comprehensive debug output:
- Network state changes
- Offline operation results
- Cache status
- Sync progress

## Future Enhancements

1. Add visual regression tests for offline UI
2. Add performance benchmarks for offline operations
3. Add tests for offline-first architecture patterns
4. Add tests for background sync when reconnecting
5. Add tests for conflict resolution when syncing
6. Add tests for offline data migration
7. Add tests for different browser PWA implementations

## Platform-Specific Notes

### Android
- Uses `connectivity_plus` for network detection
- ML Kit for offline translation
- Hive for local storage

### iOS
- Uses `connectivity_plus` for network detection
- ML Kit for offline translation
- Hive for local storage

### Web (PWA)
- Uses `window.navigator.onLine` for network detection
- Transformers.js for offline translation
- IndexedDB for local storage
- Service Worker for asset caching
- Cache Storage for offline assets

## CI/CD Considerations

For CI/CD pipelines:
1. Web tests can run with headless Chrome
2. Mobile tests may require emulators with network control
3. PWA tests require service worker support
4. Offline tests should run in isolated network environments
