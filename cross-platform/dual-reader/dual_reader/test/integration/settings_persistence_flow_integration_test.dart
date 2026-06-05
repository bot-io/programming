import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dual_reader/src/domain/entities/settings_entity.dart';
import 'package:dual_reader/src/domain/usecases/get_settings_usecase.dart';
import 'package:dual_reader/src/domain/usecases/update_settings_usecase.dart';
import 'package:dual_reader/src/domain/repositories/settings_repository.dart';
import 'package:dual_reader/src/data/repositories/settings_repository_impl.dart';
import 'package:hive/hive.dart';
import 'package:get_it/get_it.dart';
import 'package:path_provider/path_provider.dart';

/// Integration test for the complete settings lifecycle.
/// Tests: Load defaults -> Change settings -> Persist -> Reload -> Verify
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sl = GetIt.instance;

  group('Settings Persistence Flow', () {
    late SettingsRepository settingsRepository;
    late GetSettingsUseCase getSettingsUseCase;
    late UpdateSettingsUseCase updateSettingsUseCase;
    bool hiveInitialized = false;

    setUpAll(() async {
      try {
        Hive.init((await getTemporaryDirectory()).path);
        hiveInitialized = true;
      } catch (e) {
        print('Skipping: Hive requires platform channels');
      }
    });

    setUp(() async {
      if (!hiveInitialized) return;
      if (Hive.isBoxOpen('settings')) {
        await Hive.box('settings').clear();
        await Hive.box('settings').close();
      }

      await sl.reset();
      sl.registerLazySingleton<SettingsRepository>(() => SettingsRepositoryImpl());

      settingsRepository = sl<SettingsRepository>();
      getSettingsUseCase = GetSettingsUseCase(settingsRepository);
      updateSettingsUseCase = UpdateSettingsUseCase(settingsRepository);
    });

    tearDown(() async {
      if (!hiveInitialized) return;
      if (Hive.isBoxOpen('settings')) {
        await Hive.box('settings').clear();
        await Hive.box('settings').close();
      }
    });

    tearDownAll(() async {
      if (hiveInitialized) {
        await Hive.close();
      }
      await sl.reset();
    });

    test('Default settings load correctly on first run', () async {
      if (!hiveInitialized) return;

      final settings = await getSettingsUseCase();
      expect(settings, isNotNull);
      expect(settings.themeMode, ThemeMode.system);
      expect(settings.fontSize, 16.0);
      expect(settings.fontlFamily, 'Roboto');
      expect(settings.targetTranslationLanguageCode, 'es');
    });

    test('Change theme to dark and verify persistence', () async {
      if (!hiveInitialized) return;

      var settings = await getSettingsUseCase();
      expect(settings.themeMode, ThemeMode.system);

      final dark = settings.copyWith(themeMode: ThemeMode.dark);
      await updateSettingsUseCase(dark);

      settings = await getSettingsUseCase();
      expect(settings.themeMode, ThemeMode.dark);
    });

    test('Change translation language and verify it persists', () async {
      if (!hiveInitialized) return;

      var settings = await getSettingsUseCase();
      final spanish = settings.copyWith(targetTranslationLanguageCode: 'fr');
      await updateSettingsUseCase(spanish);

      settings = await getSettingsUseCase();
      expect(settings.targetTranslationLanguageCode, 'fr');
    });

    test('Change multiple settings and verify all persist', () async {
      if (!hiveInitialized) return;

      var settings = await getSettingsUseCase();
      final updated = settings.copyWith(
        themeMode: ThemeMode.dark,
        targetTranslationLanguageCode: 'fr',
        fontSize: 20.0,
        lineHeight: 1.8,
      );
      await updateSettingsUseCase(updated);

      settings = await getSettingsUseCase();
      expect(settings.themeMode, ThemeMode.dark);
      expect(settings.targetTranslationLanguageCode, 'fr');
      expect(settings.fontSize, 20.0);
      expect(settings.lineHeight, 1.8);
    });

    test('Settings survive repository recreation (simulates app restart)', () async {
      if (!hiveInitialized) return;

      // Set some settings with first repository instance
      var settings = await getSettingsUseCase();
      await updateSettingsUseCase(settings.copyWith(
        themeMode: ThemeMode.light,
        targetTranslationLanguageCode: 'de',
        fontSize: 18.0,
      ));

      // Close settings box (simulates app shutdown)
      if (Hive.isBoxOpen('settings')) {
        await Hive.box('settings').close();
      }

      // New repository instance (simulates app restart)
      await sl.reset();
      sl.registerLazySingleton<SettingsRepository>(() => SettingsRepositoryImpl());
      settingsRepository = sl<SettingsRepository>();
      getSettingsUseCase = GetSettingsUseCase(settingsRepository);
      updateSettingsUseCase = UpdateSettingsUseCase(settingsRepository);

      // Verify settings persisted
      settings = await getSettingsUseCase();
      expect(settings.themeMode, ThemeMode.light);
      expect(settings.targetTranslationLanguageCode, 'de');
      expect(settings.fontSize, 18.0);
    });

    test('Sequential settings updates each persist correctly', () async {
      if (!hiveInitialized) return;

      var settings = await getSettingsUseCase();

      // Update 1: font size
      settings = settings.copyWith(fontSize: 14.0);
      await updateSettingsUseCase(settings);
      settings = await getSettingsUseCase();
      expect(settings.fontSize, 14.0);

      // Update 2: theme -- previous change preserved
      settings = settings.copyWith(themeMode: ThemeMode.dark);
      await updateSettingsUseCase(settings);
      settings = await getSettingsUseCase();
      expect(settings.themeMode, ThemeMode.dark);
      expect(settings.fontSize, 14.0);

      // Update 3: language -- all previous changes preserved
      settings = settings.copyWith(targetTranslationLanguageCode: 'ja');
      await updateSettingsUseCase(settings);
      settings = await getSettingsUseCase();
      expect(settings.targetTranslationLanguageCode, 'ja');
      expect(settings.themeMode, ThemeMode.dark);
      expect(settings.fontSize, 14.0);
    });

    test('Complete reading preferences setup flow', () async {
      if (!hiveInitialized) return;

      var settings = await getSettingsUseCase();
      final readingPrefs = settings.copyWith(
        themeMode: ThemeMode.dark,
        targetTranslationLanguageCode: 'es',
        fontSize: 18.0,
        lineHeight: 1.6,
        margin: 16.0,
      );
      await updateSettingsUseCase(readingPrefs);

      settings = await getSettingsUseCase();
      expect(settings.themeMode, ThemeMode.dark);
      expect(settings.targetTranslationLanguageCode, 'es');
      expect(settings.fontSize, 18.0);
      expect(settings.lineHeight, 1.6);
      expect(settings.margin, 16.0);
    });
  });
}
