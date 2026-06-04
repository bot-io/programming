/// Page object for Settings screen
///
/// Implements the Page Object pattern for Settings screen E2E tests.

library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import '../config/test_config.dart';
import '../helpers/test_helpers.dart';

/// Page object for Settings screen interactions
class SettingsPage {
  final WidgetTester tester;

  SettingsPage(this.tester);

  /// Expected UI elements on the settings screen
  static const String settingsTitle = 'Settings';
  static const String themeModeLabel = 'Theme Mode';
  static const String fontSizeLabel = 'Font Size';
  static const String lineHeightLabel = 'Line Height';
  static const String marginsLabel = 'Margins';
  static const String textAlignmentLabel = 'Text Alignment';
  static const String targetLanguageLabel = 'Target Translation Language';
  static const String viewLogsLabel = 'View Logs';
  static const String downloadedLanguagesLabel = 'Downloaded Languages';
  static const String translationCacheLabel = 'Translation Cache';
  static const String factoryResetLabel = 'Factory Reset';

  /// Key finders for settings elements
  Finder get settingsTitleFinder => find.text(settingsTitle);
  Finder get themeModeDropdownFinder => find.byWidgetPredicate(
        (widget) =>
            widget is DropdownButton &&
            widget.key?.toString().contains('theme_') == true,
      );
  Finder get fontSizeSliderFinder => find.byWidgetPredicate(
        (widget) =>
            widget is Slider &&
            widget.min == 12.0 &&
            widget.max == 32.0,
      );
  Finder get lineHeightSliderFinder => find.byWidgetPredicate(
        (widget) =>
            widget is Slider &&
            widget.min == 1.0 &&
            widget.max == 2.5,
      );
  Finder get marginsSliderFinder => find.byWidgetPredicate(
        (widget) =>
            widget is Slider &&
            widget.min == 0.0 &&
            widget.max == 48.0,
      );
  Finder get textAlignmentDropdownFinder => find.byWidgetPredicate(
        (widget) =>
            widget is DropdownButton &&
            widget.key?.toString().contains('align_') == true,
      );
  Finder get targetLanguageDropdownFinder => find.byWidgetPredicate(
        (widget) =>
            widget is DropdownButton &&
            widget.key?.toString().contains('lang_') == true,
      );
  Finder get viewLogsButtonFinder => find.text(viewLogsLabel);
  Finder get downloadedLanguagesButtonFinder => find.text(downloadedLanguagesLabel);
  Finder get translationCacheExpansionFinder => find.byType(ExpansionTile);
  Finder get factoryResetButtonFinder => find.text(factoryResetLabel);
  Finder get cacheClearButtonFinder => find.text('Clear Cache');
  Finder get cacheExportButtonFinder => find.text('Export');
  Finder get languageDownloadDialogFinder => find.byType(Dialog);

  /// Wait for settings screen to load
  Future<void> waitForLoad() async {
    TestHelpers.logTestStart('Settings Screen Load');
    await TestHelpers.waitForAppSettled(tester);
    await tester.waitForWidget(settingsTitleFinder);
    TestHelpers.logTestComplete('Settings Screen Load');
  }

  /// Verify settings screen is displayed
  Future<void> verifyDisplayed() async {
    expect(settingsTitleFinder, findsOneWidget);
    expect(themeModeDropdownFinder, findsOneWidget);
    expect(fontSizeSliderFinder, findsOneWidget);
  }

  /// Set theme mode
  Future<void> setThemeMode(ThemeMode mode) async {
    TestHelpers.logTestStart('Set Theme Mode: $mode');
    await tester.tap(themeModeDropdownFinder);
    await TestHelpers.waitForAppSettled(tester);

    final modeFinder = find.text(mode.toString().split('.').last.toUpperCase());
    await tester.tapWithRetry(modeFinder, description: 'Theme mode: $mode');
    await TestHelpers.waitForAppSettled(tester);
    TestHelpers.logTestComplete('Set Theme Mode');
  }

  /// Set font size
  Future<void> setFontSize(double size) async {
    TestHelpers.logTestStart('Set Font Size: $size');
    await tester.drag(fontSizeSliderFinder, Offset(size * 10, 0));
    await TestHelpers.waitForAppSettled(tester);
    TestHelpers.logTestComplete('Set Font Size');
  }

  /// Set line height
  Future<void> setLineHeight(double height) async {
    TestHelpers.logTestStart('Set Line Height: $height');
    await tester.drag(lineHeightSliderFinder, Offset(height * 100, 0));
    await TestHelpers.waitForAppSettled(tester);
    TestHelpers.logTestComplete('Set Line Height');
  }

  /// Set margins
  Future<void> setMargins(double margin) async {
    TestHelpers.logTestStart('Set Margins: $margin');
    await tester.drag(marginsSliderFinder, Offset(margin * 5, 0));
    await TestHelpers.waitForAppSettled(tester);
    TestHelpers.logTestComplete('Set Margins');
  }

  /// Set text alignment
  Future<void> setTextAlignment(TextAlign align) async {
    TestHelpers.logTestStart('Set Text Alignment: $align');
    await tester.tap(textAlignmentDropdownFinder);
    await TestHelpers.waitForAppSettled(tester);

    final alignFinder = find.text(align.name.toUpperCase());
    await tester.tapWithRetry(alignFinder, description: 'Text align: $align');
    await TestHelpers.waitForAppSettled(tester);
    TestHelpers.logTestComplete('Set Text Alignment');
  }

  /// Set target language
  Future<void> setTargetLanguage(String languageCode) async {
    TestHelpers.logTestStart('Set Target Language: $languageCode');
    await tester.tap(targetLanguageDropdownFinder);
    await TestHelpers.waitForAppSettled(tester);

    final languageFinder = find.text(languageCode.toUpperCase());
    await tester.tapWithRetry(languageFinder, description: 'Language: $languageCode');
    await TestHelpers.waitForAppSettled(tester);
    TestHelpers.logTestComplete('Set Target Language');
  }

  /// Tap view logs button
  Future<void> tapViewLogs() async {
    TestHelpers.logTestStart('Tap View Logs');
    await tester.tapWithRetry(viewLogsButtonFinder, description: 'View Logs button');
    await TestHelpers.waitForAppSettled(tester);
    TestHelpers.logTestComplete('Tap View Logs');
  }

  /// Tap downloaded languages button
  Future<void> tapDownloadedLanguages() async {
    TestHelpers.logTestStart('Tap Downloaded Languages');
    await tester.tapWithRetry(downloadedLanguagesButtonFinder,
        description: 'Downloaded Languages button');
    await TestHelpers.waitForAppSettled(tester);
    TestHelpers.logTestComplete('Tap Downloaded Languages');
  }

  /// Expand translation cache section
  Future<void> expandTranslationCache() async {
    TestHelpers.logTestStart('Expand Translation Cache');
    await tester.tap(translationCacheExpansionFinder);
    await TestHelpers.waitForAppSettled(tester);
    TestHelpers.logTestComplete('Expand Translation Cache');
  }

  /// Tap clear cache button
  Future<void> tapClearCache() async {
    TestHelpers.logTestStart('Tap Clear Cache');
    await tester.tapWithRetry(cacheClearButtonFinder, description: 'Clear Cache button');
    await TestHelpers.waitForAppSettled(tester);
    TestHelpers.logTestComplete('Tap Clear Cache');
  }

  /// Tap export cache button
  Future<void> tapExportCache() async {
    TestHelpers.logTestStart('Tap Export Cache');
    await tester.tapWithRetry(cacheExportButtonFinder, description: 'Export button');
    await TestHelpers.waitForAppSettled(tester);
    TestHelpers.logTestComplete('Tap Export Cache');
  }

  /// Tap factory reset button
  Future<void> tapFactoryReset() async {
    TestHelpers.logTestStart('Tap Factory Reset');
    await tester.tapWithRetry(factoryResetButtonFinder, description: 'Factory Reset button');
    await TestHelpers.waitForAppSettled(tester);
    TestHelpers.logTestComplete('Tap Factory Reset');
  }

  /// Verify theme mode setting
  void verifyThemeMode(ThemeMode expectedMode) {
    final dropdown = themeModeDropdownFinder.evaluate().first.widget as DropdownButton<ThemeMode>;
    expect(dropdown.value, equals(expectedMode));
  }

  /// Verify font size setting
  void verifyFontSize(double expectedSize) {
    final slider = fontSizeSliderFinder.evaluate().first.widget as Slider;
    expect(slider.value, closeTo(expectedSize, 0.5));
  }

  /// Verify line height setting
  void verifyLineHeight(double expectedHeight) {
    final slider = lineHeightSliderFinder.evaluate().first.widget as Slider;
    expect(slider.value, closeTo(expectedHeight, 0.1));
  }

  /// Verify margins setting
  void verifyMargins(double expectedMargin) {
    final slider = marginsSliderFinder.evaluate().first.widget as Slider;
    expect(slider.value, closeTo(expectedMargin, 0.5));
  }

  /// Verify text alignment setting
  void verifyTextAlignment(TextAlign expectedAlign) {
    final dropdown = textAlignmentDropdownFinder.evaluate().first.widget as DropdownButton<TextAlign>;
    expect(dropdown.value, equals(expectedAlign));
  }

  /// Verify target language setting
  void verifyTargetLanguage(String expectedLanguage) {
    final dropdown = targetLanguageDropdownFinder.evaluate().first.widget as DropdownButton<String>;
    expect(dropdown.value, equals(expectedLanguage));
  }

  /// Get current theme mode
  ThemeMode getCurrentThemeMode() {
    final dropdown = themeModeDropdownFinder.evaluate().first.widget as DropdownButton<ThemeMode>;
    return dropdown.value!;
  }

  /// Get current font size
  double getCurrentFontSize() {
    final slider = fontSizeSliderFinder.evaluate().first.widget as Slider;
    return slider.value;
  }

  /// Get current target language
  String getCurrentTargetLanguage() {
    final dropdown = targetLanguageDropdownFinder.evaluate().first.widget as DropdownButton<String>;
    return dropdown.value!;
  }

  /// Verify log viewer dialog is displayed
  void verifyLogViewerVisible() {
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('App Logs'), findsOneWidget);
  }

  /// Verify language download dialog is displayed
  void verifyLanguageDownloadDialogVisible() {
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('Downloading Language Model'), findsOneWidget);
  }

  /// Confirm language download in dialog
  Future<void> confirmLanguageDownload() async {
    final confirmButton = find.text('Delete Everything');
    if (confirmButton.evaluate().isNotEmpty) {
      await tester.tap(confirmButton);
      await TestHelpers.waitForAppSettled(tester);
    }
  }

  /// Cancel language download in dialog
  Future<void> cancelLanguageDownload() async {
    final cancelButton = find.text('Cancel');
    if (cancelButton.evaluate().isNotEmpty) {
      await tester.tap(cancelButton);
      await TestHelpers.waitForAppSettled(tester);
    }
  }

  /// Navigate back
  Future<void> goBack() async {
    TestHelpers.logTestStart('Navigate Back from Settings');
    final backButtonFinder = find.byType(BackButton);
    await tester.tapWithRetry(backButtonFinder, description: 'Back button');
    await TestHelpers.waitForAppSettled(tester);
    TestHelpers.logTestComplete('Navigate Back from Settings');
  }

  /// Verify cache statistics are displayed
  void verifyCacheStatistics({
    int? entryCount,
    String? sizeBytes,
    double? hitRate,
  }) {
    // Verify statistics are shown
    if (entryCount != null) {
      expect(find.textContaining('$entryCount'), findsOneWidget);
    }
  }

  /// Verify cache is cleared
  void verifyCacheCleared() {
    expect(find.text('Translation cache cleared'), findsOneWidget);
  }

  /// Verify export succeeded
  void verifyCacheExported() {
    expect(find.text('Cache exported to clipboard'), findsOneWidget);
  }

  /// Get cache size displayed
  String getCacheSizeText() {
    final sizeFinder = find.textContaining(RegExp(r'\d+ B|\d+ KB|\d+ MB'));
    if (sizeFinder.evaluate().isNotEmpty) {
      final textWidget = sizeFinder.evaluate().first.widget as Text;
      return textWidget.data ?? '';
    }
    return '';
  }

  /// Get current margins value
  double getCurrentMargins() {
    final slider = marginsSliderFinder.evaluate().first.widget as Slider;
    return slider.value;
  }

  /// Get current text alignment value
  TextAlign getCurrentTextAlignment() {
    final dropdown = textAlignmentDropdownFinder.evaluate().first.widget as DropdownButton<TextAlign>;
    return dropdown.value!;
  }
}

// Import for missing types
import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart' show Dialog, Switch, BackButton, DropdownButton, ThemeMode, TextAlign;
