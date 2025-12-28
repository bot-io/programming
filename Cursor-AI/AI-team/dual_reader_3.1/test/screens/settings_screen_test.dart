import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:dual_reader/screens/settings_screen.dart';
import 'package:dual_reader/providers/settings_provider.dart';
import 'package:dual_reader/services/storage_service.dart';
import 'package:hive_flutter/hive_flutter.dart';

void main() {
  group('SettingsScreen Widget Tests', () {
    late StorageService storageService;
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
      
      settingsProvider = SettingsProvider(storageService);
    });

    testWidgets('displays settings screen with app bar', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<SettingsProvider>.value(
            value: settingsProvider,
            child: const SettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('displays appearance section', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<SettingsProvider>.value(
            value: settingsProvider,
            child: const SettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Appearance'), findsOneWidget);
    });

    testWidgets('displays font section', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<SettingsProvider>.value(
            value: settingsProvider,
            child: const SettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Font'), findsOneWidget);
    });

    testWidgets('displays layout section', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<SettingsProvider>.value(
            value: settingsProvider,
            child: const SettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Layout'), findsOneWidget);
    });

    testWidgets('displays translation section', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<SettingsProvider>.value(
            value: settingsProvider,
            child: const SettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Translation'), findsOneWidget);
    });

    // Note: Full integration tests for settings changes and persistence
    // require testing the SettingsProvider and are covered in provider tests
  });
}
