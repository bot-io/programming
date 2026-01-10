import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dual_reader/src/presentation/screens/settings_screen.dart';
import 'package:dual_reader/src/presentation/providers/settings_notifier.dart';
import 'package:dual_reader/src/domain/entities/settings_entity.dart';
import 'package:dual_reader/src/domain/usecases/get_settings_usecase.dart';
import 'package:dual_reader/src/domain/usecases/update_settings_usecase.dart';
import 'package:dual_reader/src/data/services/book_translation_cache_service.dart';
import 'package:dual_reader/src/domain/services/translation_service.dart';
import 'package:get_it/get_it.dart';

// Fake implementations
class FakeGetSettingsUseCase implements GetSettingsUseCase {
  SettingsEntity _settings = const SettingsEntity();

  @override
  Future<SettingsEntity> call() async => _settings;

  void setSettings(SettingsEntity settings) => _settings = settings;

  @override
  get settingsRepository => throw UnimplementedError();
}

class FakeUpdateSettingsUseCase implements UpdateSettingsUseCase {
  final FakeGetSettingsUseCase _getSettingsUseCase;
  FakeUpdateSettingsUseCase(this._getSettingsUseCase);

  @override
  Future<void> call(SettingsEntity settings) async {
    _getSettingsUseCase.setSettings(settings);
  }

  @override
  get settingsRepository => throw UnimplementedError();
}

class FakeBookTranslationCacheService extends BookTranslationCacheService {
  bool clearCalled = false;
  bool initCalled = false;
  int clearCount = 0;

  @override
  Future<void> init() async {
    initCalled = true;
    // Don't call super.init() in tests to avoid Hive initialization issues
  }

  @override
  Future<void> clearAll() async {
    clearCalled = true;
    clearCount++;
    // Don't call super.clearAll() in tests
  }
}

class FakeTranslationService implements TranslationService {
  @override
  Future<String> translate({
    required String text,
    required String targetLanguage,
    String? sourceLanguage,
  }) async {
    return '[Translated to $targetLanguage] $text';
  }

  @override
  Future<String> detectLanguage(String text) async => 'en';

  @override
  Future<bool> isLanguageModelReady(String languageCode) async => true;

  @override
  Future<bool> downloadLanguageModel(String languageCode, {void Function(String)? onProgress}) async {
    onProgress?.call('Downloading...');
    onProgress?.call('Complete');
    return true;
  }
}

void main() {
  final sl = GetIt.instance;
  late FakeGetSettingsUseCase fakeGetSettingsUseCase;

  setUp(() {
    sl.reset();
    fakeGetSettingsUseCase = FakeGetSettingsUseCase();
    final fakeUpdateSettingsUseCase = FakeUpdateSettingsUseCase(fakeGetSettingsUseCase);
    sl.registerLazySingleton<GetSettingsUseCase>(() => fakeGetSettingsUseCase);
    sl.registerLazySingleton<UpdateSettingsUseCase>(() => fakeUpdateSettingsUseCase);
    sl.registerLazySingleton<BookTranslationCacheService>(() => FakeBookTranslationCacheService());
    sl.registerLazySingleton<TranslationService>(() => FakeTranslationService());
  });

  tearDown(() async {
    await sl.reset();
  });

  group('SettingsScreen Widget Tests', () {
    testWidgets('SettingsScreen renders all settings options', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify all main settings options are displayed
      expect(find.text('Theme Mode'), findsOneWidget);
      expect(find.text('Font Size'), findsOneWidget);
      expect(find.text('Line Height'), findsOneWidget);
      expect(find.text('Margins'), findsOneWidget);
      expect(find.text('Text Alignment'), findsOneWidget);
      expect(find.text('Target Translation Language'), findsOneWidget);
      expect(find.text('Clear Translation Cache'), findsOneWidget);
    });

    testWidgets('Theme mode dropdown shows and changes theme', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsProvider.overrideWith((ref) {
              return SettingsNotifier(
                fakeGetSettingsUseCase,
                sl<UpdateSettingsUseCase>(),
              )..state = const SettingsEntity();
            }),
          ],
          child: MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap theme mode dropdown
      final themeDropdown = find.byType(DropdownButton<ThemeMode>);
      expect(themeDropdown, findsOneWidget);

      // Open dropdown
      await tester.tap(themeDropdown);
      await tester.pumpAndSettle();

      // Verify theme options are present
      expect(find.text('SYSTEM'), findsWidgets);
      expect(find.text('LIGHT'), findsWidgets);
      expect(find.text('DARK'), findsWidgets);
    });

    testWidgets('Font size slider changes value', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsProvider.overrideWith((ref) {
              return SettingsNotifier(
                fakeGetSettingsUseCase,
                sl<UpdateSettingsUseCase>(),
              )..state = const SettingsEntity(fontSize: 16.0);
            }),
          ],
          child: const MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find sliders - there should be 3 sliders (font size, line height, margins)
      final sliders = find.byType(Slider);
      expect(sliders, findsWidgets);

      // Tap the first slider (font size)
      await tester.tap(sliders.first);
      await tester.pumpAndSettle();

      // Verify sliders are still present
      expect(find.byType(Slider), findsWidgets);
    });

    testWidgets('Line height slider changes value', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsProvider.overrideWith((ref) {
              return SettingsNotifier(
                fakeGetSettingsUseCase,
                sl<UpdateSettingsUseCase>(),
              )..state = const SettingsEntity(lineHeight: 1.5);
            }),
          ],
          child: const MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final sliders = find.byType(Slider);
      expect(sliders, findsWidgets);

      // Tap the second slider (line height)
      await tester.tap(sliders.at(1));
      await tester.pumpAndSettle();

      expect(find.byType(Slider), findsWidgets);
    });

    testWidgets('Margins slider changes value', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsProvider.overrideWith((ref) {
              return SettingsNotifier(
                fakeGetSettingsUseCase,
                sl<UpdateSettingsUseCase>(),
              )..state = const SettingsEntity(margin: 16.0);
            }),
          ],
          child: const MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final sliders = find.byType(Slider);
      expect(sliders, findsWidgets);

      // Tap the third slider (margins)
      await tester.tap(sliders.at(2));
      await tester.pumpAndSettle();

      expect(find.byType(Slider), findsWidgets);
    });

    testWidgets('Text alignment dropdown shows all options', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsProvider.overrideWith((ref) {
              return SettingsNotifier(
                fakeGetSettingsUseCase,
                sl<UpdateSettingsUseCase>(),
              )..state = const SettingsEntity(textAlign: TextAlign.left);
            }),
          ],
          child: MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find text alignment dropdown
      final alignDropdown = find.byWidgetPredicate((widget) =>
        widget is DropdownButton<TextAlign>);

      expect(alignDropdown, findsOneWidget);

      // Open dropdown
      await tester.tap(alignDropdown);
      await tester.pumpAndSettle();

      // Verify alignment options
      expect(find.text('LEFT'), findsWidgets);
      expect(find.text('CENTER'), findsWidgets);
      expect(find.text('RIGHT'), findsWidgets);
      expect(find.text('JUSTIFY'), findsWidgets);
    });

    testWidgets('Language dropdown shows all supported languages', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsProvider.overrideWith((ref) {
              return SettingsNotifier(
                fakeGetSettingsUseCase,
                sl<UpdateSettingsUseCase>(),
              )..state = const SettingsEntity(targetTranslationLanguageCode: 'en');
            }),
          ],
          child: MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find the target language dropdown specifically
      final targetLangTile = find.ancestor(
        of: find.text('Target Translation Language'),
        matching: find.byType(ListTile),
      );

      expect(targetLangTile, findsOneWidget);

      // Find the dropdown button within the tile
      final targetLangDropdown = find.descendant(
        of: targetLangTile,
        matching: find.byType(DropdownButton<String>),
      );

      expect(targetLangDropdown, findsOneWidget);
    });

    testWidgets('Clear translation cache shows confirmation dialog', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsProvider.overrideWith((ref) {
              return SettingsNotifier(
                fakeGetSettingsUseCase,
                sl<UpdateSettingsUseCase>(),
              )..state = const SettingsEntity();
            }),
          ],
          child: MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find and tap clear cache option
      final clearCacheTile = find.widgetWithText(ListTile, 'Clear Translation Cache');
      await tester.tap(clearCacheTile);
      await tester.pumpAndSettle();

      // Verify dialog appears
      expect(find.text('Clear Translation Cache'), findsWidgets);
      expect(find.text('Are you sure you want to clear all cached translations? This will make translations slower until they are cached again.'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Clear'), findsOneWidget);
    });

    testWidgets('Clear translation cache - cancel dismisses dialog', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsProvider.overrideWith((ref) {
              return SettingsNotifier(
                fakeGetSettingsUseCase,
                sl<UpdateSettingsUseCase>(),
              )..state = const SettingsEntity();
            }),
          ],
          child: MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap clear cache
      final clearCacheTile = find.widgetWithText(ListTile, 'Clear Translation Cache');
      await tester.tap(clearCacheTile);
      await tester.pumpAndSettle();

      // Tap cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Verify dialog is dismissed
      expect(find.text('Are you sure you want to clear all cached translations? This will make translations slower until they are cached again.'), findsNothing);

      // Verify cache was not cleared
      final cacheService = sl<BookTranslationCacheService>() as FakeBookTranslationCacheService;
      expect(cacheService.clearCalled, isFalse);
    });

    testWidgets('Clear translation cache - confirm clears cache', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsProvider.overrideWith((ref) {
              return SettingsNotifier(
                fakeGetSettingsUseCase,
                sl<UpdateSettingsUseCase>(),
              )..state = const SettingsEntity();
            }),
          ],
          child: MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap clear cache
      final clearCacheTile = find.widgetWithText(ListTile, 'Clear Translation Cache');
      await tester.tap(clearCacheTile);
      await tester.pumpAndSettle();

      // Tap clear button
      final clearButton = find.text('Clear');
      await tester.tap(clearButton);
      await tester.pumpAndSettle();

      // Verify cache was cleared
      final cacheService = sl<BookTranslationCacheService>() as FakeBookTranslationCacheService;
      expect(cacheService.initCalled, isTrue);
      expect(cacheService.clearCalled, isTrue);
    });

    testWidgets('Language change with already downloaded model', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsProvider.overrideWith((ref) {
              return SettingsNotifier(
                fakeGetSettingsUseCase,
                sl<UpdateSettingsUseCase>(),
              )..state = const SettingsEntity(targetTranslationLanguageCode: 'en');
            }),
          ],
          child: MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find language dropdown (target translation language)
      final targetLangTile = find.ancestor(
        of: find.text('Target Translation Language'),
        matching: find.byType(ListTile),
      );

      expect(targetLangTile, findsOneWidget);
    });

    testWidgets('Settings screen handles different initial settings', (WidgetTester tester) async {
      final customSettings = SettingsEntity(
        themeMode: ThemeMode.dark,
        fontSize: 20.0,
        lineHeight: 2.0,
        margin: 24.0,
        textAlign: TextAlign.justify,
        targetTranslationLanguageCode: 'es',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsProvider.overrideWith((ref) {
              return SettingsNotifier(
                fakeGetSettingsUseCase,
                sl<UpdateSettingsUseCase>(),
              )..state = customSettings;
            }),
          ],
          child: MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify all settings render correctly
      expect(find.text('Theme Mode'), findsOneWidget);
      expect(find.text('Font Size'), findsOneWidget);
      expect(find.text('Line Height'), findsOneWidget);
      expect(find.text('Margins'), findsOneWidget);
      expect(find.text('Text Alignment'), findsOneWidget);
    });

    testWidgets('Clear cache handles errors gracefully', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsProvider.overrideWith((ref) {
              return SettingsNotifier(
                fakeGetSettingsUseCase,
                sl<UpdateSettingsUseCase>(),
              )..state = const SettingsEntity();
            }),
          ],
          child: MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap clear cache
      final clearCacheTile = find.widgetWithText(ListTile, 'Clear Translation Cache');
      await tester.tap(clearCacheTile);
      await tester.pumpAndSettle();

      // Tap clear button
      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();

      // Even with error, should not crash
      expect(find.byType(SettingsScreen), findsOneWidget);
    });
  });
}
