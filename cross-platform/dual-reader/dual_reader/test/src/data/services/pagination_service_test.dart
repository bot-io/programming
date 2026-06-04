import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dual_reader/src/data/services/pagination_service_impl.dart';
import 'package:dual_reader/src/domain/services/pagination_service.dart';

void main() {
  group('PaginationServiceImpl', () {
    late PaginationServiceImpl service;

    setUp(() {
      service = PaginationServiceImpl();
    });

    test('should paginate text correctly based on constraints', () {
      // Given
      const text = 'This is a short sentence. This is another sentence. And a third one.';
      const constraints = BoxConstraints(
        maxWidth: 100, // Small width to force pagination
        maxHeight: 50, // Small height to force pagination
      );
      const textStyle = TextStyle(fontSize: 14);
      const lineHeight = 18.0; // Approximate line height

      // When
      final pages = service.paginateText(
        text: text,
        constraints: constraints,
        textStyle: textStyle,
        lineHeight: lineHeight,
      );

      // Then
      expect(pages, isNotEmpty);
      expect(pages.length, greaterThan(1));
      // Reconstruct the text by joining pages and removing all spaces to compare
      final reconstructed = pages.join('').replaceAll(RegExp(r'\s+'), '');
      final originalStripped = text.replaceAll(RegExp(r'\s+'), '');
      expect(reconstructed, equals(originalStripped));
    });

    test('should handle empty text', () {
      // Given
      const text = '';
      const constraints = BoxConstraints(
        maxWidth: 100,
        maxHeight: 100,
      );
      const textStyle = TextStyle(fontSize: 14);

      // When
      final pages = service.paginateText(
        text: text,
        constraints: constraints,
        textStyle: textStyle,
      );

      // Then
      expect(pages, isEmpty);
    });

    group('Chapter title stripping', () {
      test('should strip HTML h1-h6 headings from text', () {
        // Given
        const text = '<h1>Chapter 1</h1>\n\nSome content here.\n\n<h2>Section 1.1</h2>\n\nMore content.';
        const constraints = BoxConstraints(
          maxWidth: 300,
          maxHeight: 200,
        );
        const textStyle = TextStyle(fontSize: 14);

        // When
        final pages = service.paginateText(
          text: text,
          constraints: constraints,
          textStyle: textStyle,
        );

        // Then: Headings should be stripped, not included in pages
        final reconstructed = pages.join();
        expect(reconstructed, isNot(contains('Chapter 1')));
        expect(reconstructed, isNot(contains('Section 1.1')));
        expect(reconstructed, contains('Some content here'));
        expect(reconstructed, contains('More content'));
      });

      test('should strip markdown-style headings', () {
        // Given
        const text = '# Chapter One\n\nContent here.\n\n## Section One\n\nMore content.';
        const constraints = BoxConstraints(
          maxWidth: 300,
          maxHeight: 200,
        );
        const textStyle = TextStyle(fontSize: 14);

        // When
        final pages = service.paginateText(
          text: text,
          constraints: constraints,
          textStyle: textStyle,
        );

        // Then: Markdown headings should be stripped
        final reconstructed = pages.join();
        expect(reconstructed, isNot(contains('Chapter One')));
        expect(reconstructed, isNot(contains('Section One')));
        expect(reconstructed, contains('Content here'));
      });

      test('should strip "Chapter X" patterns from text', () {
        // Given
        const text = 'Chapter 1: The Beginning\n\nOnce upon a time...\n\nChapter 2: The Journey\n\nThey traveled far.';
        const constraints = BoxConstraints(
          maxWidth: 300,
          maxHeight: 200,
        );
        const textStyle = TextStyle(fontSize: 14);

        // When
        final pages = service.paginateText(
          text: text,
          constraints: constraints,
          textStyle: textStyle,
        );

        // Then: Chapter titles should be stripped
        final reconstructed = pages.join();
        expect(reconstructed, isNot(contains('Chapter 1: The Beginning')));
        expect(reconstructed, isNot(contains('Chapter 2: The Journey')));
        expect(reconstructed, contains('Once upon a time'));
        expect(reconstructed, contains('They traveled far'));
      });

      test('should strip Roman numeral chapters', () {
        // Given
        const text = 'I. The First Age\n\nLong ago...\n\nII. The Second Age\n\nTime passed.';
        const constraints = BoxConstraints(
          maxWidth: 300,
          maxHeight: 200,
        );
        const textStyle = TextStyle(fontSize: 14);

        // When
        final pages = service.paginateText(
          text: text,
          constraints: constraints,
          textStyle: textStyle,
        );

        // Then: Roman numeral chapters should be stripped
        final reconstructed = pages.join();
        expect(reconstructed, isNot(contains('I. The First Age')));
        expect(reconstructed, isNot(contains('II. The Second Age')));
      });

      test('should preserve content while stripping headings', () {
        // Given: Text with HTML headings
        const text = '<h1>Title</h1>\n\n<p>Paragraph 1</p>\n\n<h2>Subtitle</h2>\n\n<p>Paragraph 2</p>';
        const constraints = BoxConstraints(
          maxWidth: 300,
          maxHeight: 100,
        );
        const textStyle = TextStyle(fontSize: 14);

        // When
        final pages = service.paginateText(
          text: text,
          constraints: constraints,
          textStyle: textStyle,
        );

        // Then: Content is preserved but headings removed
        expect(pages, isNotEmpty);
        final reconstructed = pages.join();
        expect(reconstructed, contains('Paragraph 1'));
        expect(reconstructed, contains('Paragraph 2'));
        expect(reconstructed, isNot(contains('<h1>')));
        expect(reconstructed, isNot(contains('<h2>')));
      });
    });

    group('Timeout behavior', () {
      test('should timeout after 5 seconds for large text', () {
        // Given: Very large text that would take > 5 seconds to paginate
        final text = 'Sentence. ' * 50000; // ~450,000 characters
        const constraints = BoxConstraints(
          maxWidth: 300,
          maxHeight: 400,
        );
        const textStyle = TextStyle(fontSize: 14);

        // When: Use custom config with short timeout for testing
        final result = service.paginateWithProgress(
          text: text,
          constraints: constraints,
          textStyle: textStyle,
          config: const PaginationConfig(
            timeoutMs: 100, // Very short timeout for testing
            progressInterval: 1000,
          ),
        );

        // Then: Should timeout and mark as timed out
        expect(result.timedOut, isTrue);
        expect(result.pages, isNotEmpty);
        expect(result.elapsedMs, greaterThan(100));
      });

      test('should not timeout for small text', () {
        // Given: Small text
        const text = 'This is a short text.';
        const constraints = BoxConstraints(
          maxWidth: 300,
          maxHeight: 400,
        );
        const textStyle = TextStyle(fontSize: 14);

        // When
        final result = service.paginateWithProgress(
          text: text,
          constraints: constraints,
          textStyle: textStyle,
          config: const PaginationConfig(
            timeoutMs: 100,
          ),
        );

        // Then: Should not timeout
        expect(result.timedOut, isFalse);
        expect(result.pages.length, equals(1));
        expect(result.elapsedMs, lessThan(100));
      });

      test('should add remaining text as final page on timeout', () {
        // Given: Text that will timeout during pagination
        final text = 'Sentence. ' * 10000; // ~90,000 characters
        const constraints = BoxConstraints(
          maxWidth: 200,
          maxHeight: 300,
        );
        const textStyle = TextStyle(fontSize: 14);

        // When
        final result = service.paginateWithProgress(
          text: text,
          constraints: constraints,
          textStyle: textStyle,
          config: const PaginationConfig(
            timeoutMs: 50, // Very short timeout
          ),
        );

        // Then: All text should be in pages (even if timed out)
        final totalLength = result.pages.map((p) => p.length).reduce((a, b) => a + b);
        expect(totalLength, equals(text.length));
        expect(result.timedOut, isTrue);
      });
    });

    group('Progress reporting', () {
      test('should report progress during pagination', () {
        // Given: Large text
        final text = 'Sentence. ' * 1000; // ~9,000 characters
        const constraints = BoxConstraints(
          maxWidth: 300,
          maxHeight: 400,
        );
        const textStyle = TextStyle(fontSize: 14);

        final progressUpdates = <int>[];

        // When
        service.paginateWithProgress(
          text: text,
          constraints: constraints,
          textStyle: textStyle,
          config: const PaginationConfig(
            progressInterval: 5, // Report every 5 pages
          ),
          progressCallback: (current, estimated) {
            progressUpdates.add(current);
          },
        );

        // Then: Should have received progress updates
        expect(progressUpdates, isNotEmpty);
        expect(progressUpdates.first, greaterThan(0));
      });
    });

    group('Boundary detection', () {
      test('should break at sentence boundaries', () {
        // Given: Text with clear sentence boundaries
        const text = 'Sentence one. Sentence two! Sentence three? Sentence four.';
        const constraints = BoxConstraints(
          maxWidth: 150,
          maxHeight: 50,
        );
        const textStyle = TextStyle(fontSize: 14);

        // When
        final pages = service.paginateText(
          text: text,
          constraints: constraints,
          textStyle: textStyle,
        );

        // Then: Pages should end at sentence boundaries
        expect(pages, isNotEmpty);
        // Check that pages don't end mid-sentence (no partial sentences)
        for (final page in pages) {
          if (page.isNotEmpty) {
            final lastChar = page.trim().characters.last;
            // Last character should be sentence ending or space/newline
            expect(
              ['.', '!', '?', ' ', '\n'].contains(lastChar) || page.endsWith('one.') || page.endsWith('two!') || page.endsWith('three?'),
              isTrue,
            );
          }
        }
      });

      test('should handle text with no punctuation', () {
        // Given: Text without sentence-ending punctuation
        const text = 'word1 word2 word3 word4 word5 word6 word7 word8';
        const constraints = BoxConstraints(
          maxWidth: 100,
          maxHeight: 30,
        );
        const textStyle = TextStyle(fontSize: 14);

        // When
        final pages = service.paginateText(
          text: text,
          constraints: constraints,
          textStyle: textStyle,
        );

        // Then: Should break at word boundaries
        expect(pages, isNotEmpty);
        // Reconstructed should equal original
        final reconstructed = pages.join();
        expect(reconstructed, equals(text));
      });

      test('should handle very long sentences', () {
        // Given: Very long single sentence
        final text = 'This is a very long sentence that continues on and on without '
            'any breaks or pauses and just keeps going with more and more words '
            'and clauses and phrases that make it difficult to find a good break '
            'point for pagination purposes but we need to handle it anyway. ';
        const constraints = BoxConstraints(
          maxWidth: 200,
          maxHeight: 50,
        );
        const textStyle = TextStyle(fontSize: 14);

        // When
        final pages = service.paginateText(
          text: text,
          constraints: constraints,
          textStyle: textStyle,
        );

        // Then: Should create multiple pages
        expect(pages.length, greaterThan(1));
        // All text should be preserved
        final reconstructed = pages.join();
        expect(reconstructed, equals(text));
      });

      test('should detect abbreviations correctly', () {
        // Given: Text with abbreviations that end with periods
        const text = 'Dr. Smith went to Washington D.C. with Mr. Jones. They met Mrs. Brown.';
        const constraints = BoxConstraints(
          maxWidth: 200,
          maxHeight: 100,
        );
        const textStyle = TextStyle(fontSize: 14);

        // When
        final pages = service.paginateText(
          text: text,
          constraints: constraints,
          textStyle: textStyle,
        );

        // Then: Should not break at abbreviation periods
        // Check that we don't have weird splits like "Dr." alone
        for (final page in pages) {
          expect(page, isNot(endsWith('Dr.')));
          expect(page, isNot(endsWith('D.C.')));
          expect(page, isNot(endsWith('Mr.')));
        }

        // All text preserved
        final reconstructed = pages.join();
        expect(reconstructed, equals(text));
      });
    });

    group('Original tests', () {
      test('should respect paragraph breaks', () {
        // Given
        const text = 'Paragraph one.\n\nParagraph two.';
        const constraints = BoxConstraints(
          maxWidth: 200,
          maxHeight: 30,
        ); // Force break between paragraphs
        const textStyle = TextStyle(fontSize: 14);

        // When
        final pages = service.paginateText(
          text: text,
          constraints: constraints,
          textStyle: textStyle,
        );

        // Then
        expect(pages.length, greaterThanOrEqualTo(2));
        expect(pages[0].contains('Paragraph one.'), isTrue);
        expect(pages[1].contains('Paragraph two.'), isTrue);
      });

      test('should not put all remaining text on last page when it exceeds page capacity', () {
        // Given: A large text that should span many pages
        final text = 'This is a test sentence. ' * 1000; // ~20,000 characters
        const constraints = BoxConstraints(
          maxWidth: 300,
          maxHeight: 400,
        );
        const textStyle = TextStyle(fontSize: 16);

        // When
        final pages = service.paginateText(
          text: text,
          constraints: constraints,
          textStyle: textStyle,
        );

        // Then:
        // 1. Should have multiple pages
        expect(pages.length, greaterThan(10));

        // 2. Last page should not contain all remaining text
        expect(pages.last.length, lessThan(2000));

        // 3. All pages except possibly the last should be reasonably sized
        for (int i = 0; i < pages.length - 1; i++) {
          expect(pages[i].length, lessThan(3000));
        }

        // 4. All text should be preserved
        final reconstructed = pages.join();
        expect(reconstructed, equals(text));
      });
    });
  });
}

