import 'package:flutter_test/flutter_test.dart';
import 'package:dual_reader/models/app_settings.dart';

void main() {
  group('AppSettings', () {
    group('Default Values', () {
      test('creates with default values', () {
        final settings = AppSettings();

        expect(settings.theme, 'dark');
        expect(settings.fontFamily, 'Roboto');
        expect(settings.fontSize, 16);
        expect(settings.lineHeight, 1.6);
        expect(settings.marginSize, 2);
        expect(settings.textAlignment, 'left');
        expect(settings.translationLanguage, 'es');
        expect(settings.autoTranslate, true);
        expect(settings.panelRatio, 0.5);
        expect(settings.syncScrolling, true);
      });
    });

    group('Custom Values', () {
      test('creates with custom values', () {
        final settings = AppSettings(
          theme: 'light',
          fontFamily: 'Arial',
          fontSize: 18,
          lineHeight: 1.8,
          marginSize: 3,
          textAlignment: 'justify',
          translationLanguage: 'fr',
          autoTranslate: false,
          panelRatio: 0.6,
          syncScrolling: false,
        );

        expect(settings.theme, 'light');
        expect(settings.fontFamily, 'Arial');
        expect(settings.fontSize, 18);
        expect(settings.lineHeight, 1.8);
        expect(settings.marginSize, 3);
        expect(settings.textAlignment, 'justify');
        expect(settings.translationLanguage, 'fr');
        expect(settings.autoTranslate, false);
        expect(settings.panelRatio, 0.6);
        expect(settings.syncScrolling, false);
      });

      test('creates with partial custom values', () {
        final settings = AppSettings(
          theme: 'sepia',
          fontSize: 14,
        );

        expect(settings.theme, 'sepia');
        expect(settings.fontSize, 14);
        // Other values should use defaults
        expect(settings.fontFamily, 'Roboto');
        expect(settings.lineHeight, 1.6);
        expect(settings.marginSize, 2);
        expect(settings.textAlignment, 'left');
        expect(settings.translationLanguage, 'es');
        expect(settings.autoTranslate, true);
        expect(settings.panelRatio, 0.5);
        expect(settings.syncScrolling, true);
      });
    });

    group('copyWith', () {
      test('creates new instance with updated values', () {
        final original = AppSettings();
        final updated = original.copyWith(
          theme: 'light',
          fontSize: 20,
          autoTranslate: false,
        );

        // Original unchanged
        expect(original.theme, 'dark');
        expect(original.fontSize, 16);
        expect(original.autoTranslate, true);

        // Updated has new values
        expect(updated.theme, 'light');
        expect(updated.fontSize, 20);
        expect(updated.autoTranslate, false);

        // Other values preserved
        expect(updated.fontFamily, original.fontFamily);
        expect(updated.lineHeight, original.lineHeight);
        expect(updated.marginSize, original.marginSize);
      });

      test('preserves all values when no parameters provided', () {
        final original = AppSettings(
          theme: 'sepia',
          fontSize: 14,
        );
        final copied = original.copyWith();

        expect(copied.theme, original.theme);
        expect(copied.fontSize, original.fontSize);
        expect(copied.fontFamily, original.fontFamily);
        expect(copied.lineHeight, original.lineHeight);
        expect(copied.marginSize, original.marginSize);
        expect(copied.textAlignment, original.textAlignment);
        expect(copied.translationLanguage, original.translationLanguage);
        expect(copied.autoTranslate, original.autoTranslate);
        expect(copied.panelRatio, original.panelRatio);
        expect(copied.syncScrolling, original.syncScrolling);
      });

      test('updates multiple values at once', () {
        final original = AppSettings();
        final updated = original.copyWith(
          theme: 'light',
          fontFamily: 'Times New Roman',
          fontSize: 22,
          lineHeight: 2.0,
          marginSize: 4,
          textAlignment: 'center',
          translationLanguage: 'de',
          autoTranslate: false,
          panelRatio: 0.7,
          syncScrolling: false,
        );

        expect(updated.theme, 'light');
        expect(updated.fontFamily, 'Times New Roman');
        expect(updated.fontSize, 22);
        expect(updated.lineHeight, 2.0);
        expect(updated.marginSize, 4);
        expect(updated.textAlignment, 'center');
        expect(updated.translationLanguage, 'de');
        expect(updated.autoTranslate, false);
        expect(updated.panelRatio, 0.7);
        expect(updated.syncScrolling, false);
      });
    });

    group('JSON Serialization', () {
      test('toJson returns correct map structure', () {
        final settings = AppSettings(
          theme: 'light',
          fontFamily: 'Arial',
          fontSize: 18,
          lineHeight: 1.8,
          marginSize: 3,
          textAlignment: 'justify',
          translationLanguage: 'fr',
          autoTranslate: false,
          panelRatio: 0.6,
          syncScrolling: false,
        );

        final json = settings.toJson();

        expect(json, isA<Map<String, dynamic>>());
        expect(json['theme'], 'light');
        expect(json['fontFamily'], 'Arial');
        expect(json['fontSize'], 18);
        expect(json['lineHeight'], 1.8);
        expect(json['marginSize'], 3);
        expect(json['textAlignment'], 'justify');
        expect(json['translationLanguage'], 'fr');
        expect(json['autoTranslate'], false);
        expect(json['panelRatio'], 0.6);
        expect(json['syncScrolling'], false);
      });

      test('toJson includes all fields', () {
        final settings = AppSettings();
        final json = settings.toJson();

        expect(json.keys.length, 10);
        expect(json.containsKey('theme'), true);
        expect(json.containsKey('fontFamily'), true);
        expect(json.containsKey('fontSize'), true);
        expect(json.containsKey('lineHeight'), true);
        expect(json.containsKey('marginSize'), true);
        expect(json.containsKey('textAlignment'), true);
        expect(json.containsKey('translationLanguage'), true);
        expect(json.containsKey('autoTranslate'), true);
        expect(json.containsKey('panelRatio'), true);
        expect(json.containsKey('syncScrolling'), true);
      });

      test('toJson with default values', () {
        final settings = AppSettings();
        final json = settings.toJson();

        expect(json['theme'], 'dark');
        expect(json['fontFamily'], 'Roboto');
        expect(json['fontSize'], 16);
        expect(json['lineHeight'], 1.6);
        expect(json['marginSize'], 2);
        expect(json['textAlignment'], 'left');
        expect(json['translationLanguage'], 'es');
        expect(json['autoTranslate'], true);
        expect(json['panelRatio'], 0.5);
        expect(json['syncScrolling'], true);
      });
    });

    group('JSON Deserialization', () {
      test('fromJson creates AppSettings from valid map', () {
        final json = {
          'theme': 'light',
          'fontFamily': 'Arial',
          'fontSize': 18,
          'lineHeight': 1.8,
          'marginSize': 3,
          'textAlignment': 'justify',
          'translationLanguage': 'fr',
          'autoTranslate': false,
          'panelRatio': 0.6,
          'syncScrolling': false,
        };

        final settings = AppSettings.fromJson(json);

        expect(settings.theme, 'light');
        expect(settings.fontFamily, 'Arial');
        expect(settings.fontSize, 18);
        expect(settings.lineHeight, 1.8);
        expect(settings.marginSize, 3);
        expect(settings.textAlignment, 'justify');
        expect(settings.translationLanguage, 'fr');
        expect(settings.autoTranslate, false);
        expect(settings.panelRatio, 0.6);
        expect(settings.syncScrolling, false);
      });

      test('fromJson uses default values for missing fields', () {
        final json = {
          'theme': 'light',
          'fontSize': 20,
        };

        final settings = AppSettings.fromJson(json);

        expect(settings.theme, 'light');
        expect(settings.fontSize, 20);
        // Other fields should use defaults
        expect(settings.fontFamily, 'Roboto');
        expect(settings.lineHeight, 1.6);
        expect(settings.marginSize, 2);
        expect(settings.textAlignment, 'left');
        expect(settings.translationLanguage, 'es');
        expect(settings.autoTranslate, true);
        expect(settings.panelRatio, 0.5);
        expect(settings.syncScrolling, true);
      });

      test('fromJson handles null values with defaults', () {
        final json = {
          'theme': null,
          'fontFamily': null,
          'fontSize': null,
          'lineHeight': null,
          'marginSize': null,
          'textAlignment': null,
          'translationLanguage': null,
          'autoTranslate': null,
          'panelRatio': null,
          'syncScrolling': null,
        };

        final settings = AppSettings.fromJson(json);

        // All should use defaults
        expect(settings.theme, 'dark');
        expect(settings.fontFamily, 'Roboto');
        expect(settings.fontSize, 16);
        expect(settings.lineHeight, 1.6);
        expect(settings.marginSize, 2);
        expect(settings.textAlignment, 'left');
        expect(settings.translationLanguage, 'es');
        expect(settings.autoTranslate, true);
        expect(settings.panelRatio, 0.5);
        expect(settings.syncScrolling, true);
      });

      test('fromJson handles empty map with defaults', () {
        final json = <String, dynamic>{};
        final settings = AppSettings.fromJson(json);

        expect(settings.theme, 'dark');
        expect(settings.fontFamily, 'Roboto');
        expect(settings.fontSize, 16);
        expect(settings.lineHeight, 1.6);
        expect(settings.marginSize, 2);
        expect(settings.textAlignment, 'left');
        expect(settings.translationLanguage, 'es');
        expect(settings.autoTranslate, true);
        expect(settings.panelRatio, 0.5);
        expect(settings.syncScrolling, true);
      });

      test('fromJson handles numeric types correctly', () {
        final json = {
          'fontSize': 18.5, // Double instead of int
          'lineHeight': 2, // Int instead of double
          'marginSize': 3.7, // Double instead of int
          'panelRatio': 0.6,
        };

        final settings = AppSettings.fromJson(json);

        expect(settings.fontSize, 18); // Should convert to int
        expect(settings.lineHeight, 2.0); // Should convert to double
        expect(settings.marginSize, 3); // Should convert to int
        expect(settings.panelRatio, 0.6);
      });
    });

    group('JSON String Serialization', () {
      test('toJsonString returns valid JSON string', () {
        final settings = AppSettings(
          theme: 'light',
          fontSize: 18,
        );

        final jsonString = settings.toJsonString();

        expect(jsonString, isA<String>());
        expect(jsonString.contains('"theme":"light"'), true);
        expect(jsonString.contains('"fontSize":18'), true);
      });

      test('toJsonString produces parseable JSON', () {
        final settings = AppSettings();
        final jsonString = settings.toJsonString();

        // Should not throw
        expect(() => AppSettings.fromJsonString(jsonString), returnsNormally);
      });
    });

    group('JSON String Deserialization', () {
      test('fromJsonString creates AppSettings from valid JSON string', () {
        final jsonString = '''
        {
          "theme": "light",
          "fontFamily": "Arial",
          "fontSize": 18,
          "lineHeight": 1.8,
          "marginSize": 3,
          "textAlignment": "justify",
          "translationLanguage": "fr",
          "autoTranslate": false,
          "panelRatio": 0.6,
          "syncScrolling": false
        }
        ''';

        final settings = AppSettings.fromJsonString(jsonString);

        expect(settings.theme, 'light');
        expect(settings.fontFamily, 'Arial');
        expect(settings.fontSize, 18);
        expect(settings.lineHeight, 1.8);
        expect(settings.marginSize, 3);
        expect(settings.textAlignment, 'justify');
        expect(settings.translationLanguage, 'fr');
        expect(settings.autoTranslate, false);
        expect(settings.panelRatio, 0.6);
        expect(settings.syncScrolling, false);
      });

      test('fromJsonString handles invalid JSON gracefully', () {
        final invalidJson = 'invalid json string';

        final settings = AppSettings.fromJsonString(invalidJson);

        // Should return default settings
        expect(settings.theme, 'dark');
        expect(settings.fontFamily, 'Roboto');
        expect(settings.fontSize, 16);
      });

      test('fromJsonString handles malformed JSON gracefully', () {
        final malformedJson = '{"theme": "light", invalid}';

        final settings = AppSettings.fromJsonString(malformedJson);

        // Should return default settings
        expect(settings.theme, 'dark');
      });

      test('fromJsonString handles empty string gracefully', () {
        final emptyJson = '';

        final settings = AppSettings.fromJsonString(emptyJson);

        // Should return default settings
        expect(settings.theme, 'dark');
        expect(settings.fontFamily, 'Roboto');
      });
    });

    group('Round-trip Serialization', () {
      test('serialize then deserialize preserves all values', () {
        final original = AppSettings(
          theme: 'sepia',
          fontFamily: 'Georgia',
          fontSize: 20,
          lineHeight: 1.9,
          marginSize: 4,
          textAlignment: 'center',
          translationLanguage: 'de',
          autoTranslate: false,
          panelRatio: 0.65,
          syncScrolling: false,
        );

        final json = original.toJson();
        final restored = AppSettings.fromJson(json);

        expect(restored.theme, original.theme);
        expect(restored.fontFamily, original.fontFamily);
        expect(restored.fontSize, original.fontSize);
        expect(restored.lineHeight, original.lineHeight);
        expect(restored.marginSize, original.marginSize);
        expect(restored.textAlignment, original.textAlignment);
        expect(restored.translationLanguage, original.translationLanguage);
        expect(restored.autoTranslate, original.autoTranslate);
        expect(restored.panelRatio, original.panelRatio);
        expect(restored.syncScrolling, original.syncScrolling);
      });

      test('toJsonString then fromJsonString preserves all values', () {
        final original = AppSettings(
          theme: 'light',
          fontFamily: 'Times New Roman',
          fontSize: 22,
          lineHeight: 2.0,
          marginSize: 1,
          textAlignment: 'justify',
          translationLanguage: 'it',
          autoTranslate: true,
          panelRatio: 0.55,
          syncScrolling: true,
        );

        final jsonString = original.toJsonString();
        final restored = AppSettings.fromJsonString(jsonString);

        expect(restored.theme, original.theme);
        expect(restored.fontFamily, original.fontFamily);
        expect(restored.fontSize, original.fontSize);
        expect(restored.lineHeight, original.lineHeight);
        expect(restored.marginSize, original.marginSize);
        expect(restored.textAlignment, original.textAlignment);
        expect(restored.translationLanguage, original.translationLanguage);
        expect(restored.autoTranslate, original.autoTranslate);
        expect(restored.panelRatio, original.panelRatio);
        expect(restored.syncScrolling, original.syncScrolling);
      });

      test('multiple round-trips preserve values', () {
        var settings = AppSettings(
          theme: 'dark',
          fontSize: 14,
          translationLanguage: 'pt',
        );

        // Perform multiple round-trips
        for (int i = 0; i < 5; i++) {
          final json = settings.toJson();
          settings = AppSettings.fromJson(json);
        }

        expect(settings.theme, 'dark');
        expect(settings.fontSize, 14);
        expect(settings.translationLanguage, 'pt');
      });
    });

    group('Export/Import Functionality', () {
      test('export settings can be imported correctly', () {
        final original = AppSettings(
          theme: 'light',
          fontFamily: 'Arial',
          fontSize: 18,
          lineHeight: 1.8,
          marginSize: 3,
          textAlignment: 'justify',
          translationLanguage: 'fr',
          autoTranslate: false,
          panelRatio: 0.6,
          syncScrolling: false,
        );

        // Export
        final jsonString = original.toJsonString();

        // Import
        final imported = AppSettings.fromJsonString(jsonString);

        expect(imported.theme, original.theme);
        expect(imported.fontFamily, original.fontFamily);
        expect(imported.fontSize, original.fontSize);
        expect(imported.lineHeight, original.lineHeight);
        expect(imported.marginSize, original.marginSize);
        expect(imported.textAlignment, original.textAlignment);
        expect(imported.translationLanguage, original.translationLanguage);
        expect(imported.autoTranslate, original.autoTranslate);
        expect(imported.panelRatio, original.panelRatio);
        expect(imported.syncScrolling, original.syncScrolling);
      });

      test('exported JSON contains all required fields', () {
        final settings = AppSettings();
        final jsonString = settings.toJsonString();
        final json = AppSettings.fromJsonString(jsonString).toJson();

        expect(json.containsKey('theme'), true);
        expect(json.containsKey('fontFamily'), true);
        expect(json.containsKey('fontSize'), true);
        expect(json.containsKey('lineHeight'), true);
        expect(json.containsKey('marginSize'), true);
        expect(json.containsKey('textAlignment'), true);
        expect(json.containsKey('translationLanguage'), true);
        expect(json.containsKey('autoTranslate'), true);
        expect(json.containsKey('panelRatio'), true);
        expect(json.containsKey('syncScrolling'), true);
      });
    });

    group('Edge Cases', () {
      test('handles extreme font sizes', () {
        final smallFont = AppSettings(fontSize: 12);
        final largeFont = AppSettings(fontSize: 24);

        expect(smallFont.fontSize, 12);
        expect(largeFont.fontSize, 24);

        // Round-trip should preserve
        expect(AppSettings.fromJson(smallFont.toJson()).fontSize, 12);
        expect(AppSettings.fromJson(largeFont.toJson()).fontSize, 24);
      });

      test('handles extreme line heights', () {
        final smallLineHeight = AppSettings(lineHeight: 1.0);
        final largeLineHeight = AppSettings(lineHeight: 2.5);

        expect(smallLineHeight.lineHeight, 1.0);
        expect(largeLineHeight.lineHeight, 2.5);

        // Round-trip should preserve
        expect(AppSettings.fromJson(smallLineHeight.toJson()).lineHeight, 1.0);
        expect(AppSettings.fromJson(largeLineHeight.toJson()).lineHeight, 2.5);
      });

      test('handles all margin sizes', () {
        for (int i = 0; i <= 4; i++) {
          final settings = AppSettings(marginSize: i);
          expect(settings.marginSize, i);
          expect(AppSettings.fromJson(settings.toJson()).marginSize, i);
        }
      });

      test('handles all text alignments', () {
        final alignments = ['left', 'center', 'justify'];
        for (final alignment in alignments) {
          final settings = AppSettings(textAlignment: alignment);
          expect(settings.textAlignment, alignment);
          expect(AppSettings.fromJson(settings.toJson()).textAlignment, alignment);
        }
      });

      test('handles all themes', () {
        final themes = ['dark', 'light', 'sepia'];
        for (final theme in themes) {
          final settings = AppSettings(theme: theme);
          expect(settings.theme, theme);
          expect(AppSettings.fromJson(settings.toJson()).theme, theme);
        }
      });

      test('handles panel ratio boundaries', () {
        final minRatio = AppSettings(panelRatio: 0.0);
        final maxRatio = AppSettings(panelRatio: 1.0);
        final midRatio = AppSettings(panelRatio: 0.5);

        expect(minRatio.panelRatio, 0.0);
        expect(maxRatio.panelRatio, 1.0);
        expect(midRatio.panelRatio, 0.5);

        // Round-trip should preserve
        expect(AppSettings.fromJson(minRatio.toJson()).panelRatio, 0.0);
        expect(AppSettings.fromJson(maxRatio.toJson()).panelRatio, 1.0);
        expect(AppSettings.fromJson(midRatio.toJson()).panelRatio, 0.5);
      });

      test('handles boolean values correctly', () {
        final autoTranslateTrue = AppSettings(autoTranslate: true);
        final autoTranslateFalse = AppSettings(autoTranslate: false);
        final syncScrollingTrue = AppSettings(syncScrolling: true);
        final syncScrollingFalse = AppSettings(syncScrolling: false);

        expect(autoTranslateTrue.autoTranslate, true);
        expect(autoTranslateFalse.autoTranslate, false);
        expect(syncScrollingTrue.syncScrolling, true);
        expect(syncScrollingFalse.syncScrolling, false);

        // Round-trip should preserve
        expect(AppSettings.fromJson(autoTranslateTrue.toJson()).autoTranslate, true);
        expect(AppSettings.fromJson(autoTranslateFalse.toJson()).autoTranslate, false);
        expect(AppSettings.fromJson(syncScrollingTrue.toJson()).syncScrolling, true);
        expect(AppSettings.fromJson(syncScrollingFalse.toJson()).syncScrolling, false);
      });
    });
  });
}
