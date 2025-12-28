import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dual_reader/widgets/rich_text_renderer.dart';

void main() {
  group('RichTextRenderer Widget Tests', () {
    const baseStyle = TextStyle(
      fontSize: 16,
      color: Colors.black,
    );

    testWidgets('renders plain text when HTML content is empty', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RichTextRenderer(
              htmlContent: '',
              baseStyle: baseStyle,
            ),
          ),
        ),
      );

      // Should render empty text widget
      expect(find.byType(Text), findsOneWidget);
    });

    testWidgets('renders plain text when HTML parsing fails', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RichTextRenderer(
              htmlContent: 'Plain text content',
              baseStyle: baseStyle,
            ),
          ),
        ),
      );

      expect(find.text('Plain text content'), findsOneWidget);
    });

    testWidgets('renders bold text correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RichTextRenderer(
              htmlContent: '<b>Bold text</b>',
              baseStyle: baseStyle,
            ),
          ),
        ),
      );

      expect(find.text('Bold text'), findsOneWidget);
      
      // Check that the text has bold styling
      final textWidget = tester.widget<Text>(find.text('Bold text'));
      expect(textWidget.style?.fontWeight, FontWeight.bold);
    });

    testWidgets('renders italic text correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RichTextRenderer(
              htmlContent: '<i>Italic text</i>',
              baseStyle: baseStyle,
            ),
          ),
        ),
      );

      expect(find.text('Italic text'), findsOneWidget);
      
      final textWidget = tester.widget<Text>(find.text('Italic text'));
      expect(textWidget.style?.fontStyle, FontStyle.italic);
    });

    testWidgets('renders headings correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RichTextRenderer(
              htmlContent: '<h1>Heading 1</h1>',
              baseStyle: baseStyle,
            ),
          ),
        ),
      );

      expect(find.text('Heading 1'), findsOneWidget);
      
      // H1 should be larger and bold
      final textWidget = tester.widget<Text>(find.text('Heading 1'));
      expect(textWidget.style?.fontWeight, FontWeight.bold);
      expect(textWidget.style?.fontSize, 32.0); // 16 * 2.0
    });

    testWidgets('renders paragraphs with spacing', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RichTextRenderer(
              htmlContent: '<p>First paragraph</p><p>Second paragraph</p>',
              baseStyle: baseStyle,
            ),
          ),
        ),
      );

      expect(find.text('First paragraph'), findsOneWidget);
      expect(find.text('Second paragraph'), findsOneWidget);
    });

    testWidgets('renders line breaks correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RichTextRenderer(
              htmlContent: 'Line 1<br>Line 2',
              baseStyle: baseStyle,
            ),
          ),
        ),
      );

      // Should find text with line break
      expect(find.textContaining('Line 1'), findsOneWidget);
      expect(find.textContaining('Line 2'), findsOneWidget);
    });

    testWidgets('renders lists correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RichTextRenderer(
              htmlContent: '<ul><li>Item 1</li><li>Item 2</li></ul>',
              baseStyle: baseStyle,
            ),
          ),
        ),
      );

      expect(find.textContaining('Item 1'), findsOneWidget);
      expect(find.textContaining('Item 2'), findsOneWidget);
    });

    testWidgets('applies text alignment correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RichTextRenderer(
              htmlContent: 'Centered text',
              baseStyle: baseStyle,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );

      final textWidget = tester.widget<Text>(find.text('Centered text'));
      expect(textWidget.textAlign, TextAlign.center);
    });

    testWidgets('applies padding correctly', (WidgetTester tester) async {
      const padding = EdgeInsets.all(16.0);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RichTextRenderer(
              htmlContent: 'Text with padding',
              baseStyle: baseStyle,
              padding: padding,
            ),
          ),
        ),
      );

      final paddingWidget = tester.widget<Padding>(find.byType(Padding));
      expect(paddingWidget.padding, padding);
    });

    testWidgets('handles complex HTML with multiple tags', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RichTextRenderer(
              htmlContent: '<h1>Title</h1><p>Paragraph with <b>bold</b> and <i>italic</i> text.</p>',
              baseStyle: baseStyle,
            ),
          ),
        ),
      );

      expect(find.text('Title'), findsOneWidget);
      expect(find.textContaining('Paragraph with'), findsOneWidget);
    });

    testWidgets('handles blockquote correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RichTextRenderer(
              htmlContent: '<blockquote>Quoted text</blockquote>',
              baseStyle: baseStyle,
            ),
          ),
        ),
      );

      expect(find.textContaining('Quoted text'), findsOneWidget);
    });

    testWidgets('handles code tags correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RichTextRenderer(
              htmlContent: '<code>code snippet</code>',
              baseStyle: baseStyle,
            ),
          ),
        ),
      );

      expect(find.text('code snippet'), findsOneWidget);
    });
  });

  group('FormattedTextRenderer Widget Tests', () {
    const baseStyle = TextStyle(
      fontSize: 16,
      color: Colors.black,
    );

    testWidgets('renders plain text correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FormattedTextRenderer(
              text: 'Plain text',
              baseStyle: baseStyle,
            ),
          ),
        ),
      );

      expect(find.text('Plain text'), findsOneWidget);
    });

    testWidgets('renders empty text when text is empty', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FormattedTextRenderer(
              text: '',
              baseStyle: baseStyle,
            ),
          ),
        ),
      );

      expect(find.byType(Text), findsOneWidget);
    });

    testWidgets('renders bold markdown correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FormattedTextRenderer(
              text: 'This is **bold** text',
              baseStyle: baseStyle,
            ),
          ),
        ),
      );

      expect(find.textContaining('bold'), findsOneWidget);
    });

    testWidgets('renders italic markdown correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FormattedTextRenderer(
              text: 'This is *italic* text',
              baseStyle: baseStyle,
            ),
          ),
        ),
      );

      expect(find.textContaining('italic'), findsOneWidget);
    });

    testWidgets('renders headings with # correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FormattedTextRenderer(
              text: '# Heading 1',
              baseStyle: baseStyle,
            ),
          ),
        ),
      );

      expect(find.text('Heading 1'), findsOneWidget);
    });

    testWidgets('applies text alignment correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FormattedTextRenderer(
              text: 'Right aligned',
              baseStyle: baseStyle,
              textAlign: TextAlign.right,
            ),
          ),
        ),
      );

      final textWidget = tester.widget<Text>(find.text('Right aligned'));
      expect(textWidget.textAlign, TextAlign.right);
    });

    testWidgets('applies padding correctly', (WidgetTester tester) async {
      const padding = EdgeInsets.symmetric(horizontal: 20.0);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FormattedTextRenderer(
              text: 'Text with padding',
              baseStyle: baseStyle,
              padding: padding,
            ),
          ),
        ),
      );

      final paddingWidget = tester.widget<Padding>(find.byType(Padding));
      expect(paddingWidget.padding, padding);
    });
  });
}
