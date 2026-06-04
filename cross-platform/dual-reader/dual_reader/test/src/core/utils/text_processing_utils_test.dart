import 'package:flutter_test/flutter_test.dart';
import 'package:dual_reader/src/core/utils/text_processing_utils.dart';

void main() {
  group('TextProcessingUtils', () {
    group('Sentence Grouping for Translation', () {
      test('groups 2-3 sentences together', () {
        const sentences = [
          'First sentence here.',
          'Second sentence follows.',
          'Third sentence completes.',
          'Fourth sentence starts new group.',
          'Fifth sentence ends it.',
        ];

        final groups = TextProcessingUtils.groupSentencesForTranslation(sentences);

        expect(groups.length, lessThanOrEqualTo(3));
        expect(groups.every((g) => g.sentences.length <= 3), isTrue);
      });

      test('respects dialogue boundaries', () {
        const sentences = [
          'He said hello.',
          '"How are you?" he asked.',
          '"I am fine," she replied.',
          'They smiled at each other.',
        ];

        final groups = TextProcessingUtils.groupSentencesForTranslation(sentences);

        // Dialogue should be grouped together
        final dialogueGroups = groups.where((g) => g.isDialogue == true);
        expect(dialogueGroups.isNotEmpty, isTrue);
      });

      test('handles single long sentence', () {
        const sentences = [
          'This is a very long sentence that exceeds the normal character limit and should be in its own group to avoid translation issues.',
        ];

        final groups = TextProcessingUtils.groupSentencesForTranslation(sentences);

        expect(groups, hasLength(1));
        expect(groups[0].sentences, hasLength(1));
      });

      test('respects character limits per group', () {
        final sentences = List.generate(
          10,
          (i) => 'Sentence number $i with some text.',
        );

        final groups = TextProcessingUtils.groupSentencesForTranslation(sentences);

        for (final group in groups) {
          final length = group.sentences.join('').length;
          expect(length, lessThanOrEqualTo(600)); // Allow some buffer
        }
      });

      test('handles empty sentence list', () {
        final groups = TextProcessingUtils.groupSentencesForTranslation([]);

        expect(groups, isEmpty);
      });

      test('groups coherent units together', () {
        const sentences = [
          'The sun was shining brightly.',
          'Birds were singing in the trees.',
          'It was a beautiful day.',
          'Meanwhile, in the city...',
          'Traffic was heavy.',
        ];

        final groups = TextProcessingUtils.groupSentencesForTranslation(sentences);

        // First three sentences form a coherent unit
        expect(groups.first.sentences.length, greaterThanOrEqualTo(2));
      });
    });

    group('Dialogue Detection', () {
      test('detects dialogue in sentences', () {
        const sentences = [
          'He said "Hello world".',
          '"How are you?" she asked.',
          'This has no quotes.',
        ];

        final dialogues = TextProcessingUtils.detectDialogue(sentences);

        expect(dialogues, hasLength(2));
        expect(dialogues[0].quote, contains('Hello world'));
        expect(dialogues[1].quote, contains('How are you'));
      });

      test('extracts speaker information', () {
        const sentences = [
          'John said "Hello there".',
          'Mary replied "I am well".',
        ];

        final dialogues = TextProcessingUtils.detectDialogue(sentences);

        expect(dialogues[0].speaker, 'John');
        expect(dialogues[0].tag, 'said');
        expect(dialogues[1].speaker, 'Mary');
        expect(dialogues[1].tag, 'replied');
      });

      test('handles various dialogue tags', () {
        const sentences = [
          'He asked "What time is it?"',
          'She exclaimed "Wow!"',
          'He whispered "Be quiet"',
          'They shouted "Go away!"',
        ];

        final dialogues = TextProcessingUtils.detectDialogue(sentences);

        expect(dialogues, hasLength(4));
        expect(dialogues[0].tag, 'asked');
        expect(dialogues[1].tag, 'exclaimed');
        expect(dialogues[2].tag, 'whispered');
        expect(dialogues[3].tag, 'shouted');
      });

      test('handles single quotes', () {
        const sentences = [
          "He said 'Hello world'.",
        ];

        final dialogues = TextProcessingUtils.detectDialogue(sentences);

        expect(dialogues, hasLength(1));
        expect(dialogues[0].quote, contains('Hello world'));
      });

      test('handles dialogue without speaker', () {
        const sentences = [
          '"Hello world."',
          '"How are you?"',
        ];

        final dialogues = TextProcessingUtils.detectDialogue(sentences);

        expect(dialogues, hasLength(2));
        expect(dialogues[0].speaker, isNull);
        expect(dialogues[1].speaker, isNull);
      });
    });

    group('Formatting Extraction and Preservation', () {
      test('extracts bold formatting', () {
        const text = 'This is **bold text** and this is not.';
        final markers = TextProcessingUtils.extractFormatting(text);

        expect(markers, hasLength(1));
        expect(markers[0].type, FormattingType.bold);
        expect(markers[0].content, 'bold text');
      });

      test('extracts italic formatting', () {
        const text = 'This is *italic text* and this is not.';
        final markers = TextProcessingUtils.extractFormatting(text);

        expect(markers, hasLength(1));
        expect(markers[0].type, FormattingType.italic);
        expect(markers[0].content, 'italic text');
      });

      test('extracts inline code', () {
        const text = 'Use `print("hello")` for output.';
        final markers = TextProcessingUtils.extractFormatting(text);

        expect(markers, hasLength(1));
        expect(markers[0].type, FormattingType.code);
        expect(markers[0].content, contains('print'));
      });

      test('extracts links', () {
        const text = 'Visit [example](https://example.com) for details.';
        final markers = TextProcessingUtils.extractFormatting(text);

        expect(markers, hasLength(1));
        expect(markers[0].type, FormattingType.link);
        expect(markers[0].content, 'example');
        expect(markers[0].url, 'https://example.com');
      });

      test('extracts multiple formatting types', () {
        const text = '**Bold**, *italic*, `code`, and [link](url).';
        final markers = TextProcessingUtils.extractFormatting(text);

        expect(markers, hasLength(4));
        expect(markers.any((m) => m.type == FormattingType.bold), isTrue);
        expect(markers.any((m) => m.type == FormattingType.italic), isTrue);
        expect(markers.any((m) => m.type == FormattingType.code), isTrue);
        expect(markers.any((m) => m.type == FormattingType.link), isTrue);
      });

      test('applies formatting to translated text', () {
        const translated = 'This is translated text.';
        final markers = [
          FormattingMarker(
            type: FormattingType.bold,
            start: 0,
            end: 4,
            content: 'This',
          ),
        ];

        final result = TextProcessingUtils.applyFormatting(translated, markers);

        expect(result, contains('**'));
      });

      test('handles overlapping formatting markers', () {
        const text = '***bold and italic*** text.';
        final markers = TextProcessingUtils.extractFormatting(text);

        // Should not duplicate markers for overlapping formats
        expect(markers.length, lessThanOrEqualTo(2));
      });
    });

    group('Post-processing', () {
      test('fixes spacing around punctuation', () {
        const text = 'Hello world . How are you ?';
        final processed = TextProcessingUtils.postProcess(text, 'en');

        expect(processed, contains('Hello world.'));
        expect(processed, contains('How are you?'));
        expect(processed, isNot(contains(' . ')));
        expect(processed, isNot(contains(' ? ')));
      });

      test('capitalizes after sentence endings', () {
        const text = 'hello. how are you? i am fine.';
        final processed = TextProcessingUtils.postProcess(text, 'en');

        expect(processed[0], equals('H')); // First letter capitalized
        expect(processed, contains('How')); // After period
        expect(processed, contains('I')); // After question mark
      });

      test('normalizes quotation marks for French', () {
        const text = '"Hello" and "world"';
        final processed = TextProcessingUtils.postProcess(text, 'fr');

        expect(processed, contains('«'));
        expect(processed, contains('»'));
      });

      test('normalizes quotation marks for German', () {
        const text = '"Hello" and "world"';
        final processed = TextProcessingUtils.postProcess(text, 'de');

        expect(processed, contains('„'));
        expect(processed, contains('""'));
      });

      test('normalizes quotation marks for Japanese', () {
        const text = '"Hello" and "world"';
        final processed = TextProcessingUtils.postProcess(text, 'ja');

        expect(processed, contains('「'));
        expect(processed, contains('」'));
      });

      test('normalizes ellipsis', () {
        const text = 'Wait...... what...';
        final processed = TextProcessingUtils.postProcess(text, 'en');

        expect(processed, contains('...'));
        expect(processed, isNot(contains('......')));
      });

      test('removes double spaces', () {
        const text = 'Hello  world.  How  are  you?';
        final processed = TextProcessingUtils.postProcess(text, 'en');

        expect(processed, isNot(contains('  ')));
      });

      test('preserves single spaces', () {
        const text = 'Hello world. How are you?';
        final processed = TextProcessingUtils.postProcess(text, 'en');

        expect(processed, contains('Hello world.'));
        expect(processed, contains('How are you?'));
      });
    });

    group('Quality Score Calculation', () {
      test('gives high score for good translation', () {
        const original = 'Hello world. How are you?';
        const translated = 'Hola mundo. Cómo estás?';

        final score = TextProcessingUtils.calculateQualityScore(original, translated, 'es');

        expect(score, greaterThan(70));
      });

      test('penalizes very short translation', () {
        const original = 'Hello world. How are you? I am fine.';
        const translated = 'Hi.';

        final score = TextProcessingUtils.calculateQualityScore(original, translated, 'es');

        expect(score, lessThan(80));
      });

      test('penalizes very long translation', () {
        const original = 'Hello.';
        final translated = 'Hello ' * 100;

        final score = TextProcessingUtils.calculateQualityScore(original, translated, 'es');

        expect(score, lessThan(80));
      });

      test('penalizes missing sentence endings', () {
        const original = 'Hello. World. Test.';
        const translated = 'Hello world test';

        final score = TextProcessingUtils.calculateQualityScore(original, translated, 'es');

        expect(score, lessThan(85));
      });

      test('penalizes missing proper nouns', () {
        const original = 'John went to London.';
        const translated = 'Él fue a ciudad.'; // Missing John and London

        final score = TextProcessingUtils.calculateQualityScore(original, translated, 'es');

        expect(score, lessThan(90));
      });

      test('penalizes missing numbers', () {
        const original = 'There are 123 items.';
        const translated = 'Hay artículos.'; // Missing number

        final score = TextProcessingUtils.calculateQualityScore(original, translated, 'es');

        expect(score, lessThan(90));
      });

      test('penalizes missing formatting', () {
        const original = '**Bold** text and `code`.';
        const translated = 'Bold text and code.'; // Missing formatting markers

        final score = TextProcessingUtils.calculateQualityScore(original, translated, 'es');

        expect(score, lessThan(95));
      });

      test('caps score at 100', () {
        const original = 'Hello.';
        const translated = 'Hello.'; // Perfect

        final score = TextProcessingUtils.calculateQualityScore(original, translated, 'en');

        expect(score, lessThanOrEqualTo(100));
      });

      test('caps score at 0 minimum', () {
        const original = 'Hello world. Test 123.';
        const translated = 'x';

        final score = TextProcessingUtils.calculateQualityScore(original, translated, 'es');

        expect(score, greaterThanOrEqualTo(0));
      });
    });

    group('Contextual Translation Units', () {
      test('creates units from text', () {
        const text = 'First sentence. Second sentence. Third sentence.';

        final units = TextProcessingUtils.createTranslationUnits(text);

        expect(units.isNotEmpty, isTrue);
        expect(units.every((u) => u.text.isNotEmpty), isTrue);
        expect(units.every((u) => u.sentences.isNotEmpty), isTrue);
      });

      test('tracks sentence count in units', () {
        const text = 'First. Second. Third. Fourth. Fifth. Sixth.';

        final units = TextProcessingUtils.createTranslationUnits(text);

        final totalSentences = units.fold(0, (sum, u) => sum + u.sentenceCount);
        expect(totalSentences, greaterThanOrEqualTo(3)); // At least some grouping
      });

      test('tracks dialogue in units', () {
        const text = 'He said "Hello". "How are you?" she asked.';

        final units = TextProcessingUtils.createTranslationUnits(text);

        expect(units.any((u) => u.isDialogue), isTrue);
      });

      test('tracks formatting in units', () {
        const text = 'This is **bold**. This is `code`.';

        final units = TextProcessingUtils.createTranslationUnits(text);

        expect(units.any((u) => u.formatting.isNotEmpty), isTrue);
      });

      test('calculates unit lengths correctly', () {
        const text = 'Short. Medium length sentence here. Very long sentence with many words that goes on and on.';

        final units = TextProcessingUtils.createTranslationUnits(text);

        for (final unit in units) {
          expect(unit.length, equals(unit.text.length));
        }
      });
    });

    group('Reassembling Translated Units', () {
      test('reassembles units with proper spacing', () {
        final units = [
          ContextualTranslationUnit(
            text: 'First unit',
            sentences: ['First unit'],
            formatting: [],
            isDialogue: false,
            startIndex: 0,
          ),
          ContextualTranslationUnit(
            text: 'Second unit',
            sentences: ['Second unit'],
            formatting: [],
            isDialogue: false,
            startIndex: 10,
          ),
        ];

        final translations = ['Primera unidad', 'Segunda unidad'];

        final result = TextProcessingUtils.reassembleTranslatedUnits(units, translations, 'es');

        expect(result, contains('Primera unidad'));
        expect(result, contains('Segunda unidad'));
      });

      test('handles empty units', () {
        final units = [
          ContextualTranslationUnit(
            text: '',
            sentences: [],
            formatting: [],
            isDialogue: false,
            startIndex: 0,
          ),
        ];

        final translations = [''];

        final result = TextProcessingUtils.reassembleTranslatedUnits(units, translations, 'es');

        expect(result, isEmpty);
      });

      test('applies formatting during reassembly', () {
        final units = [
          ContextualTranslationUnit(
            text: 'Bold text here',
            sentences: ['Bold text here'],
            formatting: [
              FormattingMarker(
                type: FormattingType.bold,
                start: 0,
                end: 4,
                content: 'Bold',
              ),
            ],
            isDialogue: false,
            startIndex: 0,
          ),
        ];

        final translations = ['Texto bold aquí'];

        final result = TextProcessingUtils.reassembleTranslatedUnits(units, translations, 'es');

        expect(result, contains('**')); // Should apply bold formatting
      });

      test('post-processes during reassembly', () {
        final units = [
          ContextualTranslationUnit(
            text: 'Hello',
            sentences: ['Hello'],
            formatting: [],
            isDialogue: false,
            startIndex: 0,
          ),
        ];

        final translations = ['hola'];

        final result = TextProcessingUtils.reassembleTranslatedUnits(units, translations, 'es');

        // Should capitalize after post-processing
        expect(result[0].toUpperCase(), equals(result[0]));
      });
    });

    group('Real-world Scenarios', () {
      test('handles book excerpt with dialogue', () {
        const text = '''
John entered the room. "Hello everyone," he said.
"How are you?" Mary asked.
"I am well," John replied. "Thank you for asking."
The meeting was about to begin.
''';

        final units = TextProcessingUtils.createTranslationUnits(text);

        expect(units.isNotEmpty, isTrue);
        expect(units.any((u) => u.isDialogue), isTrue);

        // Check that dialogue units have multiple sentences
        final dialogueUnits = units.where((u) => u.isDialogue);
        for (final unit in dialogueUnits) {
          expect(unit.sentenceCount, greaterThanOrEqualTo(1));
        }
      });

      test('handles mixed formatting', () {
        const text = '''
The book **Title** is great.
See [the link](https://example.com) for details.
Use `code` for examples.
''';

        final units = TextProcessingUtils.createTranslationUnits(text);

        expect(units.any((u) => u.formatting.any((f) => f.type == FormattingType.bold)), isTrue);
        expect(units.any((u) => u.formatting.any((f) => f.type == FormattingType.link)), isTrue);
        expect(units.any((u) => u.formatting.any((f) => f.type == FormattingType.code)), isTrue);
      });

      test('handles technical documentation', () {
        const text = '''
Install the package using `npm install`.
Run `npm start` to begin.
See **documentation** for more details.
Visit https://example.com/help if needed.
''';

        final units = TextProcessingUtils.createTranslationUnits(text);

        expect(units.length, greaterThanOrEqualTo(2));
        expect(units.any((u) => u.formatting.isNotEmpty), isTrue);
      });

      test('handles conversation with multiple speakers', () {
        const text = '''
"Hello," said John.
"Hi there," replied Mary.
"How are you?" John asked.
"I'm fine," Mary said. "Thanks for asking."
''';

        final dialogues = TextProcessingUtils.detectDialogue(TextSentenceSplitter.split(text));

        expect(dialogues.length, greaterThanOrEqualTo(4));
        expect(dialogues.where((d) => d.hasSpeaker).length, greaterThan(0));
      });
    });

    group('Integration Tests', () {
      test('full translation pipeline preserves structure', () {
        const text = '''
**Chapter 1**

John went to *London*.

"Hello," he said. "How are you?"

The temperature was 98.6°F.

Visit [example.com](https://example.com) for details.
''';

        // Create units
        final units = TextProcessingUtils.createTranslationUnits(text);

        // Simulate translation (identity for test)
        final translations = units.map((u) => u.text).toList();

        // Reassemble
        final result = TextProcessingUtils.reassembleTranslatedUnits(units, translations, 'en');

        // Verify structure is preserved
        expect(result, contains('Chapter 1'));
        expect(result, contains('John'));
        expect(result, contains('98.6'));
      });

      test('quality score reflects translation quality', () {
        const original = 'The quick brown fox jumps over the lazy dog.';
        const goodTranslation = 'El rápido zorro marrón salta sobre el perro perezoso.';
        const badTranslation = 'Fox dog.';

        final goodScore = TextProcessingUtils.calculateQualityScore(original, goodTranslation, 'es');
        final badScore = TextProcessingUtils.calculateQualityScore(original, badTranslation, 'es');

        expect(goodScore, greaterThan(badScore));
      });
    });
  });
}

// Helper class for testing
class TextSentenceSplitter {
  static List<String> split(String text) {
    return text.split(RegExp(r'(?<=[.!?])\s+'));
  }
}
