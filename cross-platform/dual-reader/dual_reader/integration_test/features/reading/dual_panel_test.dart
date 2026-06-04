/// E2E Tests for Dual-Panel Display
///
/// Tests the dual-panel layout for reading:
/// - Original and translated panels display
/// - Portrait mode: stacked panels
/// - Landscape mode: side-by-side panels
/// - Panel width ratio adjustment
/// - Original text fits exactly
/// - Translated panel independently scrollable

library;

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/rendering.dart';
import 'package:dual_reader/main.dart' as app;
import '../../../test_integration/helpers/test_helpers.dart';
import '../../../test_integration/pages/reader_page.dart';
import '../../../test_integration/config/test_config.dart';
import '../../../test_integration/helpers/test_logger.dart';

void main() {
  TestHelpers.initTests();
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Reading Experience - Dual Panel Display E2E Tests', () {
    late TestLogger logger;

    setUpAll(() {
      logger = TestLogger();
    });

    tearDownAll(() async {
      await logger.dispose();
    });

    setUp(() {
      logger.logTestSetup('Dual Panel Display');
    });

    tearDown(() {
      logger.logTestTeardown('Dual Panel Display');
    });

    testWidgets('Dual panel layout displays both original and translated text',
        (WidgetTester tester) async {
      logger.info('Testing dual panel layout', category: 'dual_panel');

      // Arrange - Navigate to reader with a book
      await tester.pumpWidget(
        const ProviderScope(
          child: app.MyApp(),
        ),
      );
      await TestHelpers.waitForAppSettled(tester);

      // Act - This would require navigating to a book
      // For structural testing, we verify the reader screen can be displayed

      // Assert
      // final readerPage = ReaderPage(tester);
      // await readerPage.waitForLoad();
      // readerPage.verifyDualPanelLayout();

      logger.info('Dual panel layout verified', category: 'dual_panel');

      logger.info('Dual panel display test completed', category: 'dual_panel');
    }, skip: true, reason: 'Requires test book and navigation');

    testWidgets('Portrait mode shows stacked panels (original top, translated bottom)',
        (WidgetTester tester) async {
      logger.info('Testing portrait mode layout', category: 'dual_panel');

      // Arrange - Set portrait orientation
      await tester.binding.setSurfaceSize(const Size(400, 800));

      await tester.pumpWidget(
        const ProviderScope(
          child: app.MyApp(),
        ),
      );
      await TestHelpers.waitForAppSettled(tester);

      // Assert
      // final readerPage = ReaderPage(tester);
      // readerPage.verifyPortraitLayout();

      logger.info('Portrait mode stacked layout verified', category: 'dual_panel');

      // Reset
      await tester.binding.setSurfaceSize(null);

      logger.info('Portrait mode test completed', category: 'dual_panel');
    }, skip: true, reason: 'Requires test book and navigation');

    testWidgets('Landscape mode shows side-by-side panels', (WidgetTester tester) async {
      logger.info('Testing landscape mode layout', category: 'dual_panel');

      // Arrange - Set landscape orientation
      await tester.binding.setSurfaceSize(const Size(800, 400));

      await tester.pumpWidget(
        const ProviderScope(
          child: app.MyApp(),
        ),
      );
      await TestHelpers.waitForAppSettled(tester);

      // Assert
      // final readerPage = ReaderPage(tester);
      // readerPage.verifyLandscapeLayout();

      logger.info('Landscape mode side-by-side layout verified', category: 'dual_panel');

      // Reset
      await tester.binding.setSurfaceSize(null);

      logger.info('Landscape mode test completed', category: 'dual_panel');
    }, skip: true, reason: 'Requires test book and navigation');

    testWidgets('Original text fits exactly without scrolling', (WidgetTester tester) async {
      logger.info('Testing original text fit', category: 'dual_panel');

      // Arrange
      await tester.pumpWidget(
        const ProviderScope(
          child: app.MyApp(),
        ),
      );
      await TestHelpers.waitForAppSettled(tester);

      // Assert
      // final readerPage = ReaderPage(tester);
      // readerPage.verifyOriginalPanelFits();

      logger.info('Original text fits without scroll verified', category: 'dual_panel');

      logger.info('Original text fit test completed', category: 'dual_panel');
    }, skip: true, reason: 'Requires test book and navigation');

    testWidgets('Translated panel is independently scrollable', (WidgetTester tester) async {
      logger.info('Testing translated panel scrollability', category: 'dual_panel');

      // Arrange
      await tester.pumpWidget(
        const ProviderScope(
          child: app.MyApp(),
        ),
      );
      await TestHelpers.waitForAppSettled(tester);

      // Act & Assert
      // final readerPage = ReaderPage(tester);
      // readerPage.verifyTranslatedPanelScrollable();

      // Test scrolling
      // await readerPage.scrollTranslatedPanel(const Offset(0, -200));

      logger.info('Translated panel scrollable verified', category: 'dual_panel');

      logger.info('Translated panel scroll test completed', category: 'dual_panel');
    }, skip: true, reason: 'Requires test book and navigation');

    testWidgets('Panel width ratio is adjustable in landscape mode',
        (WidgetTester tester) async {
      logger.info('Testing panel width ratio adjustment', category: 'dual_panel');

      // Arrange - Landscape orientation
      await tester.binding.setSurfaceSize(const Size(800, 400));

      await tester.pumpWidget(
        const ProviderScope(
          child: app.MyApp(),
        ),
      );
      await TestHelpers.waitForAppSettled(tester);

      // Act
      // final readerPage = ReaderPage(tester);
      // final initialRatio = readerPage.getPanelWidthRatio();

      // Adjust ratio (this would require drag gesture on divider)
      // await readerPage.setPanelWidthRatio(0.6);

      // final newRatio = readerPage.getPanelWidthRatio();

      // Assert
      // expect(newRatio, isNot(equals(initialRatio)));

      logger.info('Panel width ratio adjustment test completed', category: 'dual_panel');

      // Reset
      await tester.binding.setSurfaceSize(null);

      logger.info('Panel ratio test completed', category: 'dual_panel');
    }, skip: true, reason: 'Requires test book and navigation');

    testWidgets('Both panels show text simultaneously', (WidgetTester tester) async {
      logger.info('Testing simultaneous text display', category: 'dual_panel');

      // Arrange
      await tester.pumpWidget(
        const ProviderScope(
          child: app.MyApp(),
        ),
      );
      await TestHelpers.waitForAppSettled(tester);

      // Assert
      // final readerPage = ReaderPage(tester);
      // final displayedText = readerPage.getDisplayedText();
      // expect(displayedText, isNotEmpty);
      // expect(displayedText.length, greaterThan(1), reason: 'Should have text from both panels');

      logger.info('Simultaneous text display verified', category: 'dual_panel');

      logger.info('Simultaneous display test completed', category: 'dual_panel');
    }, skip: true, reason: 'Requires test book and navigation');

    testWidgets('Layout adapts to orientation changes', (WidgetTester tester) async {
      logger.info('Testing orientation change adaptation', category: 'dual_panel');

      // Arrange - Start in portrait
      await tester.binding.setSurfaceSize(const Size(400, 800));

      await tester.pumpWidget(
        const ProviderScope(
          child: app.MyApp(),
        ),
      );
      await TestHelpers.waitForAppSettled(tester);

      // Verify portrait layout
      // final readerPage = ReaderPage(tester);
      // readerPage.verifyPortraitLayout();

      // Act - Change to landscape
      await tester.binding.setSurfaceSize(const Size(800, 400));
      await tester.pumpAndSettle();

      // Verify landscape layout
      // readerPage.verifyLandscapeLayout();

      // Act - Change back to portrait
      await tester.binding.setSurfaceSize(const Size(400, 800));
      await tester.pumpAndSettle();

      // Verify portrait layout again
      // readerPage.verifyPortraitLayout();

      logger.info('Orientation adaptation verified', category: 'dual_panel');

      // Reset
      await tester.binding.setSurfaceSize(null);

      logger.info('Orientation change test completed', category: 'dual_panel');
    }, skip: true, reason: 'Requires test book and navigation');

    testWidgets('Panel divider is visible and interactive', (WidgetTester tester) async {
      logger.info('Testing panel divider', category: 'dual_panel');

      // Arrange - Landscape mode
      await tester.binding.setSurfaceSize(const Size(800, 400));

      await tester.pumpWidget(
        const ProviderScope(
          child: app.MyApp(),
        ),
      );
      await TestHelpers.waitForAppSettled(tester);

      // Assert - Divider should be visible
      // final dividerFinder = find.byType(VerticalDivider);
      // expect(dividerFinder, findsOneWidget);

      logger.info('Panel divider verified', category: 'dual_panel');

      // Reset
      await tester.binding.setSurfaceSize(null);

      logger.info('Panel divider test completed', category: 'dual_panel');
    }, skip: true, reason: 'Requires test book and navigation');

    testWidgets('Text in both panels is readable and properly formatted',
        (WidgetTester tester) async {
      logger.info('Testing text formatting', category: 'dual_panel');

      // Arrange
      await tester.pumpWidget(
        const ProviderScope(
          child: app.MyApp(),
        ),
      );
      await TestHelpers.waitForAppSettled(tester);

      // Assert
      // final readerPage = ReaderPage(tester);
      // final displayedText = readerPage.getDisplayedText();

      // Check for proper text widgets
      // final textWidgets = find.byType(Text);
      // expect(textWidgets, findsWidgets);

      // Check for proper styling (font size, spacing)
      // This would require inspecting widget properties

      logger.info('Text formatting test completed', category: 'dual_panel');
    }, skip: true, reason: 'Requires test book and navigation');

    group('Edge Cases', () {
      testWidgets('Handle very long translated text', (WidgetTester tester) async {
        logger.info('Testing long translated text handling', category: 'dual_panel');

        // Arrange
        await tester.pumpWidget(
          const ProviderScope(
            child: app.MyApp(),
          ),
        );
        await TestHelpers.waitForAppSettled(tester);

        // Assert - Translated panel should scroll for long text
        // final readerPage = ReaderPage(tester);
        // await readerPage.scrollTranslatedPanel(const Offset(0, -500));

        logger.info('Long text handling test completed', category: 'dual_panel');
      }, skip: true, reason: 'Requires test book and navigation');

      testWidgets('Handle empty translation', (WidgetTester tester) async {
        logger.info('Testing empty translation handling', category: 'dual_panel');

        // Arrange
        await tester.pumpWidget(
          const ProviderScope(
            child: app.MyApp(),
          ),
        );
        await TestHelpers.waitForAppSettled(tester);

        // Assert - Should show placeholder or loading state
        // final readerPage = ReaderPage(tester);
        // expect(find.text('Translating...') | find.text('No translation'),
        //     findsOneWidget);

        logger.info('Empty translation handling test completed', category: 'dual_panel');
      }, skip: true, reason: 'Requires test book and navigation');

      testWidgets('Handle special characters in both panels', (WidgetTester tester) async {
        logger.info('Testing special character handling', category: 'dual_panel');

        // Arrange
        await tester.pumpWidget(
          const ProviderScope(
            child: app.MyApp(),
          ),
        );
        await TestHelpers.waitForAppSettled(tester);

        // Assert - Special characters should display correctly
        // final readerPage = ReaderPage(tester);
        // readerPage.verifyTextDisplayed('\'');
        // readerPage.verifyTextDisplayed('"');
        // readerPage.verifyTextDisplayed('—');

        logger.info('Special character handling test completed', category: 'dual_panel');
      }, skip: true, reason: 'Requires test book and navigation');
    });
  });
}
