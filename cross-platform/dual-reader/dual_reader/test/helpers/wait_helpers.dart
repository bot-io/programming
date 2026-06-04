/// Wait Helpers
///
/// Async utilities for waiting in tests.
/// Provides predictable waiting for various conditions.

library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';

/// Wait helpers for async operations in tests
class WaitHelpers {
  /// Wait for a condition to be true
  static Future<void> waitFor(
    bool Function() condition, {
    Duration timeout = const Duration(seconds: 10),
    Duration interval = const Duration(milliseconds: 100),
    String? timeoutMessage,
  }) async {
    final end = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(end)) {
      if (condition()) {
        return;
      }
      await Future.delayed(interval);
    }

    throw WaitException(
      timeoutMessage ?? 'Condition not met within ${timeout.inSeconds}s',
    );
  }

  /// Wait for a widget to appear
  static Future<void> waitForWidget(
    WidgetTester tester,
    Finder finder, {
    Duration timeout = const Duration(seconds: 10),
    String? timeoutMessage,
  }) async {
    final end = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(end)) {
      await tester.pumpAndSettle(const Duration(milliseconds: 50));

      if (finder.evaluate().isNotEmpty) {
        return;
      }
    }

    throw WaitException(
      timeoutMessage ?? 'Widget not found within ${timeout.inSeconds}s: $finder',
    );
  }

  /// Wait for a widget to disappear
  static Future<void> waitForWidgetToDisappear(
    WidgetTester tester,
    Finder finder, {
    Duration timeout = const Duration(seconds: 10),
    String? timeoutMessage,
  }) async {
    final end = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(end)) {
      await tester.pumpAndSettle(const Duration(milliseconds: 50));

      if (finder.evaluate().isEmpty) {
        return;
      }
    }

    throw WaitException(
      timeoutMessage ?? 'Widget still present after ${timeout.inSeconds}s: $finder',
    );
  }

  /// Wait for N widgets to appear
  static Future<void> waitForWidgetCount(
    WidgetTester tester,
    Finder finder,
    int count, {
    Duration timeout = const Duration(seconds: 10),
    String? timeoutMessage,
  }) async {
    final end = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(end)) {
      await tester.pumpAndSettle(const Duration(milliseconds: 50));

      if (finder.evaluate().length == count) {
        return;
      }
    }

    throw WaitException(
      timeoutMessage ?? 'Widget count not reached within ${timeout.inSeconds}s: expected $count, got ${finder.evaluate().length}',
    );
  }

  /// Wait for animation to complete
  static Future<void> waitForAnimation(
    WidgetTester tester, {
    Duration timeout = const Duration(seconds: 5),
    String? timeoutMessage,
  }) async {
    final end = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(end)) {
      await tester.pump();

      if (!tester.binding.hasScheduledFrame) {
        // No more frames scheduled
        await tester.pumpAndSettle();
        return;
      }

      await Future.delayed(const Duration(milliseconds: 16));
    }

    // Final pump to settle everything
    await tester.pumpAndSettle();
  }

  /// Wait for async operation to complete
  static Future<void> waitForAsync(
    WidgetTester tester, {
    Duration timeout = const Duration(seconds: 5),
    String? timeoutMessage,
  }) async {
    final end = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(end)) {
      await tester.pump();

      // Check for microtasks
      if (!tester.binding.hasScheduledFrame) {
        // Pump once more to catch any pending microtasks
        await tester.pump();
        return;
      }

      await Future.delayed(const Duration(milliseconds: 50));
    }
  }

  /// Wait for a specific duration
  static Future<void> wait(Duration duration) async {
    await Future.delayed(duration);
  }

  /// Wait for a text widget to show specific text
  static Future<void> waitForText(
    WidgetTester tester,
    String text, {
    Duration timeout = const Duration(seconds: 10),
    String? timeoutMessage,
  }) async {
    final finder = find.text(text);
    await waitForWidget(tester, finder, timeout: timeout);
  }

  /// Wait for a widget to become visible
  static Future<void> waitForVisible(
    WidgetTester tester,
    Finder finder, {
    Duration timeout = const Duration(seconds: 10),
    String? timeoutMessage,
  }) async {
    final end = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(end)) {
      await tester.pumpAndSettle(const Duration(milliseconds: 50));

      if (finder.evaluate().isEmpty) {
        continue;
      }

      final widget = finder.evaluate().first.widget;

      // Check opacity
      if (widget is Opacity && widget.opacity == 0) {
        continue;
      }

      // Check offstage
      if (widget is Offstage && widget.offstage == true) {
        continue;
      }

      return;
    }

    throw WaitException(
      timeoutMessage ?? 'Widget not visible within ${timeout.inSeconds}s: $finder',
    );
  }

  /// Wait for a widget to become invisible
  static Future<void> waitForInvisible(
    WidgetTester tester,
    Finder finder, {
    Duration timeout = const Duration(seconds: 10),
    String? timeoutMessage,
  }) async {
    final end = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(end)) {
      await tester.pumpAndSettle(const Duration(milliseconds: 50));

      if (finder.evaluate().isEmpty) {
        return;
      }

      final widget = finder.evaluate().first.widget;

      bool isInvisible = false;

      if (widget is Opacity && widget.opacity == 0) {
        isInvisible = true;
      } else if (widget is Offstage && widget.offstage == true) {
        isInvisible = true;
      }

      if (isInvisible) {
        return;
      }
    }

    throw WaitException(
      timeoutMessage ?? 'Widget still visible after ${timeout.inSeconds}s: $finder',
    );
  }

  /// Wait for a scrollable to settle
  static Future<void> waitForScrollToSettle(
    WidgetTester tester, {
    Duration timeout = const Duration(seconds: 5),
    String? timeoutMessage,
  }) async {
    final end = DateTime.now().add(timeout);

    double previousPosition = double.infinity;
    int stableFrames = 0;

    while (DateTime.now().isBefore(end)) {
      await tester.pump();

      final scrollables = find.byType(Scrollable).evaluate();
      if (scrollables.isEmpty) {
        return;
      }

      double currentPosition = 0;
      for (final element in scrollables) {
        final scrollable = element.widget as Scrollable;
        final controller = scrollable.controller;
        if (controller.hasClients) {
          currentPosition = controller.position.pixels;
          break;
        }
      }

      if ((currentPosition - previousPosition).abs() < 1.0) {
        stableFrames++;
        if (stableFrames >= 3) {
          return;
        }
      } else {
        stableFrames = 0;
      }

      previousPosition = currentPosition;
      await Future.delayed(const Duration(milliseconds: 50));
    }

    // Not fully settled, but timeout reached
  }

  /// Wait for app to be idle (no scheduled frames)
  static Future<void> waitForIdle(
    WidgetTester tester, {
    Duration timeout = const Duration(seconds: 5),
    String? timeoutMessage,
  }) async {
    final end = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(end)) {
      await tester.pump();

      if (!tester.binding.hasScheduledFrame) {
        // One more pump to catch any pending microtasks
        await tester.pump();
        return;
      }

      await Future.delayed(const Duration(milliseconds: 16));
    }
  }

  /// Wait with retry logic
  static Future<T> waitForRetry<T>({
    required Future<T?> Function() attempt,
    Duration timeout = const Duration(seconds: 5),
    Duration interval = const Duration(milliseconds: 500),
    String? timeoutMessage,
  }) async {
    final end = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(end)) {
      final result = await attempt();
      if (result != null) {
        return result;
      }

      if (DateTime.now().add(interval).isAfter(end)) {
        break;
      }

      await Future.delayed(interval);
    }

    throw WaitException(
      timeoutMessage ?? 'Operation did not complete within ${timeout.inSeconds}s',
    );
  }

  /// Wait for multiple conditions
  static Future<void> waitForAll(
    List<bool Function()> conditions, {
    Duration timeout = const Duration(seconds: 10),
    String? timeoutMessage,
  }) async {
    final end = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(end)) {
      if (conditions.every((condition) => condition())) {
        return;
      }
      await Future.delayed(const Duration(milliseconds: 100));
    }

    throw WaitException(
      timeoutMessage ?? 'Not all conditions met within ${timeout.inSeconds}s',
    );
  }

  /// Wait for any condition to be true
  static Future<void> waitForAny(
    List<bool Function()> conditions, {
    Duration timeout = const Duration(seconds: 10),
    String? timeoutMessage,
  }) async {
    final end = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(end)) {
      if (conditions.any((condition) => condition())) {
        return;
      }
      await Future.delayed(const Duration(milliseconds: 100));
    }

    throw WaitException(
      timeoutMessage ?? 'No condition met within ${timeout.inSeconds}s',
    );
  }

  /// Wait until a specific time of day
  static Future<void> waitUntilTimeOfDay(
    TimeOfDay time, {
    String? timeoutMessage,
  }) async {
    final now = TimeOfDay.now();
    final target = TimeOfDay(hour: time.hour, minute: time.minute);

    Duration difference;
    if (now.hour < target.hour || (now.hour == target.hour && now.minute < target.minute)) {
      // Target is later today
      difference = Duration(
        hours: target.hour - now.hour - 1,
        minutes: 60 - now.minute + target.minute,
      );
    } else {
      // Target is tomorrow
      difference = Duration(
        hours: 24 - now.hour + target.hour - 1,
        minutes: 60 - now.minute + target.minute,
      );
    }

    await Future.delayed(difference);
  }
}

/// Exception for wait operations
class WaitException implements Exception {
  final String message;
  WaitException(this.message);

  @override
  String toString() => 'WaitException: $message';
}

/// Time of day for scheduling
class TimeOfDay {
  final int hour;
  final int minute;

  const TimeOfDay({required this.hour, required this.minute});

  /// Get current time
  static TimeOfDay now() {
    final now = DateTime.now();
    return TimeOfDay(hour: now.hour, minute: now.minute);
  }
}
