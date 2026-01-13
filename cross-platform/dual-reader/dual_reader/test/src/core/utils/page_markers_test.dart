import 'package:flutter_test/flutter_test.dart';
import 'package:dual_reader/src/core/utils/page_markers.dart';

void main() {
  group('PageMarkers', () {
    group('insertMarkers', () {
      test('should insert markers around text for page 0', () {
        const text = 'Hello world';
        final result = PageMarkers.insertMarkers(text, 0);

        expect(result, isNot(equals(text)));
        expect(result.startsWith('\uE000'), isTrue);
        expect(result.endsWith('\uF000'), isTrue);
        expect(result, contains('Hello world'));
      });

      test('should insert markers around text for page 5', () {
        const text = 'Page five content';
        final result = PageMarkers.insertMarkers(text, 5);

        expect(result, isNot(equals(text)));
        expect(result.startsWith('\uE005'), isTrue);
        expect(result.endsWith('\uF005'), isTrue);
        expect(result, contains('Page five content'));
      });

      test('should insert markers around multiline text', () {
        const text = 'Line 1\nLine 2\nLine 3';
        final result = PageMarkers.insertMarkers(text, 0);

        expect(result, contains('\uE000'));
        expect(result, contains('\uF000'));
        expect(result, contains('Line 1\nLine 2\nLine 3'));
      });

      test('should insert markers around empty text', () {
        const text = '';
        final result = PageMarkers.insertMarkers(text, 0);

        expect(result, '\uE000\uF000');
      });

      test('should handle special characters in text', () {
        const text = 'Special: !@#\$%^&*()_+-=[]{}|;:\'",.<>?/~`';
        final result = PageMarkers.insertMarkers(text, 0);

        expect(result, contains(text));
        expect(result.startsWith('\uE000'), isTrue);
        expect(result.endsWith('\uF000'), isTrue);
      });

      test('should throw on negative page index', () {
        expect(
          () => PageMarkers.insertMarkers('text', -1),
          throwsArgumentError,
        );
      });

      test('should throw on page index > 3839', () {
        expect(
          () => PageMarkers.insertMarkers('text', 3840),
          throwsArgumentError,
        );
      });
    });

    group('extractPage', () {
      test('should extract page 0 from single marked page', () {
        const marked = '\uE000Hello world\uF000';
        final result = PageMarkers.extractPage(marked, 0);

        expect(result, 'Hello world');
      });

      test('should extract page 0 from multiple marked pages', () {
        const marked = '\uE000Page 0\uF000\n\uE001Page 1\uF001\n\uE002Page 2\uF002';
        final result = PageMarkers.extractPage(marked, 0);

        expect(result, 'Page 0');
      });

      test('should extract page 1 from multiple marked pages', () {
        const marked = '\uE000Page 0\uF000\n\uE001Page 1\uF001\n\uE002Page 2\uF002';
        final result = PageMarkers.extractPage(marked, 1);

        expect(result, 'Page 1');
      });

      test('should extract page 2 from multiple marked pages', () {
        const marked = '\uE000Page 0\uF000\n\uE001Page 1\uF001\n\uE002Page 2\uF002';
        final result = PageMarkers.extractPage(marked, 2);

        expect(result, 'Page 2');
      });

      test('should return empty string when start marker not found', () {
        const marked = 'No markers here';
        final result = PageMarkers.extractPage(marked, 0);

        expect(result, '');
      });

      test('should return content after start marker if end marker missing', () {
        const marked = '\uE000Content without end marker';
        final result = PageMarkers.extractPage(marked, 0);

        expect(result, 'Content without end marker');
      });

      test('should extract page with special characters', () {
        const marked = '\uE000Special: !@#\$%\uF000';
        final result = PageMarkers.extractPage(marked, 0);

        expect(result, 'Special: !@#\$%');
      });

      test('should extract multiline content', () {
        const marked = '\uE000Line 1\nLine 2\nLine 3\uF000';
        final result = PageMarkers.extractPage(marked, 0);

        expect(result, 'Line 1\nLine 2\nLine 3');
      });

      test('should throw on negative page index', () {
        expect(
          () => PageMarkers.extractPage('text', -1),
          throwsArgumentError,
        );
      });

      test('should throw on page index > 3839', () {
        expect(
          () => PageMarkers.extractPage('text', 3840),
          throwsArgumentError,
        );
      });
    });

    group('stripMarkers', () {
      test('should remove markers from single page', () {
        const marked = '\uE000Hello world\uF000';
        final result = PageMarkers.stripMarkers(marked);

        expect(result, 'Hello world');
      });

      test('should remove markers from multiple pages', () {
        const marked = '\uE000Page 0\uF000\n\uE001Page 1\uF001\n\uE002Page 2\uF002';
        final result = PageMarkers.stripMarkers(marked);

        expect(result, 'Page 0\nPage 1\nPage 2');
      });

      test('should return empty string when empty input', () {
        const marked = '';
        final result = PageMarkers.stripMarkers(marked);

        expect(result, '');
      });

      test('should return text unchanged when no markers present', () {
        const text = 'No markers here';
        final result = PageMarkers.stripMarkers(text);

        expect(result, 'No markers here');
      });

      test('should handle text with only markers', () {
        const marked = '\uE000\uF000\uE001\uF001';
        final result = PageMarkers.stripMarkers(marked);

        expect(result, '');
      });
    });

    group('hasMarkers', () {
      test('should return true when start marker present', () {
        const marked = '\uE000Hello\uF000';
        final result = PageMarkers.hasMarkers(marked);

        expect(result, isTrue);
      });

      test('should return false when no markers present', () {
        const text = 'No markers';
        final result = PageMarkers.hasMarkers(text);

        expect(result, isFalse);
      });

      test('should return false for empty string', () {
        final result = PageMarkers.hasMarkers('');

        expect(result, isFalse);
      });
    });

    group('countMarkedPages', () {
      test('should return 0 for text with no markers', () {
        final result = PageMarkers.countMarkedPages('No markers');

        expect(result, 0);
      });

      test('should count single marked page', () {
        const marked = '\uE000Page 0\uF000';
        final result = PageMarkers.countMarkedPages(marked);

        expect(result, 1);
      });

      test('should count multiple marked pages', () {
        const marked = '\uE000P0\uF000\uE001P1\uF001\uE002P2\uF002\uE003P3\uF003';
        final result = PageMarkers.countMarkedPages(marked);

        expect(result, 4);
      });

      test('should count non-consecutive page markers', () {
        const marked = '\uE000P0\uF000\uE005P5\uF005\uE00AP10\uF00A';
        final result = PageMarkers.countMarkedPages(marked);

        expect(result, 3);
      });
    });

    group('extractPageIndices', () {
      test('should return empty list for text with no markers', () {
        final result = PageMarkers.extractPageIndices('No markers');

        expect(result, isEmpty);
      });

      test('should extract single page index', () {
        const marked = '\uE000Page 0\uF000';
        final result = PageMarkers.extractPageIndices(marked);

        expect(result, [0]);
      });

      test('should extract multiple consecutive page indices', () {
        const marked = '\uE000P0\uF000\uE001P1\uF001\uE002P2\uF002';
        final result = PageMarkers.extractPageIndices(marked);

        expect(result, [0, 1, 2]);
      });

      test('should extract non-consecutive page indices', () {
        const marked = '\uE000P0\uF000\uE005P5\uF005\uE00AP10\uF00A';
        final result = PageMarkers.extractPageIndices(marked);

        expect(result, [0, 5, 10]);
      });
    });

    group('Round-trip Tests', () {
      test('should preserve text through insert->extract cycle', () {
        const original = 'Hello, world! This is a test.';
        final marked = PageMarkers.insertMarkers(original, 0);
        final extracted = PageMarkers.extractPage(marked, 0);

        expect(extracted, original);
      });

      test('should preserve text through insert->extract->strip cycle', () {
        const original = 'Hello, world! This is a test.';
        final marked = PageMarkers.insertMarkers(original, 0);
        final stripped = PageMarkers.stripMarkers(marked);

        expect(stripped, original);
      });

      test('should handle multiple pages through full cycle', () {
        final pages = ['Page 0 content', 'Page 1 content', 'Page 2 content'];
        final marked = pages
            .asMap()
            .entries
            .map((e) => PageMarkers.insertMarkers(e.value, e.key))
            .join('\n\n');

        for (int i = 0; i < pages.length; i++) {
          final extracted = PageMarkers.extractPage(marked, i);
          expect(extracted, pages[i]);
        }
      });

      test('should strip all markers from multiple pages', () {
        final pages = ['Page 0', 'Page 1', 'Page 2'];
        final marked = pages
            .asMap()
            .entries
            .map((e) => PageMarkers.insertMarkers(e.value, e.key))
            .join('\n\n');

        final stripped = PageMarkers.stripMarkers(marked);
        expect(stripped, 'Page 0\n\nPage 1\n\nPage 2');
      });
    });

    group('Edge Cases', () {
      test('should handle very long text', () {
        final longText = 'A' * 10000;
        final marked = PageMarkers.insertMarkers(longText, 0);
        final extracted = PageMarkers.extractPage(marked, 0);

        expect(extracted, longText);
      });

      test('should handle unicode text', () {
        const unicode = 'Hello 世界 🌍 Привет мир';
        final marked = PageMarkers.insertMarkers(unicode, 0);
        final extracted = PageMarkers.extractPage(marked, 0);

        expect(extracted, unicode);
      });

      test('should handle text with existing backslash u escapes', () {
        const text = 'Escape sequences: \\n \\t \\u0041';
        final marked = PageMarkers.insertMarkers(text, 0);
        final extracted = PageMarkers.extractPage(marked, 0);

        expect(extracted, text);
      });

      test('should handle page at max index (3839)', () {
        const text = 'Last page';
        final marked = PageMarkers.insertMarkers(text, 3839);
        final extracted = PageMarkers.extractPage(marked, 3839);

        expect(extracted, text);
      });

      test('should handle high page index like 358', () {
        const text = 'Page 358 content';
        final marked = PageMarkers.insertMarkers(text, 358);
        final extracted = PageMarkers.extractPage(marked, 358);

        expect(extracted, text);
      });
    });
  });
}
