import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hive/hive.dart';
import 'package:dual_reader/src/data/repositories/settings_repository_impl.dart';
import 'package:dual_reader/src/domain/entities/settings_entity.dart';
import 'package:dual_reader/src/domain/entities/book_entity.dart';

// ThemeMode adapter for Hive
class ThemeModeAdapter extends TypeAdapter<ThemeMode> {
  @override
  final int typeId = 2; // Unique typeId, different from BookEntity (0) and SettingsEntity (1)

  @override
  ThemeMode read(BinaryReader reader) {
    final index = reader.readByte();
    return ThemeMode.values[index];
  }

  @override
  void write(BinaryWriter writer, ThemeMode obj) {
    writer.writeByte(obj.index);
  }
}

// TextAlign adapter for Hive
class TextAlignAdapter extends TypeAdapter<TextAlign> {
  @override
  final int typeId = 3; // Unique typeId

  @override
  TextAlign read(BinaryReader reader) {
    final index = reader.readByte();
    return TextAlign.values[index];
  }

  @override
  void write(BinaryWriter writer, TextAlign obj) {
    writer.writeByte(obj.index);
  }
}

void main() {
  group('SettingsRepositoryImpl', () {
    late SettingsRepositoryImpl repository;

    setUpAll(() async {
      // Initialize Hive for testing
      Hive.init('test_hive');
      // Register adapters in the correct order
      Hive.registerAdapter(BookEntityAdapter());
      Hive.registerAdapter(ThemeModeAdapter());
      Hive.registerAdapter(TextAlignAdapter());
      Hive.registerAdapter(SettingsEntityAdapter());
    });

    setUp(() async {
      repository = SettingsRepositoryImpl();
      // Clear any existing settings
      final box = await Hive.openBox<SettingsEntity>('settings');
      await box.clear();
    });

    tearDown(() async {
      // Clear data after each test
      final box = await Hive.openBox<SettingsEntity>('settings');
      await box.clear();
      await box.close();
    });

    tearDownAll(() async {
      await Hive.deleteBoxFromDisk('settings');
      await Hive.close();
    });

    group('getSettings', () {
      test('should return default settings when none exist', () async {
        final result = await repository.getSettings();

        expect(result, isA<SettingsEntity>());
        expect(result.fontlFamily, equals('Roboto'));
        expect(result.fontSize, equals(16.0));
        expect(result.lineHeight, equals(1.5));
        expect(result.margin, equals(16.0));
        expect(result.textAlign, equals(TextAlign.justify));
        expect(result.panelWidthRatio, equals(0.5));
        expect(result.targetTranslationLanguageCode, equals('es'));
        expect(result.themeMode, equals(ThemeMode.system));
      });

      test('should return saved settings', () async {
        final settings = const SettingsEntity(
          themeMode: ThemeMode.dark,
          fontlFamily: 'Arial',
          fontSize: 20.0,
          lineHeight: 2.0,
          margin: 24.0,
          textAlign: TextAlign.left,
          panelWidthRatio: 0.6,
          targetTranslationLanguageCode: 'es',
        );

        await repository.saveSettings(settings);

        final result = await repository.getSettings();

        expect(result.themeMode, equals(ThemeMode.dark));
        expect(result.fontlFamily, equals('Arial'));
        expect(result.fontSize, equals(20.0));
        expect(result.lineHeight, equals(2.0));
        expect(result.margin, equals(24.0));
        expect(result.textAlign, equals(TextAlign.left));
        expect(result.panelWidthRatio, equals(0.6));
        expect(result.targetTranslationLanguageCode, equals('es'));
      });
    });

    group('saveSettings', () {
      test('should save settings successfully', () async {
        final settings = const SettingsEntity(
          themeMode: ThemeMode.light,
          fontlFamily: 'Georgia',
          fontSize: 18.0,
        );

        await repository.saveSettings(settings);

        final result = await repository.getSettings();

        expect(result.themeMode, equals(ThemeMode.light));
        expect(result.fontlFamily, equals('Georgia'));
        expect(result.fontSize, equals(18.0));
      });

      test('should overwrite existing settings', () async {
        final settings1 = const SettingsEntity(
          themeMode: ThemeMode.light,
          fontlFamily: 'Arial',
          fontSize: 14.0,
        );

        final settings2 = const SettingsEntity(
          themeMode: ThemeMode.dark,
          fontlFamily: 'Times New Roman',
          fontSize: 22.0,
        );

        await repository.saveSettings(settings1);
        await repository.saveSettings(settings2);

        final result = await repository.getSettings();

        expect(result.themeMode, equals(ThemeMode.dark));
        expect(result.fontlFamily, equals('Times New Roman'));
        expect(result.fontSize, equals(22.0));
      });

      test('should save partial settings and maintain defaults', () async {
        final settings = const SettingsEntity(
          fontSize: 24.0,
        );

        await repository.saveSettings(settings);

        final result = await repository.getSettings();

        expect(result.fontSize, equals(24.0));
        // Other fields should have default values
        expect(result.fontlFamily, equals('Roboto'));
        expect(result.lineHeight, equals(1.5));
        expect(result.margin, equals(16.0));
      });
    });

    group('settings fields', () {
      test('should handle theme mode changes', () async {
        final lightSettings = const SettingsEntity(themeMode: ThemeMode.light);
        await repository.saveSettings(lightSettings);
        expect((await repository.getSettings()).themeMode, equals(ThemeMode.light));

        final darkSettings = const SettingsEntity(themeMode: ThemeMode.dark);
        await repository.saveSettings(darkSettings);
        expect((await repository.getSettings()).themeMode, equals(ThemeMode.dark));

        final systemSettings = const SettingsEntity(themeMode: ThemeMode.system);
        await repository.saveSettings(systemSettings);
        expect((await repository.getSettings()).themeMode, equals(ThemeMode.system));
      });

      test('should handle font family changes', () async {
        final families = ['Roboto', 'Arial', 'Georgia', 'Times New Roman', 'Courier New'];

        for (final family in families) {
          final settings = SettingsEntity(fontlFamily: family);
          await repository.saveSettings(settings);
          expect((await repository.getSettings()).fontlFamily, equals(family));
        }
      });

      test('should handle font size changes', () async {
        final sizes = [12.0, 14.0, 16.0, 18.0, 20.0, 24.0, 32.0];

        for (final size in sizes) {
          final settings = SettingsEntity(fontSize: size);
          await repository.saveSettings(settings);
          expect((await repository.getSettings()).fontSize, equals(size));
        }
      });

      test('should handle line height changes', () async {
        final heights = [1.0, 1.2, 1.5, 1.8, 2.0, 2.5];

        for (final height in heights) {
          final settings = SettingsEntity(lineHeight: height);
          await repository.saveSettings(settings);
          expect((await repository.getSettings()).lineHeight, equals(height));
        }
      });

      test('should handle margin changes', () async {
        final margins = [8.0, 12.0, 16.0, 20.0, 24.0, 32.0];

        for (final margin in margins) {
          final settings = SettingsEntity(margin: margin);
          await repository.saveSettings(settings);
          expect((await repository.getSettings()).margin, equals(margin));
        }
      });

      test('should handle text align changes', () async {
        final alignments = [
          TextAlign.left,
          TextAlign.right,
          TextAlign.center,
          TextAlign.justify,
        ];

        for (final alignment in alignments) {
          final settings = SettingsEntity(textAlign: alignment);
          await repository.saveSettings(settings);
          expect((await repository.getSettings()).textAlign, equals(alignment));
        }
      });

      test('should handle panel width ratio changes', () async {
        final ratios = [0.3, 0.4, 0.5, 0.6, 0.7];

        for (final ratio in ratios) {
          final settings = SettingsEntity(panelWidthRatio: ratio);
          await repository.saveSettings(settings);
          expect((await repository.getSettings()).panelWidthRatio, equals(ratio));
        }
      });

      test('should handle target language code changes', () async {
        final languages = ['en', 'es', 'fr', 'de', 'it', 'pt', 'zh', 'ja'];

        for (final language in languages) {
          final settings = SettingsEntity(targetTranslationLanguageCode: language);
          await repository.saveSettings(settings);
          expect((await repository.getSettings()).targetTranslationLanguageCode, equals(language));
        }
      });
    });

    group('integration - complete settings lifecycle', () {
      test('should handle complete settings lifecycle with updates', () async {
        // Start with default settings
        var settings = await repository.getSettings();
        expect(settings.fontSize, equals(16.0));

        // Update some settings
        final updated1 = settings.copyWith(fontSize: 20.0);
        await repository.saveSettings(updated1);
        settings = await repository.getSettings();
        expect(settings.fontSize, equals(20.0));

        // Update more settings
        final updated2 = settings.copyWith(
          fontSize: 24.0,
          themeMode: ThemeMode.dark,
          fontlFamily: 'Georgia',
        );
        await repository.saveSettings(updated2);
        settings = await repository.getSettings();
        expect(settings.fontSize, equals(24.0));
        expect(settings.themeMode, equals(ThemeMode.dark));
        expect(settings.fontlFamily, equals('Georgia'));

        // Verify original settings are not preserved (they were overwritten)
        expect(settings.fontSize, equals(24.0));
        expect(settings.themeMode, equals(ThemeMode.dark));
      });

      test('should preserve all settings when saving complex configuration', () async {
        final originalSettings = SettingsEntity(
          themeMode: ThemeMode.dark,
          fontlFamily: 'Georgia',
          fontSize: 18.0,
          lineHeight: 1.8,
          margin: 20.0,
          textAlign: TextAlign.justify,
          panelWidthRatio: 0.55,
          targetTranslationLanguageCode: 'fr',
        );

        await repository.saveSettings(originalSettings);

        final retrieved = await repository.getSettings();

        expect(retrieved.themeMode, equals(originalSettings.themeMode));
        expect(retrieved.fontlFamily, equals(originalSettings.fontlFamily));
        expect(retrieved.fontSize, equals(originalSettings.fontSize));
        expect(retrieved.lineHeight, equals(originalSettings.lineHeight));
        expect(retrieved.margin, equals(originalSettings.margin));
        expect(retrieved.textAlign, equals(originalSettings.textAlign));
        expect(retrieved.panelWidthRatio, equals(originalSettings.panelWidthRatio));
        expect(retrieved.targetTranslationLanguageCode, equals(originalSettings.targetTranslationLanguageCode));
      });
    });

    group('edge cases', () {
      test('should handle empty string font family', () async {
        final settings = const SettingsEntity(fontlFamily: '');
        await repository.saveSettings(settings);
        expect((await repository.getSettings()).fontlFamily, equals(''));
      });

      test('should handle very small font size', () async {
        final settings = const SettingsEntity(fontSize: 8.0);
        await repository.saveSettings(settings);
        expect((await repository.getSettings()).fontSize, equals(8.0));
      });

      test('should handle very large font size', () async {
        final settings = const SettingsEntity(fontSize: 72.0);
        await repository.saveSettings(settings);
        expect((await repository.getSettings()).fontSize, equals(72.0));
      });

      test('should handle extreme line heights', () async {
        final settings1 = const SettingsEntity(lineHeight: 0.5);
        await repository.saveSettings(settings1);
        expect((await repository.getSettings()).lineHeight, equals(0.5));

        final settings2 = const SettingsEntity(lineHeight: 5.0);
        await repository.saveSettings(settings2);
        expect((await repository.getSettings()).lineHeight, equals(5.0));
      });

      test('should handle zero and extreme margins', () async {
        final settings1 = const SettingsEntity(margin: 0.0);
        await repository.saveSettings(settings1);
        expect((await repository.getSettings()).margin, equals(0.0));

        final settings2 = const SettingsEntity(margin: 100.0);
        await repository.saveSettings(settings2);
        expect((await repository.getSettings()).margin, equals(100.0));
      });

      test('should handle extreme panel ratios', () async {
        final settings1 = const SettingsEntity(panelWidthRatio: 0.1);
        await repository.saveSettings(settings1);
        expect((await repository.getSettings()).panelWidthRatio, equals(0.1));

        final settings2 = const SettingsEntity(panelWidthRatio: 0.9);
        await repository.saveSettings(settings2);
        expect((await repository.getSettings()).panelWidthRatio, equals(0.9));
      });
    });
  });
}
