import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:dual_reader/widgets/chapters_dialog.dart';
import 'package:dual_reader/providers/reader_provider.dart';
import 'package:dual_reader/services/storage_service.dart';
import 'package:dual_reader/services/translation_service.dart';
import 'package:dual_reader/providers/settings_provider.dart';
import 'package:dual_reader/models/book.dart';
import 'package:dual_reader/models/chapter.dart';
import '../helpers/test_helpers.dart';
import 'package:hive_flutter/hive_flutter.dart';

void main() {
  group('ChaptersDialog Widget Tests', () {
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

    testWidgets('displays empty state when no chapters exist', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<ReaderProvider>.value(
              value: readerProvider,
              child: const ChaptersDialog(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('No chapters available'), findsOneWidget);
      expect(find.byIcon(Icons.menu_book_outlined), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
    });

    // Note: Testing with chapters requires loading a book through loadBook(),
    // which needs a BuildContext and book in storage. This is better suited
    // for integration tests. Here we test the empty state and basic structure.

    testWidgets('displays close button and closes dialog when tapped', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => ChangeNotifierProvider<ReaderProvider>.value(
                      value: readerProvider,
                      child: const ChaptersDialog(),
                    ),
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Chapters'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.text('Chapters'), findsNothing);
    });

    // Note: Full chapter navigation tests require a loaded book with chapters.
    // These are better suited for integration tests that set up the full
    // book loading flow through loadBook().
  });
}
