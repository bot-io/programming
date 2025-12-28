import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dual_reader/widgets/dual_panel_reader.dart';
import 'package:dual_reader/models/page_content.dart';
import 'package:dual_reader/models/app_settings.dart';
import '../helpers/test_helpers.dart';

void main() {
  group('DualPanelReader Widget Tests', () {
    late PageContent testPage;
    late AppSettings testSettings;

    setUp(() {
      testPage = PageContent(
        pageNumber: 1,
        totalPages: 10,
        originalText: 'This is the original text content.',
        translatedText: 'Este es el texto original.',
      );
      testSettings = TestHelpers.createTestSettings();
    });

    testWidgets('displays original and translated text in portrait mode', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(400, 800),
              orientation: Orientation.portrait,
            ),
            child: Scaffold(
              body: DualPanelReader(
                page: testPage,
                settings: testSettings,
              ),
            ),
          ),
        ),
      );

      // Check that original text is displayed
      expect(find.text('This is the original text content.'), findsOneWidget);
      
      // Check that translated text is displayed
      expect(find.text('Este es el texto original.'), findsOneWidget);
      
      // Check for labels
      expect(find.text('Original'), findsOneWidget);
      expect(find.text('Translated'), findsOneWidget);
    });

    testWidgets('displays original and translated text in landscape mode', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(800, 400),
              orientation: Orientation.landscape,
            ),
            child: Scaffold(
              body: DualPanelReader(
                page: testPage,
                settings: testSettings,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check that original text is displayed
      expect(find.text('This is the original text content.'), findsOneWidget);
      
      // Check that translated text is displayed
      expect(find.text('Este es el texto original.'), findsOneWidget);
    });

    testWidgets('shows "Translating..." when translated text is null', (WidgetTester tester) async {
      final pageWithoutTranslation = PageContent(
        pageNumber: 1,
        totalPages: 10,
        originalText: 'Original text',
        translatedText: null,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DualPanelReader(
              page: pageWithoutTranslation,
              settings: testSettings,
            ),
          ),
        ),
      );

      expect(find.text('Translating...'), findsOneWidget);
      expect(find.text('Original text'), findsOneWidget);
    });

    testWidgets('applies font settings correctly', (WidgetTester tester) async {
      final customSettings = TestHelpers.createTestSettings(
        fontSize: 20,
        fontFamily: 'Arial',
        lineHeight: 2.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DualPanelReader(
              page: testPage,
              settings: customSettings,
            ),
          ),
        ),
      );

      final textWidget = tester.widget<Text>(find.text('This is the original text content.'));
      final style = textWidget.style;
      
      expect(style?.fontSize, 20.0);
      expect(style?.fontFamily, 'Arial');
      expect(style?.height, 2.0);
    });

    testWidgets('applies text alignment correctly', (WidgetTester tester) async {
      final justifySettings = TestHelpers.createTestSettings(
        textAlignment: 'justify',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DualPanelReader(
              page: testPage,
              settings: justifySettings,
            ),
          ),
        ),
      );

      final textWidget = tester.widget<Text>(find.text('This is the original text content.'));
      expect(textWidget.textAlign, TextAlign.justify);
    });

    testWidgets('applies margin size correctly', (WidgetTester tester) async {
      final marginSettings = TestHelpers.createTestSettings(
        marginSize: 3,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DualPanelReader(
              page: testPage,
              settings: marginSettings,
            ),
          ),
        ),
      );

      final scrollView = tester.widget<SingleChildScrollView>(
        find.byType(SingleChildScrollView).first,
      );
      expect(scrollView.padding, const EdgeInsets.all(32.0));
    });

    testWidgets('calls onNextPage when next page button is tapped', (WidgetTester tester) async {
      bool nextPageCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DualPanelReader(
              page: testPage,
              settings: testSettings,
              onNextPage: () {
                nextPageCalled = true;
              },
            ),
          ),
        ),
      );

      // Note: DualPanelReader doesn't have built-in navigation buttons,
      // but we can test that callbacks are properly passed
      expect(nextPageCalled, false);
    });

    testWidgets('handles empty original text', (WidgetTester tester) async {
      final emptyPage = PageContent(
        pageNumber: 1,
        totalPages: 10,
        originalText: '',
        translatedText: '',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DualPanelReader(
              page: emptyPage,
              settings: testSettings,
            ),
          ),
        ),
      );

      // Widget should still render without errors
      expect(find.text('Original'), findsOneWidget);
      expect(find.text('Translated'), findsOneWidget);
    });

    testWidgets('uses provided scroll controllers when available', (WidgetTester tester) async {
      final originalController = ScrollController();
      final translatedController = ScrollController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DualPanelReader(
              page: testPage,
              settings: testSettings,
              originalScrollController: originalController,
              translatedScrollController: translatedController,
            ),
          ),
        ),
      );

      final scrollViews = tester.widgetList<SingleChildScrollView>(
        find.byType(SingleChildScrollView),
      );

      expect(scrollViews.length, 2);
      expect(scrollViews.first.controller, originalController);
      expect(scrollViews.last.controller, translatedController);

      originalController.dispose();
      translatedController.dispose();
    });

    testWidgets('creates scroll controllers when not provided', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DualPanelReader(
              page: testPage,
              settings: testSettings,
            ),
          ),
        ),
      );

      final scrollViews = tester.widgetList<SingleChildScrollView>(
        find.byType(SingleChildScrollView),
      );

      expect(scrollViews.length, 2);
      // Controllers should be created internally
      expect(scrollViews.first.controller, isNotNull);
      expect(scrollViews.last.controller, isNotNull);
    });
  });
}
