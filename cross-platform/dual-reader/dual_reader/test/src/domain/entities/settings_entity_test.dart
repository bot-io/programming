import 'package:dual_reader/src/domain/entities/settings_entity.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SettingsEntity', () {
    // ── Construction with defaults ───────────────────────────────────

    test('should construct with all default values', () {
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

    // ── Construction with explicit values ────────────────────────────

    test('should construct with all fields explicitly provided', () {
      const settings = SettingsEntity(
        themeMode: ThemeMode.dark,
        fontlFamily: 'Arial',
        fontSize: 20.0,
        lineHeight: 2.0,
        margin: 24.0,
        textAlign: TextAlign.left,
        panelWidthRatio: 0.6,
        targetTranslationLanguageCode: 'fr',
      );

      expect(settings.themeMode, ThemeMode.dark);
      expect(settings.fontlFamily, 'Arial');
      expect(settings.fontSize, 20.0);
      expect(settings.lineHeight, 2.0);
      expect(settings.margin, 24.0);
      expect(settings.textAlign, TextAlign.left);
      expect(settings.panelWidthRatio, 0.6);
      expect(settings.targetTranslationLanguageCode, 'fr');
    });

    test('should construct with light theme mode', () {
      const settings = SettingsEntity(themeMode: ThemeMode.light);
      expect(settings.themeMode, ThemeMode.light);
    });

    test('should construct with center text alignment', () {
      const settings = SettingsEntity(textAlign: TextAlign.center);
      expect(settings.textAlign, TextAlign.center);
    });

    test('should construct with right text alignment', () {
      const settings = SettingsEntity(textAlign: TextAlign.right);
      expect(settings.textAlign, TextAlign.right);
    });

    // ── copyWith ─────────────────────────────────────────────────────

    test('copyWith returns new instance with updated themeMode', () {
      const settings = SettingsEntity();
      final copied = settings.copyWith(themeMode: ThemeMode.dark);
      expect(copied.themeMode, ThemeMode.dark);
      // Other fields unchanged
      expect(copied.fontlFamily, 'Roboto');
    });

    test('copyWith returns new instance with updated fontlFamily', () {
      const settings = SettingsEntity();
      final copied = settings.copyWith(fontlFamily: 'OpenSans');
      expect(copied.fontlFamily, 'OpenSans');
    });

    test('copyWith returns new instance with updated fontSize', () {
      const settings = SettingsEntity();
      final copied = settings.copyWith(fontSize: 22.0);
      expect(copied.fontSize, 22.0);
    });

    test('copyWith returns new instance with updated lineHeight', () {
      const settings = SettingsEntity();
      final copied = settings.copyWith(lineHeight: 1.8);
      expect(copied.lineHeight, 1.8);
    });

    test('copyWith returns new instance with updated margin', () {
      const settings = SettingsEntity();
      final copied = settings.copyWith(margin: 32.0);
      expect(copied.margin, 32.0);
    });

    test('copyWith returns new instance with updated textAlign', () {
      const settings = SettingsEntity();
      final copied = settings.copyWith(textAlign: TextAlign.left);
      expect(copied.textAlign, TextAlign.left);
    });

    test('copyWith returns new instance with updated panelWidthRatio', () {
      const settings = SettingsEntity();
      final copied = settings.copyWith(panelWidthRatio: 0.7);
      expect(copied.panelWidthRatio, 0.7);
    });

    test('copyWith returns new instance with updated targetTranslationLanguageCode', () {
      const settings = SettingsEntity();
      final copied = settings.copyWith(targetTranslationLanguageCode: 'de');
      expect(copied.targetTranslationLanguageCode, 'de');
    });

    test('copyWith with no arguments returns identical copy', () {
      const settings = SettingsEntity();
      final copied = settings.copyWith();
      expect(copied, equals(settings));
    });

    test('copyWith updates multiple fields at once', () {
      const settings = SettingsEntity();
      final copied = settings.copyWith(
        themeMode: ThemeMode.light,
        fontSize: 18.0,
        lineHeight: 1.2,
        targetTranslationLanguageCode: 'ja',
      );
      expect(copied.themeMode, ThemeMode.light);
      expect(copied.fontSize, 18.0);
      expect(copied.lineHeight, 1.2);
      expect(copied.targetTranslationLanguageCode, 'ja');
      // Unchanged fields
      expect(copied.fontlFamily, 'Roboto');
      expect(copied.margin, 16.0);
      expect(copied.textAlign, TextAlign.justify);
      expect(copied.panelWidthRatio, 0.5);
    });

    // ── Equality ─────────────────────────────────────────────────────

    test('equal when all fields match (defaults)', () {
      const settings1 = SettingsEntity();
      const settings2 = SettingsEntity();
      expect(settings1, equals(settings2));
      expect(settings1.hashCode, equals(settings2.hashCode));
    });

    test('equal when all fields match (custom values)', () {
      const settings1 = SettingsEntity(
        themeMode: ThemeMode.dark,
        fontSize: 18.0,
        targetTranslationLanguageCode: 'fr',
      );
      const settings2 = SettingsEntity(
        themeMode: ThemeMode.dark,
        fontSize: 18.0,
        targetTranslationLanguageCode: 'fr',
      );
      expect(settings1, equals(settings2));
    });

    test('not equal when themeMode differs', () {
      const settings1 = SettingsEntity(themeMode: ThemeMode.light);
      const settings2 = SettingsEntity(themeMode: ThemeMode.dark);
      expect(settings1, isNot(equals(settings2)));
    });

    test('not equal when fontlFamily differs', () {
      const settings1 = SettingsEntity(fontlFamily: 'Arial');
      const settings2 = SettingsEntity(fontlFamily: 'Roboto');
      expect(settings1, isNot(equals(settings2)));
    });

    test('not equal when fontSize differs', () {
      const settings1 = SettingsEntity(fontSize: 14.0);
      const settings2 = SettingsEntity(fontSize: 16.0);
      expect(settings1, isNot(equals(settings2)));
    });

    test('not equal when lineHeight differs', () {
      const settings1 = SettingsEntity(lineHeight: 1.4);
      const settings2 = SettingsEntity(lineHeight: 1.5);
      expect(settings1, isNot(equals(settings2)));
    });

    test('not equal when margin differs', () {
      const settings1 = SettingsEntity(margin: 8.0);
      const settings2 = SettingsEntity(margin: 16.0);
      expect(settings1, isNot(equals(settings2)));
    });

    test('not equal when textAlign differs', () {
      const settings1 = SettingsEntity(textAlign: TextAlign.left);
      const settings2 = SettingsEntity(textAlign: TextAlign.right);
      expect(settings1, isNot(equals(settings2)));
    });

    test('not equal when panelWidthRatio differs', () {
      const settings1 = SettingsEntity(panelWidthRatio: 0.4);
      const settings2 = SettingsEntity(panelWidthRatio: 0.5);
      expect(settings1, isNot(equals(settings2)));
    });

    test('not equal when targetTranslationLanguageCode differs', () {
      const settings1 = SettingsEntity(targetTranslationLanguageCode: 'en');
      const settings2 = SettingsEntity(targetTranslationLanguageCode: 'es');
      expect(settings1, isNot(equals(settings2)));
    });

    // ── Edge cases ───────────────────────────────────────────────────

    test('handles minimum fontSize value', () {
      const settings = SettingsEntity(fontSize: 0.0);
      expect(settings.fontSize, 0.0);
    });

    test('handles very large fontSize', () {
      const settings = SettingsEntity(fontSize: 100.0);
      expect(settings.fontSize, 100.0);
    });

    test('handles panelWidthRatio at extremes', () {
      const leftHeavy = SettingsEntity(panelWidthRatio: 0.0);
      const rightHeavy = SettingsEntity(panelWidthRatio: 1.0);
      expect(leftHeavy.panelWidthRatio, 0.0);
      expect(rightHeavy.panelWidthRatio, 1.0);
    });

    test('handles empty fontlFamily', () {
      const settings = SettingsEntity(fontlFamily: '');
      expect(settings.fontlFamily, '');
    });

    test('handles empty targetTranslationLanguageCode', () {
      const settings = SettingsEntity(targetTranslationLanguageCode: '');
      expect(settings.targetTranslationLanguageCode, '');
    });

    test('handles zero margin', () {
      const settings = SettingsEntity(margin: 0.0);
      expect(settings.margin, 0.0);
    });

    test('handles zero lineHeight', () {
      const settings = SettingsEntity(lineHeight: 0.0);
      expect(settings.lineHeight, 0.0);
    });
  });
}
