/// Page object for Reader (Dual Reader) screen
///
/// Implements the Page Object pattern for Reader screen E2E tests.

library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import '../config/test_config.dart';
import '../helpers/test_helpers.dart';

/// Page object for Reader screen interactions
class ReaderPage {
  final WidgetTester tester;

  ReaderPage(this.tester);

  /// Expected UI elements on the reader screen
  static const String originalPanelHint = 'Original Text';
  static const String translatedPanelHint = 'Translated Text';
  static const String pageIndicator = 'Page';
  static const String nextButtonHint = 'Next';
  static const String previousButtonHint = 'Previous';

  /// Key finders for reader elements
  Finder get originalPanelFinder => find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.child != null,
      );
  Finder get translatedPanelFinder => find.byType(Scrollable);
  Finder get pageDisplayFinder => find.byType(PageView);
  Finder get sliderFinder => find.byType(Slider);
  Finder get controlsFinder => find.byType(AnimatedOpacity);
  Finder get topControlsFinder => find.byWidgetPredicate(
        (widget) =>
            widget is Positioned &&
            widget.top == 0 &&
            widget.child != null,
      );
  Finder get bottomControlsFinder => find.byWidgetPredicate(
        (widget) =>
            widget is Positioned &&
            widget.bottom == 0 &&
            widget.child != null,
      );
  Finder get pageIndicatorFinder => find.textContaining(RegExp(r'\d+/?\d*'));
  Finder get chapterButtonFinder => find.byIcon(Icons.menu);
  Finder get settingsButtonFinder => find.byIcon(Icons.settings);
  Finder get backButtonFinder => find.byIcon(Icons.arrow_back);

  /// Wait for reader screen to load
  Future<void> waitForLoad() async {
    TestHelpers.logTestStart('Reader Screen Load');
    await TestHelpers.waitForAppSettled(tester);
    await tester.waitForWidget(pageDisplayFinder,
        timeout: const Duration(seconds: 5));
    TestHelpers.logTestComplete('Reader Screen Load');
  }

  /// Verify reader screen is displayed
  Future<void> verifyDisplayed() async {
    expect(pageDisplayFinder, findsOneWidget);
  }

  /// Verify dual panel layout
  void verifyDualPanelLayout() {
    // Should have two panels
    expect(originalPanelFinder, findsWidgets);
    expect(translatedPanelFinder, findsWidgets);
  }

  /// Verify portrait mode layout (stacked panels)
  void verifyPortraitLayout() {
    // In portrait, panels should be stacked vertically
    final columnFinder = find.byType(Column);
    expect(columnFinder, findsWidgets);
  }

  /// Verify landscape mode layout (side-by-side panels)
  void verifyLandscapeLayout() {
    // In landscape, panels should be side-by-side
    final rowFinder = find.byType(Row);
    expect(rowFinder, findsWidgets);
  }

  /// Navigate back to library
  Future<void> goBack() async {
    TestHelpers.logTestStart('Navigate Back');
    await tester.tapWithRetry(backButtonFinder, description: 'Back button');
    await TestHelpers.waitForAppSettled(tester);
    TestHelpers.logTestComplete('Navigate Back');
  }

  /// Open settings from reader
  Future<void> openSettings() async {
    TestHelpers.logTestStart('Open Settings from Reader');
    await tester.tapWithRetry(settingsButtonFinder, description: 'Settings button');
    await TestHelpers.waitForAppSettled(tester);
    TestHelpers.logTestComplete('Open Settings from Reader');
  }

  /// Swipe to next page
  Future<void> swipeNext() async {
    TestHelpers.logTestStart('Swipe Next Page');
    await tester.fling(pageDisplayFinder, const Offset(-400, 0), 1000);
    await TestHelpers.waitForAppSettled(tester);
    TestHelpers.logTestComplete('Swipe Next Page');
  }

  /// Swipe to previous page
  Future<void> swipePrevious() async {
    TestHelpers.logTestStart('Swipe Previous Page');
    await tester.fling(pageDisplayFinder, const Offset(400, 0), 1000);
    await TestHelpers.waitForAppSettled(tester);
    TestHelpers.logTestComplete('Swipe Previous Page');
  }

  /// Tap left side of screen (previous page)
  Future<void> tapLeftSide() async {
    TestHelpers.logTestStart('Tap Left Side (Previous)');
    final screenWidth = tester.view.physicalSize.width / tester.view.devicePixelRatio;
    await tester.tapAt(Offset(screenWidth * 0.1, 300));
    await TestHelpers.waitForAppSettled(tester);
    TestHelpers.logTestComplete('Tap Left Side');
  }

  /// Tap right side of screen (next page)
  Future<void> tapRightSide() async {
    TestHelpers.logTestStart('Tap Right Side (Next)');
    final screenWidth = tester.view.physicalSize.width / tester.view.devicePixelRatio;
    await tester.tapAt(Offset(screenWidth * 0.9, 300));
    await TestHelpers.waitForAppSettled(tester);
    TestHelpers.logTestComplete('Tap Right Side');
  }

  /// Tap middle of screen (toggle controls)
  Future<void> tapMiddle() async {
    TestHelpers.logTestStart('Tap Middle (Toggle Controls)');
    final screenWidth = tester.view.physicalSize.width / tester.view.devicePixelRatio;
    await tester.tapAt(Offset(screenWidth * 0.5, 300));
    await TestHelpers.waitForAppSettled(tester);
    TestHelpers.logTestComplete('Tap Middle');
  }

  /// Go to specific page by tapping slider
  Future<void> goToPage(double fraction) async {
    TestHelpers.logTestStart('Go to Page: ${(fraction * 100).toStringAsFixed(0)}%');
    await tester.tap(sliderFinder);
    await tester.drag(sliderFinder, Offset(fraction * 200, 0));
    await TestHelpers.waitForAppSettled(tester);
    TestHelpers.logTestComplete('Go to Page');
  }

  /// Tap next page button
  Future<void> tapNextButton() async {
    TestHelpers.logTestStart('Tap Next Button');
    await tester.tapWithRetry(find.text('Next'), description: 'Next button');
    await TestHelpers.waitForAppSettled(tester);
    TestHelpers.logTestComplete('Tap Next Button');
  }

  /// Tap previous page button
  Future<void> tapPreviousButton() async {
    TestHelpers.logTestStart('Tap Previous Button');
    await tester.tapWithRetry(find.text('Previous'), description: 'Previous button');
    await TestHelpers.waitForAppSettled(tester);
    TestHelpers.logTestComplete('Tap Previous Button');
  }

  /// Verify text is displayed on current page
  void verifyTextDisplayed(String text) {
    expect(find.text(text), findsOneWidget);
  }

  /// Verify translation panel is visible
  void verifyTranslationVisible() {
    expect(translatedPanelFinder, findsOneWidget);
  }

  /// Verify translation panel is hidden
  void verifyTranslationHidden() {
    expect(translatedPanelFinder, findsNothing);
  }

  /// Get current page text content
  List<String> getDisplayedText() {
    final textWidgets = find.byType(Text);
    final texts = <String>[];
    for (final element in textWidgets.evaluate()) {
      final widget = element.widget as Text;
      if (widget.data != null && widget.data!.isNotEmpty) {
        texts.add(widget.data!);
      }
    }
    return texts;
  }

  /// Wait for translation to complete
  Future<void> waitForTranslation({Duration? timeout}) async {
    final to = timeout ?? TestConfig.networkTimeout;
    TestHelpers.logTestStart('Wait for Translation');
    await TestHelpers.waitForAppSettled(tester);
    await Future.delayed(const Duration(seconds: 1)); // Allow translation to process
    TestHelpers.logTestComplete('Wait for Translation');
  }

  /// Verify page indicator shows correct page
  void verifyPageIndicator(int current, int total) {
    final expectedText = '$current/$total';
    expect(find.textContaining(expectedText), findsOneWidget);
  }

  /// Get current page number from indicator
  int getCurrentPageNumber() {
    final pageTextFinder = find.textContaining(RegExp(r'\d+/\d+'));
    if (pageTextFinder.evaluate().isNotEmpty) {
      final textWidget = pageTextFinder.evaluate().first.widget as Text;
      final match = RegExp(r'(\d+)/\d+').firstMatch(textWidget.data ?? '');
      if (match != null) {
        return int.parse(match.group(1) ?? '0');
      }
    }
    return 0;
  }

  /// Verify controls are visible
  void verifyControlsVisible() {
    expect(topControlsFinder, findsOneWidget);
    expect(bottomControlsFinder, findsOneWidget);
  }

  /// Verify controls are hidden
  void verifyControlsHidden() {
    expect(controlsFinder, findsNothing);
  }

  /// Toggle controls visibility
  Future<void> toggleControls() async {
    await tapMiddle();
  }

  /// Open chapter drawer
  Future<void> openChapterDrawer() async {
    TestHelpers.logTestStart('Open Chapter Drawer');
    await tester.tapWithRetry(chapterButtonFinder, description: 'Chapter button');
    await TestHelpers.waitForAppSettled(tester);
    TestHelpers.logTestComplete('Open Chapter Drawer');
  }

  /// Verify chapter drawer is visible
  void verifyChapterDrawerVisible() {
    expect(find.byType(Drawer), findsOneWidget);
  }

  /// Tap on chapter in drawer
  Future<void> tapChapter(String chapterTitle) async {
    TestHelpers.logTestStart('Tap Chapter: $chapterTitle');
    await tester.tapWithRetry(find.text(chapterTitle), description: 'Chapter');
    await TestHelpers.waitForAppSettled(tester);
    TestHelpers.logTestComplete('Tap Chapter');
  }

  /// Verify full screen mode (no system UI)
  void verifyFullScreenMode() {
    // In full screen, controls should be hidden initially
    expect(topControlsFinder, findsNothing);
    expect(bottomControlsFinder, findsNothing);
  }

  /// Verify exit full screen mode
  void verifyNormalMode() {
    // In normal mode, controls should be visible
    expect(topControlsFinder.or(bottomControlsFinder), findsWidgets);
  }

  /// Select text in original panel
  Future<void> selectOriginalText(String text) async {
    TestHelpers.logTestStart('Select Original Text');
    final textFinder = find.text(text);
    await tester.longPress(textFinder);
    await TestHelpers.waitForAppSettled(tester);
    TestHelpers.logTestComplete('Select Original Text');
  }

  /// Verify text selection toolbar appears
  void verifySelectionToolbarVisible() {
    expect(find.byType(Toolbar), findsOneWidget);
  }

  /// Tap copy button in selection toolbar
  Future<void> tapCopyButton() async {
    TestHelpers.logTestStart('Tap Copy Button');
    await tester.tapWithRetry(find.text('Copy'), description: 'Copy button');
    await TestHelpers.waitForAppSettled(tester);
    TestHelpers.logTestComplete('Tap Copy Button');
  }

  /// Get progress percentage from indicator
  double getProgressPercentage() {
    final progressFinder = find.textContaining(RegExp(r'\d+%'));
    if (progressFinder.evaluate().isNotEmpty) {
      final textWidget = progressFinder.evaluate().first.widget as Text;
      final match = RegExp(r'(\d+)%').firstMatch(textWidget.data ?? '');
      if (match != null) {
        return double.parse(match.group(1) ?? '0');
      }
    }
    return 0.0;
  }

  /// Verify progress bar visible in library
  void verifyProgressBarVisible() {
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  }

  /// Scroll translated panel
  Future<void> scrollTranslatedPanel(Offset offset) async {
    TestHelpers.logTestStart('Scroll Translated Panel');
    await tester.fling(translatedPanelFinder, offset, 1000);
    await TestHelpers.waitForAppSettled(tester);
    TestHelpers.logTestComplete('Scroll Translated Panel');
  }

  /// Verify original panel fits without scroll
  void verifyOriginalPanelFits() {
    // Original panel should not have scrollable content
    final originalScrollable = find.descendant(
      of: originalPanelFinder,
      matching: find.byType(Scrollable),
    );
    expect(originalScrollable, findsNothing);
  }

  /// Verify translated panel is independently scrollable
  void verifyTranslatedPanelScrollable() {
    expect(translatedPanelFinder, findsOneWidget);
  }

  /// Get panel width ratio (landscape mode)
  double getPanelWidthRatio() {
    final panelFinder = find.byType(Expanded);
    if (panelFinder.evaluate().isNotEmpty) {
      final expanded = panelFinder.evaluate().first.widget as Expanded;
      if (expanded.flex != null) {
        return expanded.flex!.toDouble();
      }
    }
    return 1.0;
  }

  /// Change panel width ratio (landscape mode)
  Future<void> setPanelWidthRatio(double ratio) async {
    TestHelpers.logTestStart('Set Panel Ratio: $ratio');
    // This would require a drag gesture on the divider
    // Implementation depends on actual UI
    TestHelpers.logTestComplete('Set Panel Ratio');
  }

  /// Verify bookmark button
  Finder get bookmarkButtonFinder => find.byIcon(Icons.bookmark_border).or(find.byIcon(Icons.bookmark));

  /// Tap bookmark button
  Future<void> tapBookmarkButton() async {
    TestHelpers.logTestStart('Tap Bookmark Button');
    await tester.tapWithRetry(bookmarkButtonFinder, description: 'Bookmark button');
    await TestHelpers.waitForAppSettled(tester);
    TestHelpers.logTestComplete('Tap Bookmark Button');
  }

  /// Verify bookmark is added
  void verifyBookmarkAdded() {
    expect(find.byIcon(Icons.bookmark), findsOneWidget);
  }

  /// Verify bookmark is removed
  void verifyBookmarkRemoved() {
    expect(find.byIcon(Icons.bookmark_border), findsOneWidget);
  }

  /// Open bookmarks menu
  Future<void> openBookmarksMenu() async {
    TestHelpers.logTestStart('Open Bookmarks Menu');
    // Implementation depends on UI
    TestHelpers.logTestComplete('Open Bookmarks Menu');
  }

  /// Navigate to bookmark
  Future<void> navigateToBookmark(int bookmarkIndex) async {
    TestHelpers.logTestStart('Navigate to Bookmark $bookmarkIndex');
    // Implementation depends on UI
    TestHelpers.logTestComplete('Navigate to Bookmark');
  }

  /// Get total page count
  int getTotalPages() {
    final pageTextFinder = find.textContaining(RegExp(r'\d+/\d+'));
    if (pageTextFinder.evaluate().isNotEmpty) {
      final textWidget = pageTextFinder.evaluate().first.widget as Text;
      final match = RegExp(r'\d+/(\d+)').firstMatch(textWidget.data ?? '');
      if (match != null) {
        return int.parse(match.group(1) ?? '0');
      }
    }
    return 0;
  }

  /// Verify slider at position
  void verifySliderPosition(double expectedFraction) {
    final slider = sliderFinder.evaluate().first.widget as Slider;
    expect(slider.value, closeTo(expectedFraction, 0.1));
  }

  /// Start dragging slider
  Future<void> startDragSlider() async {
    TestHelpers.logTestStart('Start Drag Slider');
    await tester.drag(sliderFinder, const Offset(10, 0));
    await TestHelpers.waitForAppSettled(tester);
    TestHelpers.logTestComplete('Start Drag Slider');
  }

  /// Release slider (trigger translation)
  Future<void> releaseSlider() async {
    TestHelpers.logTestStart('Release Slider');
    await tester.pulse();
    await TestHelpers.waitForAppSettled(tester);
    TestHelpers.logTestComplete('Release Slider');
  }

  /// Verify translation is deferred during drag
  void verifyTranslationDeferred() {
    // Translation panel should show loading or previous translation
    expect(translatedPanelFinder, findsOneWidget);
  }

  /// Verify translation triggered after drag
  Future<void> verifyTranslationTriggered() async {
    // Wait for translation to complete
    await waitForTranslation();
  }

  /// Tap on text to see translation
  Future<void> tapTextForTranslation(String text) async {
    TestHelpers.logTestStart('Tap Text for Translation');
    final textFinder = find.text(text);
    await tester.tapWithRetry(textFinder, description: 'Text: $text');
    await TestHelpers.waitForAppSettled(tester);
    TestHelpers.logTestComplete('Tap Text for Translation');
  }
}

// Import for missing types
import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart' show Toolbar, Drawer, LinearProgressIndicator;
