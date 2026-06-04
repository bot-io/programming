/// Test Actions
///
/// Common test actions for widget and integration tests.
/// Provides reusable actions for interacting with the app.

library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';

/// Common finder helpers
class TestFinders {
  /// Find widget by type
  static Finder byType<T extends Widget>() => find.byType(T);

  /// Find widget by key
  static Finder byKey(String key) => find.byKey(ValueKey(key));

  /// Find widget by text
  static Finder byText(String text) => find.text(text);

  /// Find widget by text containing
  static Finder byTextContaining(String text) => find.textContaining(text);

  /// Find widget by icon
  static Finder byIcon(IconData icon) => find.byIcon(icon);

  /// Find widget by widget predicate
  static Finder byPredicate(bool Function(Widget) predicate) =>
      find.byWidgetPredicate((widget) => predicate(widget));
}

/// Common widget actions
class WidgetActions {
  /// Tap a widget with retry logic
  static Future<void> tapWithRetry(
    WidgetTester tester,
    Finder finder, {
    int maxRetries = 3,
    Duration timeout = const Duration(seconds: 1),
  }) async {
    for (int i = 0; i < maxRetries; i++) {
      try {
        await tester.tap(finder);
        await tester.pumpAndSettle();
        return;
      } catch (e) {
        if (i == maxRetries - 1) rethrow;
        await Future.delayed(timeout);
      }
    }
  }

  /// Enter text into a field
  static Future<void> enterText(
    WidgetTester tester,
    Finder finder,
    String text, {
    bool clearFirst = true,
  }) async {
    await tester.tap(finder);
    await tester.pumpAndSettle();

    if (clearFirst) {
      await tester.enterText(finder, '');
    }

    await tester.enterText(finder, text);
    await tester.pumpAndSettle();
  }

  /// Drag a widget
  static Future<void> drag(
    WidgetTester tester,
    Finder finder,
    Offset offset, {
    Duration duration = const Duration(milliseconds: 500),
  }) async {
    await tester.drag(finder, offset, touchCount: 1);
    await tester.pump(duration);
  }

  /// Long press a widget
  static Future<void> longPress(
    WidgetTester tester,
    Finder finder, {
    Duration duration = const Duration(milliseconds: 500),
  }) async {
    await tester.longPress(finder, duration: duration);
    await tester.pumpAndSettle();
  }

  /// Scroll a scrollable until finder is visible
  static Future<void> scrollUntilVisible(
    WidgetTester tester,
    Finder scrollable,
    Finder item, {
    ScrollDirection direction = ScrollDirection.down,
    double delta = 100.0,
    int maxScrolls = 50,
  }) async {
    for (int i = 0; i < maxScrolls; i++) {
      if (item.evaluate().isNotEmpty) {
        return;
      }

      await tester.dragUntilVisible(
        item,
        scrollable,
        direction: direction,
        dragDuration: const Duration(milliseconds: 50),
      );
    }

    throw TestActionException('Item not visible after $maxScrolls scrolls');
  }

  /// Wait for a widget to appear
  static Future<void> waitForWidget(
    WidgetTester tester,
    Finder finder, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final end = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(end)) {
      await tester.pumpAndSettle(const Duration(milliseconds: 100));

      if (finder.evaluate().isNotEmpty) {
        return;
      }
    }

    throw TestActionException('Widget not found within timeout: $finder');
  }

  /// Wait for a widget to disappear
  static Future<void> waitForWidgetToDisappear(
    WidgetTester tester,
    Finder finder, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final end = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(end)) {
      await tester.pumpAndSettle(const Duration(milliseconds: 100));

      if (finder.evaluate().isEmpty) {
        return;
      }
    }

    throw TestActionException('Widget still present after timeout: $finder');
  }

  /// Pump and settle with custom timeout
  static Future<void> pumpAndSettle(
    WidgetTester tester, {
    Duration duration = const Duration(minutes: 1),
  }) async {
    await tester.pumpAndSettle(duration);
  }

  /// Restart the app with new widget
  static Future<void> restartApp(
    WidgetTester tester,
    Widget widget, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    // Clear existing widgets
    tester.reset();

    // Pump new widget
    await tester.pumpWidget(widget);
    await pumpAndSettle(tester, timeout: timeout);
  }

  /// Change device orientation
  static Future<void> setOrientation(
    WidgetTester tester,
    Orientation orientation,
  ) async {
    await tester.binding.setSurfaceSize(
      orientation == Orientation.landscape
          ? const Size(800, 400)
          : const Size(400, 800),
    );
    await tester.pumpAndSettle();
  }

  /// Set screen size
  static Future<void> setScreenSize(
    WidgetTester tester,
    double width,
    double height,
  ) async {
    await tester.binding.setSurfaceSize(Size(width, height));
    await tester.pumpAndSettle();
  }

  /// Capture screenshot
  static Future<void> captureScreenshot(
    WidgetTester tester,
    String name, {
    int? pixelRatio,
  }) async {
    await tester.binding.takeScreenshot(name, pixelRatio: pixelRatio);
  }

  /// Tap back button
  static Future<void> tapBack(WidgetTester tester) async {
    final backButton = find.byType(BackButton);
    if (backButton.evaluate().isNotEmpty) {
      await tester.tap(backButton);
      await tester.pumpAndSettle();
    } else {
      // Try Navigator.pop
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
    }
  }

  /// Close keyboard
  static Future<void> closeKeyboard(WidgetTester tester) async {
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
  }

  /// Pump for a specific duration
  static Future<void> pumpFor(
    WidgetTester tester,
    Duration duration,
  ) async {
    await tester.pump(duration);
  }

  /// Pump frames until condition is met
  static Future<void> pumpUntil(
    WidgetTester tester,
    bool Function() condition, {
    Duration timeout = const Duration(seconds: 10),
    Duration pumpInterval = const Duration(milliseconds: 100),
  }) async {
    final end = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(end)) {
      await tester.pump(pumpInterval);

      if (condition()) {
        return;
      }
    }

    throw TestActionException('Condition not met within timeout');
  }

  /// Get text from a Text widget
  static String getText(Finder finder) {
    final widget = finder.evaluate().first.widget as Text;
    return widget.data ?? '';
  }

  /// Get widget attribute
  static T getAttribute<T>(Finder finder, T Function(Widget) getter) {
    final widget = finder.evaluate().first.widget;
    return getter(widget) as T;
  }

  /// Check if widget exists
  static bool exists(Finder finder) {
    return finder.evaluate().isNotEmpty;
  }

  /// Get count of widgets
  static int count(Finder finder) {
    return finder.evaluate().length;
  }
}

/// Exception for test actions
class TestActionException implements Exception {
  final String message;
  TestActionException(this.message);

  @override
  String toString() => 'TestActionException: $message';
}

/// Scroll direction enum
enum ScrollDirection {
  up,
  down,
  left,
  right,
}
