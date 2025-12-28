import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:dual_reader/screens/library_screen.dart';
import 'package:dual_reader/providers/book_provider.dart';
import 'package:dual_reader/providers/settings_provider.dart';
import 'package:dual_reader/services/storage_service.dart';
import 'package:hive_flutter/hive_flutter.dart';

void main() {
  group('LibraryScreen Widget Tests', () {
    late StorageService storageService;
    late BookProvider bookProvider;
    late SettingsProvider settingsProvider;

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
      
      bookProvider = BookProvider(storageService);
      settingsProvider = SettingsProvider(storageService);
    });

    tearDown(() {
      bookProvider.dispose();
    });

    testWidgets('displays library screen with app bar', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider<BookProvider>.value(value: bookProvider),
              ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
              Provider<StorageService>.value(value: storageService),
            ],
            child: const LibraryScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check for app bar title
      expect(find.text('Library'), findsOneWidget);
    });

    testWidgets('displays empty state when no books exist', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider<BookProvider>.value(value: bookProvider),
              ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
              Provider<StorageService>.value(value: storageService),
            ],
            child: const LibraryScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should show empty state or import button
      expect(find.text('Import Book'), findsOneWidget);
    });

    testWidgets('displays search bar', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider<BookProvider>.value(value: bookProvider),
              ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
              Provider<StorageService>.value(value: storageService),
            ],
            child: const LibraryScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check for search field
      expect(find.byType(TextField), findsWidgets);
    });

    // Note: Full integration tests for book import, search, and navigation
    // require file system access and are better suited for integration_test suite
  });
}
