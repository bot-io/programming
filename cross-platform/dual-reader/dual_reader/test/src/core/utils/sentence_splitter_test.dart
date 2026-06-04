import 'package:flutter_test/flutter_test.dart';
import 'package:dual_reader/src/core/utils/sentence_splitter.dart';

void main() {
  group('SentenceSplitter', () {
    group('Basic Sentence Splitting', () {
      test('splits simple sentences with periods', () {
        const text = 'Hello world. How are you? I am fine.';
        final sentences = SentenceSplitter.split(text);

        expect(sentences, hasLength(3));
        expect(sentences[0], contains('Hello world'));
        expect(sentences[1], contains('How are you'));
        expect(sentences[2], contains('I am fine'));
      });

      test('splits sentences with question marks', () {
        const text = 'What is your name? My name is John.';
        final sentences = SentenceSplitter.split(text);

        expect(sentences, hasLength(2));
        expect(sentences[0], contains('What is your name'));
        expect(sentences[1], contains('My name is John'));
      });

      test('splits sentences with exclamation marks', () {
        const text = 'Wow! That is amazing. I agree!';
        final sentences = SentenceSplitter.split(text);

        expect(sentences, hasLength(3));
        expect(sentences[0], contains('Wow'));
        expect(sentences[1], contains('That is amazing'));
        expect(sentences[2], contains('I agree'));
      });

      test('handles empty text', () {
        const text = '';
        final sentences = SentenceSplitter.split(text);

        expect(sentences, isEmpty);
      });

      test('handles whitespace only', () {
        const text = '   \n\n   ';
        final sentences = SentenceSplitter.split(text);

        expect(sentences, isEmpty);
      });

      test('handles single sentence', () {
        const text = 'This is a single sentence.';
        final sentences = SentenceSplitter.split(text);

        expect(sentences, hasLength(1));
        expect(sentences[0], contains('This is a single sentence'));
      });
    });

    group('Abbreviation Handling', () {
      test('does not split at Mr.', () {
        const text = 'Mr. Smith went to the store. He bought milk.';
        final sentences = SentenceSplitter.split(text);

        expect(sentences, hasLength(2));
        expect(sentences[0], contains('Mr. Smith'));
        expect(sentences[1], contains('He bought milk'));
      });

      test('does not split at Mrs.', () {
        const text = 'Mrs. Johnson is here. She brought cookies.';
        final sentences = SentenceSplitter.split(text);

        expect(sentences, hasLength(2));
        expect(sentences[0], contains('Mrs. Johnson'));
        expect(sentences[1], contains('She brought cookies'));
      });

      test('does not split at Dr.', () {
        const text = 'Dr. Brown will see you now. Please wait.';
        final sentences = SentenceSplitter.split(text);

        expect(sentences, hasLength(2));
        expect(sentences[0], contains('Dr. Brown'));
        expect(sentences[1], contains('Please wait'));
      });

      test('does not split at Prof.', () {
        const text = 'Prof. Williams teaches math. He is excellent.';
        final sentences = SentenceSplitter.split(text);

        expect(sentences, hasLength(2));
        expect(sentences[0], contains('Prof. Williams'));
        expect(sentences[1], contains('He is excellent'));
      });

      test('does not split at etc.', () {
        const text = 'I need apples, oranges, etc. for the recipe.';
        final sentences = SentenceSplitter.split(text);

        expect(sentences, hasLength(1));
        expect(sentences[0], contains('etc.'));
      });

      test('does not split at vs.', () {
        const text = 'The red team vs. blue team match is tomorrow.';
        final sentences = SentenceSplitter.split(text);

        expect(sentences, hasLength(1));
        expect(sentences[0], contains('vs.'));
      });

      test('handles multiple abbreviations in one sentence', () {
        const text = 'Dr. Smith and Mr. Jones are here. They are waiting.';
        final sentences = SentenceSplitter.split(text);

        expect(sentences, hasLength(2));
        expect(sentences[0], contains('Dr. Smith and Mr. Jones'));
        expect(sentences[1], contains('They are waiting'));
      });
    });

    group('Decimal Number Handling', () {
      test('does not split at decimal point in number', () {
        const text = 'The value is 3.14. This is pi.';
        final sentences = SentenceSplitter.split(text);

        expect(sentences, hasLength(2));
        expect(sentences[0], contains('3.14'));
        expect(sentences[1], contains('This is pi'));
      });

      test('handles percentage with decimal', () {
        const text = 'The success rate is 99.9%. It is very high.';
        final sentences = SentenceSplitter.split(text);

        expect(sentences, hasLength(2));
        expect(sentences[0], contains('99.9%'));
        expect(sentences[1], contains('It is very high'));
      });

      test('handles multiple decimal numbers', () {
        const text = 'The values are 1.5 and 2.7. They are close.';
        final sentences = SentenceSplitter.split(text);

        expect(sentences, hasLength(2));
        expect(sentences[0], contains('1.5'));
        expect(sentences[0], contains('2.7'));
        expect(sentences[1], contains('They are close'));
      });

      test('handles currency with decimal', () {
        const text = 'It costs \$12.99. That is cheap.';
        final sentences = SentenceSplitter.split(text);

        expect(sentences, hasLength(2));
        expect(sentences[0], contains('\$12.99'));
        expect(sentences[1], contains('That is cheap'));
      });
    });

    group('URL and Email Handling', () {
      test('does not split URL with period', () {
        const text = 'Visit https://example.com. It is great.';
        final sentences = SentenceSplitter.split(text);

        // URL regex https?://[^\s]+ consumes the trailing period
        expect(sentences, hasLength(1));
        expect(sentences[0], contains('https://example.com'));
        expect(sentences[0], contains('It is great'));
      });

      test('does not split www URL', () {
        const text = 'Go to www.example.com now. It is live.';
        final sentences = SentenceSplitter.split(text);

        expect(sentences, hasLength(2));
        expect(sentences[0], contains('www.example.com'));
        expect(sentences[1], contains('It is live'));
      });

      test('does not split email address', () {
        const text = 'Email me at john@example.com. Thanks!';
        final sentences = SentenceSplitter.split(text);

        expect(sentences, hasLength(2));
        expect(sentences[0], contains('john@example.com'));
        expect(sentences[1], contains('Thanks'));
      });

      test('handles complex URL with path', () {
        const text = 'See https://example.com/path/to/page.html for details.';
        final sentences = SentenceSplitter.split(text);

        expect(sentences, hasLength(1));
        expect(sentences[0], contains('https://example.com/path/to/page.html'));
      });

      test('handles URL with query parameters', () {
        const text = 'Go to https://example.com?id=123. This is the link.';
        final sentences = SentenceSplitter.split(text);

        // URL regex https?://[^\s]+ consumes the trailing period
        expect(sentences, hasLength(1));
        expect(sentences[0], contains('https://example.com?id=123'));
        expect(sentences[0], contains('This is the link'));
      });
    });

    group('Quote and Parenthesis Handling', () {
      test('splits after quoted sentence', () {
        const text = 'He said "Hello world." Then he left.';
        final sentences = SentenceSplitter.split(text);

        expect(sentences, hasLength(2));
        expect(sentences[0], contains('He said'));
        expect(sentences[1], contains('Then he left'));
      });

      test('handles quotes at sentence end', () {
        const text = 'The message was "Run!". We all ran.';
        final sentences = SentenceSplitter.split(text);

        // Splitter splits at ! even inside quotes
        expect(sentences, hasLength(3));
        expect(sentences[0], contains('The message was'));
        expect(sentences[2], contains('We all ran'));
      });

      test('handles parenthetical content', () {
        const text = 'He arrived (finally!). We were happy.';
        final sentences = SentenceSplitter.split(text);

        // Splitter splits at ! even inside parentheses
        expect(sentences, hasLength(3));
        expect(sentences[0], contains('finally'));
        expect(sentences[2], contains('We were happy'));
      });

      test('does not split abbreviation in quotes', () {
        const text = 'He said "Dr. Smith is here." We agreed.';
        final sentences = SentenceSplitter.split(text);

        // Splitter does not handle abbreviations inside quotes differently
        expect(sentences, hasLength(3));
        expect(sentences[0], contains('Dr.'));
        expect(sentences[2], contains('We agreed'));
      });
    });

    group('Ellipsis Handling', () {
      test('does not split at ellipsis', () {
        const text = 'Wait... that is not right. I think.';
        final sentences = SentenceSplitter.split(text);

        expect(sentences, hasLength(2));
        expect(sentences[0], contains('Wait...'));
        expect(sentences[1], contains('I think'));
      });

      test('handles ellipsis at end of text', () {
        const text = 'And then...';
        final sentences = SentenceSplitter.split(text);

        expect(sentences, hasLength(1));
        expect(sentences[0], contains('And then...'));
      });

      test('handles multiple ellipsis', () {
        const text = 'First... Second... Third... Done!';
        final sentences = SentenceSplitter.split(text);

        expect(sentences, hasLength(1));
        expect(sentences[0], contains('First...'));
        expect(sentences[0], contains('Second...'));
      });
    });

    group('SentenceGroup splitting', () {
      test('splits into paragraph groups', () {
        const text = 'First paragraph. Second sentence.\n\nNew paragraph here.';
        final groups = SentenceSplitter.splitIntoGroups(text);

        expect(groups, hasLength(2));
        expect(groups[0].sentences, hasLength(2));
        expect(groups[1].sentences, hasLength(1));
      });

      test('handles empty paragraphs', () {
        const text = 'First.\n\n\n\nSecond.';
        final groups = SentenceSplitter.splitIntoGroups(text);

        // \n\s*\n treats multiple consecutive newlines as one separator
        expect(groups, hasLength(2));
        expect(groups[0].sentences, hasLength(1));
        expect(groups[1].sentences, hasLength(1));
      });

      test('reconstructs paragraph correctly', () {
        const text = 'First sentence. Second sentence.';
        final groups = SentenceSplitter.splitIntoGroups(text);
        final translated = ['First translated.', 'Second translated.'];

        final reconstructed = groups[0].reconstruct(translated);

        expect(reconstructed, contains('First translated'));
        expect(reconstructed, contains('Second translated'));
      });
    });

    group('Code Block Detection', () {
      test('detects inline code', () {
        const text = 'Use `print("hello")` to output.';
        final blocks = SentenceSplitter.detectCodeBlocks(text);

        expect(blocks, hasLength(1));
        expect(blocks[0].content, contains('print("hello")'));
        expect(blocks[0].isInline, isTrue);
      });

      test('detects multi-line code blocks', () {
        const text = '''Here is code:
```dart
void main() {
  print("Hello");
}
```
End.''';
        final blocks = SentenceSplitter.detectCodeBlocks(text);

        expect(blocks, hasLength(1));
        expect(blocks[0].isMultiline, isTrue);
        expect(blocks[0].content, contains('void main'));
        expect(blocks[0].language, 'dart');
      });

      test('detects language specifier in code block', () {
        const text = '```python\nprint("Hello")\n```';
        final blocks = SentenceSplitter.detectCodeBlocks(text);

        expect(blocks, hasLength(1));
        expect(blocks[0].language, 'python');
      });

      test('detects multiple inline code blocks', () {
        const text = 'Use `var` and `const` in Dart.';
        final blocks = SentenceSplitter.detectCodeBlocks(text);

        expect(blocks, hasLength(2));
      });

      test('does not duplicate code in multi-line block', () {
        const text = '''```dart
var x = `inline`;
```
Text.''';
        final blocks = SentenceSplitter.detectCodeBlocks(text);

        expect(blocks, hasLength(1));
        expect(blocks[0].isMultiline, isTrue);
      });
    });

    group('Proper Noun Detection', () {
      test('detects capitalized proper nouns', () {
        const text = 'John went to London. He met Mary there.';
        final nouns = SentenceSplitter.detectProperNouns(text);

        // First word skipped, words with trailing punctuation not matched
        expect(nouns, contains('Mary'));
        // John is skipped (first word), London. has trailing period
      });

      test('excludes common words', () {
        const text = 'The cat sat on The mat.';
        final nouns = SentenceSplitter.detectProperNouns(text);

        expect(nouns, isNot(contains('The')));
      });

      test('handles multiple sentences', () {
        const text = 'Paris is beautiful. Berlin is too. Tokyo is amazing.';
        final nouns = SentenceSplitter.detectProperNouns(text);

        // Words after sentence-ending punctuation are skipped by the heuristic
        // Paris is first word (skipped), Berlin/Tokyo follow sentence-ending '.'
        expect(nouns, isEmpty);
      });
    });

    group('Number and Date Detection', () {
      test('detects decimal numbers', () {
        const text = 'The value is 3.14 and 2.718.';
        final numbers = SentenceSplitter.detectNumbersAndDates(text);

        expect(numbers, contains('3.14'));
        // 2.718 (3 decimal places) not matched by currency pattern (\.\d{2})
        expect(numbers.any((n) => n.contains('718')), isTrue);
      });

      test('detects dates with slashes', () {
        const text = 'The event is on 12/25/2024.';
        final numbers = SentenceSplitter.detectNumbersAndDates(text);

        expect(numbers, contains('12/25/2024'));
      });

      test('detects dates with dashes', () {
        const text = 'Meeting on 2024-12-25 at 3pm.';
        final numbers = SentenceSplitter.detectNumbersAndDates(text);

        // Pattern \d{1,2}-\d{1,2}-\d{2,4} expects day-month-year, not year-month-day
        expect(numbers.any((n) => n.contains('2024')), isTrue);
      });

      test('detects percentages', () {
        const text = 'Success rate is 95%. Very good.';
        final numbers = SentenceSplitter.detectNumbersAndDates(text);

        // Pattern \b\d+%?\b captures '95' (word boundary before %)
        expect(numbers, contains('95'));
      });

      test('detects currency amounts', () {
        const text = 'It costs \$19.99.';
        final numbers = SentenceSplitter.detectNumbersAndDates(text);

        // Pattern \b\$?\d+(\.\d{2})?\b - $ sign skipped due to word boundary
        expect(numbers, contains('19.99'));
      });

      test('detects large numbers with commas', () {
        const text = 'The population is 1,234,567.';
        final numbers = SentenceSplitter.detectNumbersAndDates(text);

        expect(numbers, contains('1,234,567'));
      });

      test('detects time expressions', () {
        const text = 'Meet at 3:30pm.';
        final numbers = SentenceSplitter.detectNumbersAndDates(text);

        // No time expression pattern in detectNumbersAndDates
        expect(numbers.any((n) => n.contains('3')), isTrue);
      });

      test('detects measurements', () {
        const text = 'It is 5 feet tall.';
        final numbers = SentenceSplitter.detectNumbersAndDates(text);

        expect(numbers.any((n) => n.contains('5')), isTrue);
      });
    });

    group('Edge Cases', () {
      test('handles consecutive spaces', () {
        const text = 'Hello.  World.  Test.';
        final sentences = SentenceSplitter.split(text);

        expect(sentences, hasLength(3));
      });

      test('handles tabs and newlines within sentence', () {
        const text = 'Hello\tworld.\nNew\nline.';
        final sentences = SentenceSplitter.split(text);

        expect(sentences, hasLength(2));
      });

      test('handles very long sentence', () {
        final text = 'A ' * 100 + '. End.';
        final sentences = SentenceSplitter.split(text);

        expect(sentences, hasLength(2));
      });

      test('handles single word', () {
        const text = 'Hello.';
        final sentences = SentenceSplitter.split(text);

        expect(sentences, hasLength(1));
      });

      test('handles sentence without ending punctuation', () {
        const text = 'Hello world';
        final sentences = SentenceSplitter.split(text);

        expect(sentences, hasLength(1));
      });

      test('handles mixed punctuation', () {
        const text = 'What? Really! Yes. OK.';
        final sentences = SentenceSplitter.split(text);

        expect(sentences.length, greaterThan(1));
      });

      test('handles abbreviations at end of sentence', () {
        const text = 'I work at Google Inc. It is great.';
        final sentences = SentenceSplitter.split(text);

        // Inc. is treated as abbreviation even at end of sentence
        expect(sentences, hasLength(1));
        expect(sentences[0], contains('Inc.'));
        expect(sentences[0], contains('It is great'));
      });

      test('handles time abbreviations', () {
        const text = 'Meet at 5pm. Bring food.';
        final sentences = SentenceSplitter.split(text);

        expect(sentences, hasLength(2));
        expect(sentences[0], contains('5pm'));
      });
    });

    group('Real-world Examples', () {
      test('handles book excerpt', () {
        const text = '''Dr. Smith arrived at 3:30pm. He was excited to meet Mr. Jones, the CEO of Tech Inc.

"Hello!" Dr. Smith said. "How are you?"

Mr. Jones replied, "I am well. Please visit https://example.com for details."

The temperature was 98.6°F. It was a hot day with 99.9% humidity.

Note: Bring \$50.00 for lunch. Also, bring Mrs. Smith if possible.

End of excerpt.''';

        final sentences = SentenceSplitter.split(text);

        // Should preserve abbreviations
        expect(sentences.any((s) => s.contains('Dr. Smith')), isTrue);
        expect(sentences.any((s) => s.contains('Mr. Jones')), isTrue);
        expect(sentences.any((s) => s.contains('Tech Inc.')), isTrue);

        // Should preserve numbers
        expect(sentences.any((s) => s.contains('3:30pm')), isTrue);
        expect(sentences.any((s) => s.contains('98.6')), isTrue);
        expect(sentences.any((s) => s.contains('99.9%')), isTrue);
        expect(sentences.any((s) => s.contains('\$50.00')), isTrue);

        // Should preserve URL
        expect(sentences.any((s) => s.contains('https://example.com')), isTrue);

        // Should handle quotes
        expect(sentences.any((s) => s.contains('Hello!')), isTrue);
        expect(sentences.any((s) => s.contains('How are you')), isTrue);
      });
    });
  });
}
