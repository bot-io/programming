/// Test Assertions
///
/// Common assertion helpers for widget and integration tests.
/// Provides readable assertions for common test scenarios.

library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';

/// Common widget assertions
class TestAssertions {
  /// Assert a widget exists
  static void exists(
    Finder finder, {
    String? reason,
  }) {
    expect(
      finder.evaluate().isNotEmpty,
      isTrue,
      reason: reason ?? 'Widget should exist: $finder',
    );
  }

  /// Assert a widget does not exist
  static void notExists(
    Finder finder, {
    String? reason,
  }) {
    expect(
      finder.evaluate().isEmpty,
      isTrue,
      reason: reason ?? 'Widget should not exist: $finder',
    );
  }

  /// Assert exactly one widget exists
  static void existsOnce(
    Finder finder, {
    String? reason,
  }) {
    expect(
      finder.evaluate().length,
      equals(1),
      reason: reason ?? 'Exactly one widget should exist: $finder',
    );
  }

  /// Assert N widgets exist
  static void existsCount(
    Finder finder,
    int count, {
    String? reason,
  }) {
    expect(
      finder.evaluate().length,
      equals(count),
      reason: reason ?? 'Expected $count widgets: $finder',
    );
  }

  /// Assert a text widget displays specific text
  static void textEquals(
    Finder finder,
    String expected, {
    String? reason,
  }) {
    final textWidget = finder.evaluate().first.widget as Text;
    expect(
      textWidget.data,
      equals(expected),
      reason: reason ?? 'Text should be "$expected"',
    );
  }

  /// Assert text contains substring
  static void textContains(
    Finder finder,
    String substring, {
    String? reason,
  }) {
    final textWidget = finder.evaluate().first.widget as Text;
    expect(
      textWidget.data,
      contains(substring),
      reason: reason ?? 'Text should contain "$substring"',
    );
  }

  /// Assert widget is visible
  static void isVisible(
    Finder finder, {
    String? reason,
  }) {
    final widget = finder.evaluate().first.widget;
    final opacity = (widget as Opacity)?.opacity ?? 1.0;
    final offstage = (widget as Offstage)?.offstage ?? false;

    expect(
      opacity > 0 && !offstage,
      isTrue,
      reason: reason ?? 'Widget should be visible: $finder',
    );
  }

  /// Assert widget is enabled
  static void isEnabled(
    Finder finder, {
    String? reason,
  }) {
    final widget = finder.evaluate().first.widget;

    if (widget is IgnorePointer || widget is AbsorbPointer) {
      fail(reason ?? 'Widget should be enabled: $finder');
    }
  }

  /// Assert widget is disabled
  static void isDisabled(
    Finder finder, {
    String? reason,
  }) {
    final widget = finder.evaluate().first.widget;

    if (widget is! IgnorePointer && widget is! AbsorbPointer) {
      fail(reason ?? 'Widget should be disabled: $finder');
    }
  }

  /// Assert a Slider has a specific value
  static void sliderValue(
    Finder finder,
    double expected, {
    double tolerance = 0.01,
    String? reason,
  }) {
    final slider = finder.evaluate().first.widget as Slider;
    expect(
      slider.value,
      closeTo(expected, tolerance),
      reason: reason ?? 'Slider value should be $expected',
    );
  }

  /// Assert a DropdownButton has a specific value
  static void dropdownValue<T>(
    Finder finder,
    T expected, {
    String? reason,
  }) {
    final dropdown = finder.evaluate().first.widget as DropdownButton<T>;
    expect(
      dropdown.value,
      equals(expected),
      reason: reason ?? 'Dropdown value should be $expected',
    );
  }

  /// Assert a Switch is on/off
  static void switchState(
    Finder finder,
    bool isOn, {
    String? reason,
  }) {
    final switchWidget = finder.evaluate().first.widget as Switch;
    expect(
      switchWidget.value,
      equals(isOn),
      reason: reason ?? 'Switch should be ${isOn ? "on" : "off"}',
    );
  }

  /// Assert a TextField has specific text
  static void textFieldText(
    Finder finder,
    String expected, {
    String? reason,
  }) {
    final textField = finder.evaluate().first.widget as TextField;
    expect(
      textField.controller?.text,
      equals(expected),
      reason: reason ?? 'TextField should contain "$expected"',
    );
  }

  /// Assert an image is displayed
  static void imageDisplayed(
    Finder finder, {
    String? reason,
  }) {
    final image = finder.evaluate().first.widget as Image;
    expect(
      image.image,
      isNotNull,
      reason: reason ?? 'Image should be displayed',
    );
  }

  /// Assert a ListView has specific number of items
  static void listItemCount(
    Finder finder, {
    required int expected,
    String? reason,
  }) {
    final listView = finder.evaluate().first.widget as ListView;
    // This requires access to the sliver child delegate
    // In practice, we'd check the actual rendered items
    final itemCount = find.byType(ListTile).evaluate().length;
    expect(
      itemCount,
      equals(expected),
      reason: reason ?? 'ListView should have $expected items',
    );
  }

  /// Assert scrollable is at top
  static void isAtTop(
    Finder scrollable, {
    String? reason,
  }) {
    final scrollView = scrollable.evaluate().first.widget as Scrollable;
    final controller = scrollView.controller;
    expect(
      controller.hasClients,
      isTrue,
      reason: 'Scrollable should be attached',
    );
    expect(
      controller.position.pixels,
      equals(0.0),
      reason: reason ?? 'Scrollable should be at top',
    );
  }

  /// Assert scrollable is at bottom
  static void isAtBottom(
    Finder scrollable, {
    String? reason,
  }) {
    final scrollView = scrollable.evaluate().first.widget as Scrollable;
    final controller = scrollView.controller;
    expect(
      controller.hasClients,
      isTrue,
      reason: 'Scrollable should be attached',
    );

    final maxExtent = controller.position.maxScrollExtent;
    final current = controller.position.pixels;

    expect(
      current >= maxExtent - 1.0, // Allow for rounding
      isTrue,
      reason: reason ?? 'Scrollable should be at bottom',
    );
  }

  /// Assert app is in specific theme mode
  static void themeMode(
    WidgetTester tester,
    ThemeMode expected, {
    String? reason,
  }) {
    final theme = Theme.of(tester.element(find.byType(MaterialApp).evaluate().first));
    expect(
      theme.brightness == Brightness.dark && expected == ThemeMode.dark ||
          theme.brightness == Brightness.light && expected == ThemeMode.light,
      isTrue,
      reason: reason ?? 'App should be in ${expected} mode',
    );
  }

  /// Assert progress indicator is shown
  static void progressIndicatorShown({
    String? reason,
  }) {
    exists(find.byType(LinearProgressIndicator), reason: reason);
    exists(find.byType(CircularProgressIndicator), reason: reason);
  }

  /// Assert progress indicator is hidden
  static void progressIndicatorHidden({
    String? reason,
  }) {
    notExists(find.byType(LinearProgressIndicator), reason: reason);
    notExists(find.byType(CircularProgressIndicator), reason: reason);
  }

  /// Assert dialog is shown
  static void dialogShown({
    String? reason,
  }) {
    exists(find.byType(Dialog), reason: reason);
  }

  /// Assert dialog is hidden
  static void dialogHidden({
    String? reason,
  }) {
    notExists(find.byType(Dialog), reason: reason);
  }

  /// Assert snackbar is shown
  static void snackBarShown({
    String? message,
    String? reason,
  }) {
    final snackbar = find.byType(SnackBar);
    exists(snackbar, reason: reason);

    if (message != null) {
      final content = find.descendant(
        of: snackbar,
        matching: find.text(message),
      );
      exists(content, reason: reason);
    }
  }

  /// Assert error message is shown
  static void errorMessageShown({
    String? message,
    String? reason,
  }) {
    if (message != null) {
      exists(find.text(message), reason: reason);
    } else {
      // Look for common error indicators
      final errorIndicators = [
        find.textContaining('error', includeNull: true),
        find.textContaining('failed', includeNull: true),
        find.textContaining('could not', includeNull: true),
      ];
      final hasError = errorIndicators.any((finder) => finder.evaluate().isNotEmpty);
      expect(
        hasError,
        isTrue,
        reason: reason ?? 'Error message should be shown',
      );
    }
  }

  /// Assert sheet/bottom sheet is shown
  static void bottomSheetShown({
    String? reason,
  }) {
    exists(find.byType(BottomSheet), reason: reason);
  }

  /// Assert modal barrier is shown
  static void modalBarrierShown({
    String? reason,
  }) {
    exists(find.byType(ModalBarrier), reason: reason);
  }

  /// Assert text field has focus
  static void hasFocus(
    Finder finder, {
    String? reason,
  }) {
    final focusNode = (finder.evaluate().first.widget as FocusableWidget).focusNode;
    expect(
      focusNode?.hasFocus,
      isTrue,
      reason: reason ?? 'Widget should have focus: $finder',
    );
  }

  /// Assert widget has specific size
  static void hasSize(
    Finder finder,
    Size expected, {
    double tolerance = 1.0,
    String? reason,
  }) {
    final size = tester.getSize(finder);
    expect(
      size.width,
      closeTo(expected.width, tolerance),
      reason: reason ?? 'Width should be ${expected.width}',
    );
    expect(
      size.height,
      closeTo(expected.height, tolerance),
      reason: reason ?? 'Height should be ${expected.height}',
    );
  }

  /// Assert widget contains specific child
  static void containsChild(
    Finder parent,
    Finder child, {
    String? reason,
  }) {
    final descendant = find.descendant(
      of: parent,
      matching: child,
    );
    exists(descendant, reason: reason ?? 'Parent should contain child');
  }
}
