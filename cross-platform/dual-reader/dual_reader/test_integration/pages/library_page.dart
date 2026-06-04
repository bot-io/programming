/// Page object for Library screen
///
/// Implements the Page Object pattern for Library screen E2E tests.

library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import '../config/test_config.dart';
import '../helpers/test_helpers.dart';

/// Page object for Library screen interactions
class LibraryPage {
  final WidgetTester tester;

  LibraryPage(this.tester);

  /// Expected UI elements on the library screen
  static const String libraryTitle = 'Your Library';
  static const String emptyLibraryMessage = 'No books imported yet';
  static const String importSuccessMessage = 'Book imported successfully';
  static const String deleteDialogTitle = 'Delete Book';
  static const String settingsButtonTooltip = 'Settings';

  /// Key finders for library elements
  Finder get libraryTitleFinder => find.text(libraryTitle);
  Finder get importButtonFinder => find.byWidgetPredicate(
        (widget) =>
            widget is IconButton &&
            widget.icon is Icon &&
            (widget.icon as Icon).icon == Icons.add_box_outlined,
      );
  Finder get settingsButtonFinder => find.byWidgetPredicate(
        (widget) =>
            widget is IconButton &&
            widget.tooltip == settingsButtonTooltip,
      );
  Finder get bookGridFinder => find.byType(GridView);
  Finder get emptyLibraryFinder => find.textContaining(emptyLibraryMessage);
  Finder get bookCardFinder => find.byType(Card);
  Finder get snackBarFinder => find.byType(SnackBar);

  /// Model download UI elements
  Finder get downloadProgressBannerFinder => find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.child != null &&
            widget.decoration != null &&
            widget.decoration is BoxDecoration,
      );

  /// Wait for library screen to load
  Future<void> waitForLoad() async {
    TestHelpers.logTestStart('Library Screen Load');
    await TestHelpers.waitForAppSettled(tester);
    await tester.waitForWidget(libraryTitleFinder);
    TestHelpers.logTestComplete('Library Screen Load');
  }

  /// Verify library screen is displayed
  Future<void> verifyDisplayed() async {
    expect(libraryTitleFinder, findsOneWidget);
    expect(importButtonFinder, findsOneWidget);
    expect(settingsButtonFinder, findsOneWidget);
  }

  /// Verify empty library state
  Future<void> verifyEmpty() async {
    expect(emptyLibraryFinder, findsOneWidget);
    expect(bookGridFinder, findsNothing);
  }

  /// Verify books are displayed in grid
  Future<void> verifyBooksDisplayed({int expectedCount = 1}) async {
    await TestHelpers.waitForAppSettled(tester);
    expect(bookGridFinder, findsOneWidget);
    expect(emptyLibraryFinder, findsNothing);
    final cards = bookCardFinder.evaluate();
    expect(cards.length, greaterThanOrEqualTo(expectedCount),
        reason: 'Expected at least $expectedCount book cards, found ${cards.length}');
  }

  /// Tap import button
  Future<void> tapImport() async {
    TestHelpers.logTestStart('Tap Import Button');
    await tester.tapWithRetry(importButtonFinder, description: 'Import button');
    await TestHelpers.waitForAppSettled(tester);
    TestHelpers.logTestComplete('Tap Import Button');
  }

  /// Tap settings button
  Future<void> tapSettings() async {
    TestHelpers.logTestStart('Tap Settings Button');
    await tester.tapWithRetry(settingsButtonFinder, description: 'Settings button');
    await TestHelpers.waitForAppSettled(tester);
    TestHelpers.logTestComplete('Tap Settings Button');
  }

  /// Get count of displayed books
  int getBookCount() {
    final cards = bookCardFinder.evaluate();
    return cards.length;
  }

  /// Tap on book by title
  Future<void> openBook(String title) async {
    TestHelpers.logTestStart('Open Book: $title');
    final bookFinder = find.text(title);
    await tester.waitForWidget(bookFinder);
    await tester.tapWithRetry(bookFinder, description: 'Book: $title');
    await TestHelpers.waitForAppSettled(tester);
    TestHelpers.logTestComplete('Open Book: $title');
  }

  /// Long press on book for delete dialog
  Future<void> longPressBook(String title) async {
    TestHelpers.logTestStart('Long Press Book: $title');
    final bookFinder = find.text(title);
    await tester.longPress(bookFinder);
    await TestHelpers.waitForAppSettled(tester);
    TestHelpers.logTestComplete('Long Press Book: $title');
  }

  /// Verify delete dialog is shown
  void verifyDeleteDialogShown(String bookTitle) {
    expect(find.text(deleteDialogTitle), findsOneWidget);
    expect(find.textContaining('delete "$bookTitle"'), findsOneWidget);
  }

  /// Confirm delete in dialog
  Future<void> confirmDelete() async {
    TestHelpers.logTestStart('Confirm Delete');
    final deleteButton = find.text('Delete');
    await tester.tapWithRetry(deleteButton, description: 'Delete button');
    await TestHelpers.waitForAppSettled(tester);
    TestHelpers.logTestComplete('Confirm Delete');
  }

  /// Cancel delete in dialog
  Future<void> cancelDelete() async {
    TestHelpers.logTestStart('Cancel Delete');
    final cancelButton = find.text('Cancel');
    await tester.tapWithRetry(cancelButton, description: 'Cancel button');
    await TestHelpers.waitForAppSettled(tester);
    TestHelpers.logTestComplete('Cancel Delete');
  }

  /// Verify book is visible in grid
  void verifyBookVisible(String title) {
    expect(find.text(title), findsOneWidget);
  }

  /// Verify book is not visible in grid
  void verifyBookNotVisible(String title) {
    expect(find.text(title), findsNothing);
  }

  /// Verify import success message
  void verifyImportSuccess() {
    expect(find.text(importSuccessMessage), findsOneWidget);
  }

  /// Get all visible book titles
  List<String> getVisibleBookTitles() {
    final textWidgets = find.byType(Text);
    final titles = <String>[];
    for (final element in textWidgets.evaluate()) {
      final widget = element.widget as Text;
      if (widget.data != null && widget.data!.isNotEmpty) {
        // Only get book titles (not author names or other text)
        if (widget.style != null &&
            widget.style!.fontWeight == FontWeight.bold) {
          titles.add(widget.data!);
        }
      }
    }
    return titles;
  }

  /// Get book card by title
  Finder getBookCard(String title) {
    return find.ancestor(
      of: find.text(title),
      matching: bookCardFinder,
    );
  }

  /// Verify book cover is displayed
  void verifyBookCoverDisplayed(String title) {
    final bookCard = getBookCard(title);
    expect(
      find.descendant(
        of: bookCard,
        matching: find.byType(Image),
      ),
      findsOneWidget,
    );
  }

  /// Verify book placeholder is displayed (no cover)
  void verifyBookPlaceholderDisplayed(String title) {
    final bookCard = getBookCard(title);
    expect(
      find.descendant(
        of: bookCard,
        matching: find.byIcon(Icons.book),
      ),
      findsOneWidget,
    );
  }

  /// Verify pagination progress is displayed
  void verifyPaginationProgress(String bookTitle, String expectedProgress) {
    final bookCard = getBookCard(bookTitle);
    expect(
      find.descendant(
        of: bookCard,
        matching: find.textContaining(expectedProgress),
      ),
      findsOneWidget,
    );
  }

  /// Verify book is grayed out (during pagination)
  void verifyBookGrayedOut(String title) {
    final bookCard = getBookCard(title);
    final card = bookCard.evaluate().first.widget as Card;
    expect(card.color, isNotNull);
  }

  /// Verify total pages displayed for a book
  void verifyTotalPagesDisplayed(String title) {
    final bookCard = getBookCard(title);
    // Look for progress indicator or page count text
    expect(
      find.descendant(
        of: bookCard,
        matching: find.byType(LinearProgressIndicator),
      ).or(
        find.descendant(
          of: bookCard,
          matching: find.textContaining(RegExp(r'\d+/?\d*')),
        ),
      ),
      findsOneWidget,
    );
  }

  /// Verify model download banner is shown
  void verifyModelDownloadBannerShown() {
    expect(find.textContaining('Downloading'), findsOneWidget);
  }

  /// Verify model success banner is shown
  void verifyModelSuccessBannerShown() {
    expect(find.textContaining('model ready'), findsOneWidget);
  }

  /// Dismiss model success banner
  Future<void> dismissModelBanner() async {
    final closeButton = find.byIcon(Icons.close);
    if (closeButton.evaluate().isNotEmpty) {
      await tester.tap(closeButton);
      await TestHelpers.waitForAppSettled(tester);
    }
  }

  /// Verify settings navigation
  Future<void> verifyNavigatedToSettings() async {
    await TestHelpers.waitForAppSettled(tester);
    expect(find.text('Settings'), findsOneWidget);
  }
}
