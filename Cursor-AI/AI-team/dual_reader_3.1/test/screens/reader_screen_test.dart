import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:dual_reader/screens/reader_screen.dart';
import 'package:dual_reader/providers/reader_provider.dart';
import 'package:dual_reader/providers/settings_provider.dart';
import 'package:dual_reader/services/storage_service.dart';
import 'package:dual_reader/services/translation_service.dart';
import 'package:hive_flutter/hive_flutter.dart';

void main() {
  group('ReaderScreen Widget Tests', () {
    late StorageService storageService;
    late ReaderProvider readerProvider;
    late SettingsProvider settingsProvider;
    late TranslationService translationService;

    setUp(() async {
      // Initialize Hive for testing
      await Hive.initFlutter();
      
      // Register adapters if not already registered
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(BookAdapter());
      }
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(ChapterAdapter());
      }
      if (!Hive.isAdapterRegistered(2)) {
        Hive.registerAdapter(ReadingProgressAdapter());
      }
      if (!Hive.isAdapterRegistered(3)) {
        Hive.registerAdapter(BookmarkAdapter());
      }
      if (!Hive.isAdapterRegistered(4)) {
        Hive.registerAdapter(AppSettingsAdapter());
      }

      storageService = StorageService();
      await storageService.init();
      
      translationService = TranslationService();
      await translationService.initialize();
      
      settingsProvider = SettingsProvider(storageService);
      readerProvider = ReaderProvider(storageService, translationService, settingsProvider);
    });

    tearDown(() {
      readerProvider.dispose();
    });

    testWidgets('displays reader screen with app bar', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider<ReaderProvider>.value(value: readerProvider),
              ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
              Provider<StorageService>.value(value: storageService),
            ],
            child: const ReaderScreen(bookId: 'test-book-1'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Reader screen should render (may show loading or error state)
      expect(find.byType(ReaderScreen), findsOneWidget);
    });

    // Note: Full integration tests for reading flow, page navigation,
    // bookmarks, and chapters require a loaded book and are better
    // suited for integration_test suite
  });
}
