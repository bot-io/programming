import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dual_reader/src/domain/entities/settings_entity.dart';
import 'package:dual_reader/src/domain/usecases/get_settings_usecase.dart';
import 'package:dual_reader/src/domain/usecases/update_settings_usecase.dart';
import 'package:dual_reader/src/presentation/providers/settings_notifier.dart';

/// Fake GetSettingsUseCase
class FakeGetSettingsUseCase implements GetSettingsUseCase {
  final SettingsEntity _settings;
  int callCount = 0;

  FakeGetSettingsUseCase(this._settings);

  @override
  Future<SettingsEntity> call() async {
    callCount++;
    return _settings;
  }
}

/// Fake UpdateSettingsUseCase
class FakeUpdateSettingsUseCase implements UpdateSettingsUseCase {
  SettingsEntity? lastSavedSettings;
  int callCount = 0;

  @override
  Future<void> call(SettingsEntity settings) async {
    callCount++;
    lastSavedSettings = settings;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsNotifier Tests', () {
    test('should start with default SettingsEntity and trigger loadSettings', () async {
      const defaultSettings = SettingsEntity();
      final getUseCase = FakeGetSettingsUseCase(defaultSettings);
      final updateUseCase = FakeUpdateSettingsUseCase();

      final notifier = SettingsNotifier(getUseCase, updateUseCase);

      // Initially should have default constructor values
      expect(notifier.state.themeMode, ThemeMode.system);
      expect(notifier.state.fontSize, 16.0);

      // Wait for async _loadSettings
      await Future.delayed(const Duration(milliseconds: 50));

      expect(getUseCase.callCount, 1);
    });

    test('should load settings from use case on construction', () async {
      const loadedSettings = SettingsEntity(
        themeMode: ThemeMode.dark,
        fontSize: 20.0,
        lineHeight: 1.8,
        margin: 24.0,
        textAlign: TextAlign.left,
        panelWidthRatio: 0.6,
        targetTranslationLanguageCode: 'fr',
      );

      final getUseCase = FakeGetSettingsUseCase(loadedSettings);
      final updateUseCase = FakeUpdateSettingsUseCase();

      final notifier = SettingsNotifier(getUseCase, updateUseCase);

      await Future.delayed(const Duration(milliseconds: 50));

      expect(notifier.state.themeMode, ThemeMode.dark);
      expect(notifier.state.fontSize, 20.0);
      expect(notifier.state.lineHeight, 1.8);
      expect(notifier.state.margin, 24.0);
      expect(notifier.state.textAlign, TextAlign.left);
      expect(notifier.state.panelWidthRatio, 0.6);
      expect(notifier.state.targetTranslationLanguageCode, 'fr');
    });

    test('should update settings and call update use case', () async {
      const initialSettings = SettingsEntity();
      final getUseCase = FakeGetSettingsUseCase(initialSettings);
      final updateUseCase = FakeUpdateSettingsUseCase();

      final notifier = SettingsNotifier(getUseCase, updateUseCase);
      await Future.delayed(const Duration(milliseconds: 50));

      const newSettings = SettingsEntity(
        themeMode: ThemeMode.light,
        fontSize: 18.0,
        targetTranslationLanguageCode: 'de',
      );

      await notifier.updateSettings(newSettings);

      expect(updateUseCase.callCount, 1);
      expect(updateUseCase.lastSavedSettings, newSettings);
      expect(notifier.state.themeMode, ThemeMode.light);
      expect(notifier.state.fontSize, 18.0);
      expect(notifier.state.targetTranslationLanguageCode, 'de');
    });

    test('should update state immediately after updateSettings', () async {
      const initialSettings = SettingsEntity();
      final getUseCase = FakeGetSettingsUseCase(initialSettings);
      final updateUseCase = FakeUpdateSettingsUseCase();

      final notifier = SettingsNotifier(getUseCase, updateUseCase);
      await Future.delayed(const Duration(milliseconds: 50));

      const newSettings = SettingsEntity(
        themeMode: ThemeMode.dark,
        fontlFamily: 'Arial',
        fontSize: 22.0,
      );

      await notifier.updateSettings(newSettings);

      expect(notifier.state.themeMode, ThemeMode.dark);
      expect(notifier.state.fontlFamily, 'Arial');
      expect(notifier.state.fontSize, 22.0);
    });

    test('should handle multiple sequential updates', () async {
      const initialSettings = SettingsEntity();
      final getUseCase = FakeGetSettingsUseCase(initialSettings);
      final updateUseCase = FakeUpdateSettingsUseCase();

      final notifier = SettingsNotifier(getUseCase, updateUseCase);
      await Future.delayed(const Duration(milliseconds: 50));

      const settings1 = SettingsEntity(themeMode: ThemeMode.dark);
      await notifier.updateSettings(settings1);
      expect(notifier.state.themeMode, ThemeMode.dark);

      const settings2 = SettingsEntity(themeMode: ThemeMode.light, fontSize: 24.0);
      await notifier.updateSettings(settings2);
      expect(notifier.state.themeMode, ThemeMode.light);
      expect(notifier.state.fontSize, 24.0);

      expect(updateUseCase.callCount, 2);
    });

    test('should persist settings with all fields to update use case', () async {
      const initialSettings = SettingsEntity();
      final getUseCase = FakeGetSettingsUseCase(initialSettings);
      final updateUseCase = FakeUpdateSettingsUseCase();

      final notifier = SettingsNotifier(getUseCase, updateUseCase);
      await Future.delayed(const Duration(milliseconds: 50));

      const newSettings = SettingsEntity(
        themeMode: ThemeMode.dark,
        fontlFamily: 'Georgia',
        fontSize: 14.0,
        lineHeight: 2.0,
        margin: 32.0,
        textAlign: TextAlign.center,
        panelWidthRatio: 0.7,
        targetTranslationLanguageCode: 'bg',
      );

      await notifier.updateSettings(newSettings);

      final saved = updateUseCase.lastSavedSettings!;
      expect(saved.themeMode, ThemeMode.dark);
      expect(saved.fontlFamily, 'Georgia');
      expect(saved.fontSize, 14.0);
      expect(saved.lineHeight, 2.0);
      expect(saved.margin, 32.0);
      expect(saved.textAlign, TextAlign.center);
      expect(saved.panelWidthRatio, 0.7);
      expect(saved.targetTranslationLanguageCode, 'bg');

      // Also verify notifier state matches
      expect(notifier.state, newSettings);
    });

    test('should handle updating target translation language', () async {
      const initialSettings = SettingsEntity(targetTranslationLanguageCode: 'es');
      final getUseCase = FakeGetSettingsUseCase(initialSettings);
      final updateUseCase = FakeUpdateSettingsUseCase();

      final notifier = SettingsNotifier(getUseCase, updateUseCase);
      await Future.delayed(const Duration(milliseconds: 50));

      expect(notifier.state.targetTranslationLanguageCode, 'es');

      const newSettings = SettingsEntity(targetTranslationLanguageCode: 'fr');
      await notifier.updateSettings(newSettings);

      expect(notifier.state.targetTranslationLanguageCode, 'fr');
    });
  });

  group('SettingsEntity Tests', () {
    test('should have correct default values', () {
      const settings = SettingsEntity();

      expect(settings.themeMode, ThemeMode.system);
      expect(settings.fontlFamily, 'Roboto');
      expect(settings.fontSize, 16.0);
      expect(settings.lineHeight, 1.5);
      expect(settings.margin, 16.0);
      expect(settings.textAlign, TextAlign.justify);
      expect(settings.panelWidthRatio, 0.5);
      expect(settings.targetTranslationLanguageCode, 'es');
    });

    test('copyWith should update only specified fields', () {
      const settings = SettingsEntity();

      final updated = settings.copyWith(
        fontSize: 20.0,
        themeMode: ThemeMode.dark,
      );

      expect(updated.themeMode, ThemeMode.dark);
      expect(updated.fontSize, 20.0);
      expect(updated.fontlFamily, 'Roboto'); // unchanged
      expect(updated.lineHeight, 1.5); // unchanged
      expect(updated.margin, 16.0); // unchanged
      expect(updated.textAlign, TextAlign.justify); // unchanged
      expect(updated.panelWidthRatio, 0.5); // unchanged
      expect(updated.targetTranslationLanguageCode, 'es'); // unchanged
    });

    test('copyWith should preserve immutability', () {
      const original = SettingsEntity(fontSize: 14.0);

      final updated = original.copyWith(fontSize: 18.0);

      expect(original.fontSize, 14.0);
      expect(updated.fontSize, 18.0);
    });

    test('should be equatable', () {
      const settings1 = SettingsEntity(
        themeMode: ThemeMode.dark,
        fontSize: 18.0,
      );
      const settings2 = SettingsEntity(
        themeMode: ThemeMode.dark,
        fontSize: 18.0,
      );
      const settings3 = SettingsEntity(
        themeMode: ThemeMode.light,
        fontSize: 18.0,
      );

      expect(settings1, equals(settings2));
      expect(settings1, isNot(equals(settings3)));
    });

    test('copyWith with all fields', () {
      const settings = SettingsEntity();

      final updated = settings.copyWith(
        themeMode: ThemeMode.light,
        fontlFamily: 'Times New Roman',
        fontSize: 12.0,
        lineHeight: 1.2,
        margin: 8.0,
        textAlign: TextAlign.right,
        panelWidthRatio: 0.4,
        targetTranslationLanguageCode: 'ja',
      );

      expect(updated.themeMode, ThemeMode.light);
      expect(updated.fontlFamily, 'Times New Roman');
      expect(updated.fontSize, 12.0);
      expect(updated.lineHeight, 1.2);
      expect(updated.margin, 8.0);
      expect(updated.textAlign, TextAlign.right);
      expect(updated.panelWidthRatio, 0.4);
      expect(updated.targetTranslationLanguageCode, 'ja');
    });
  });
}
