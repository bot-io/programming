import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:dual_reader/src/data/services/language_detection_service.dart';

/// Tests for enhanced language detection service
///
/// Test coverage:
/// - Character/script detection (Unicode ranges)
/// - Stopword detection for common languages
/// - N-gram frequency analysis
/// - Confidence scoring
/// - Edge cases (short text, numbers, special characters)
/// - Cyrillic language disambiguation (Bulgarian vs Russian vs Ukrainian)
/// - Mixed language text handling
/// - Caching functionality
void main() {
  group('LanguageDetectionService', () {
    late LanguageDetectionService service;

    setUp(() async {
      Hive.init('test_hive_lang');
      service = LanguageDetectionService.instance;
      await service.init();
    });

    tearDown(() async {
      await service.close();
      await Hive.deleteBoxFromDisk('language_detection_cache');
    });

    group('Script Detection', () {
      test('should detect English (Latin script)', () async {
        const text = 'Hello world, how are you today?';
        final result = await service.detectWithConfidence(text);

        expect(result.languageCode, equals('en'));
        expect(result.confidence, greaterThan(0));
        expect(result.method, isIn([DetectionMethod.script, DetectionMethod.stopwords]));
      });

      test('should detect Spanish (Latin script with stopwords)', () async {
        const text = 'Hola mundo, ¿cómo estás hoy? El sol es brillante.';
        final result = await service.detectWithConfidence(text);

        expect(result.languageCode, equals('es'));
        expect(result.confidence, greaterThan(30));
      });

      test('should detect French', () async {
        const text = 'Bonjour le monde, comment allez-vous aujourd\'hui? Le chat est noir.';
        final result = await service.detectWithConfidence(text);

        expect(result.languageCode, equals('fr'));
        expect(result.confidence, greaterThan(30));
      });

      test('should detect German', () async {
        const text = 'Hallo Welt, wie geht es dir heute? Der Hund ist sehr groß.';
        final result = await service.detectWithConfidence(text);

        expect(result.languageCode, equals('de'));
        expect(result.confidence, greaterThan(30));
      });

      test('should detect Italian', () async {
        const text = 'Ciao mondo, come stai oggi? Il sole è bello.';
        final result = await service.detectWithConfidence(text);

        expect(result.languageCode, equals('it'));
        expect(result.confidence, greaterThan(30));
      });

      test('should detect Portuguese', () async {
        const text = 'Olá mundo, como você está hoje? O sol é brilhante.';
        final result = await service.detectWithConfidence(text);

        expect(result.languageCode, equals('pt'));
        expect(result.confidence, greaterThan(30));
      });

      test('should detect Chinese characters', () async {
        const text = '你好世界，你好吗？这是一个美丽的日子。';
        final result = await service.detectWithConfidence(text);

        expect(result.languageCode, equals('zh'));
        expect(result.confidence, greaterThan(50));
        expect(result.method, equals(DetectionMethod.script));
      });

      test('should detect Japanese characters', () async {
        const text = 'こんにちは世界、元気ですか？今日は良い天気ですね。';
        final result = await service.detectWithConfidence(text);

        expect(result.languageCode, equals('ja'));
        expect(result.confidence, greaterThan(50));
        expect(result.method, equals(DetectionMethod.script));
      });

      test('should detect Korean characters', () async {
        const text = '안녕하세요 세계, 어떻게 지내세요? 오늘은 좋은 날씨입니다.';
        final result = await service.detectWithConfidence(text);

        expect(result.languageCode, equals('ko'));
        expect(result.confidence, greaterThan(50));
        expect(result.method, equals(DetectionMethod.script));
      });

      test('should detect Arabic characters', () async {
        const text = 'مرحبا بالعالم، كيف حالك اليوم؟ الطقس جميل جدا.';
        final result = await service.detectWithConfidence(text);

        expect(result.languageCode, equals('ar'));
        expect(result.confidence, greaterThan(50));
        expect(result.method, equals(DetectionMethod.script));
      });

      test('should detect Greek characters', () async {
        const text = 'Γεια σου κόσμε, πώς είσαι σήμερα; Ο καιρός είναι όμορφος.';
        final result = await service.detectWithConfidence(text);

        expect(result.languageCode, equals('el'));
        expect(result.confidence, greaterThan(50));
      });

      test('should detect Hebrew characters', () async {
        const text = 'שלום עולם, מה קורה היום? מזג האוויר יפה מאוד.';
        final result = await service.detectWithConfidence(text);

        expect(result.languageCode, equals('he'));
        expect(result.confidence, greaterThan(50));
      });

      test('should detect Thai characters', () async {
        const text = 'สวัสดีชาวโลก วันนี้เป็นอย่างไร อากาศดีมาก';
        final result = await service.detectWithConfidence(text);

        expect(result.languageCode, equals('th'));
        expect(result.confidence, greaterThan(50));
      });

      test('should detect Hindi (Devanagari) characters', () async {
        const text = 'नमस्ते दुनिया, आज कैसे हो? मौसम बहुत अच्छा है।';
        final result = await service.detectWithConfidence(text);

        expect(result.languageCode, equals('hi'));
        expect(result.confidence, greaterThan(50));
      });
    });

    group('Cyrillic Disambiguation', () {
      test('should distinguish Bulgarian from Russian', () async {
        const bulgarianText = 'Здравей свят, как си днес? Аз съм добре, благодаря.';
        final result = await service.detectWithConfidence(bulgarianText);

        expect(result.languageCode, equals('bg'));
        expect(result.confidence, greaterThan(20));
      });

      test('should detect Russian', () async {
        const russianText = 'Привет мир, как у тебя дела сегодня? Я хорошо, спасибо.';
        final result = await service.detectWithConfidence(russianText);

        expect(result.languageCode, equals('ru'));
        expect(result.confidence, greaterThan(20));
      });

      test('should detect Ukrainian (has ї, і characters)', () async {
        const ukrainianText = 'Привіт світ, як у тебе справи сьогодні? Я добре, дякую.';
        final result = await service.detectWithConfidence(ukrainianText);

        expect(result.languageCode, equals('uk'));
        expect(result.confidence, greaterThan(50));
      });

      test('should use Bulgarian-specific characters for detection', () async {
        const textWithBgChar = 'Това е текст на български език. Ще използваме специфични букви.';
        final result = await service.detectWithConfidence(textWithBgChar);

        expect(result.languageCode, equals('bg'));
      });

      test('should detect Russian with Ы character', () async {
        const textWithY = 'Это текст на русском языке. Мы используем символ ы.';
        final result = await service.detectWithConfidence(textWithY);

        expect(result.languageCode, equals('ru'));
      });
    });

    group('Stopword Detection', () {
      test('should detect English using stopwords', () async {
        const text = 'The quick brown fox jumps over the lazy dog.';
        final result = await service.detectWithConfidence(text);

        expect(result.languageCode, equals('en'));
        expect(result.confidence, greaterThan(40));
      });

      test('should detect Spanish using articles', () async {
        const text = 'El gato come la comida del perro y duerme en el sofá.';
        final result = await service.detectWithConfidence(text);

        expect(result.languageCode, equals('es'));
        expect(result.confidence, greaterThan(40));
      });

      test('should detect French using articles', () async {
        const text = 'Le chat mange la nourriture du chien et dort sur le canapé.';
        final result = await service.detectWithConfidence(text);

        expect(result.languageCode, equals('fr'));
        expect(result.confidence, greaterThan(40));
      });

      test('should detect German using articles', () async {
        const text = 'Der Hund frisst das Futter der Katze und schläft auf dem Sofa.';
        final result = await service.detectWithConfidence(text);

        expect(result.languageCode, equals('de'));
        expect(result.confidence, greaterThan(40));
      });

      test('should detect Italian using articles', () async {
        const text = 'Il gatto mangia il cibo del cane e dorme sul divano.';
        final result = await service.detectWithConfidence(text);

        expect(result.languageCode, equals('it'));
        expect(result.confidence, greaterThan(40));
      });

      test('should detect Portuguese using articles', () async {
        const text = 'O gato come a comida do cachorro e dorme no sofá.';
        final result = await service.detectWithConfidence(text);

        expect(result.languageCode, equals('pt'));
        expect(result.confidence, greaterThan(40));
      });

      test('should detect Dutch', () async {
        const text = 'De kat eet het voer van de hond en slaapt op de bank.';
        final result = await service.detectWithConfidence(text);

        expect(result.languageCode, equals('nl'));
        expect(result.confidence, greaterThan(30));
      });

      test('should detect Polish', () async {
        const text = 'Kot zjada jedzenie psa i śpi na kanapie. To jest bardzo duże zwierzę.';
        final result = await service.detectWithConfidence(text);

        expect(result.languageCode, equals('pl'));
        expect(result.confidence, greaterThan(20));
      });

      test('should detect Turkish', () async {
        const text = 'Kedi köpeğin yemeğini yer ve kanepeye uyur. Bu çok büyük bir hayvan.';
        final result = await service.detectWithConfidence(text);

        expect(result.languageCode, equals('tr'));
        expect(result.confidence, greaterThan(20));
      });

      test('should detect Swedish', () async {
        const text = 'Katten äter hundens mat och sover på soffan. Det är ett mycket stort djur.';
        final result = await service.detectWithConfidence(text);

        expect(result.languageCode, equals('sv'));
        expect(result.confidence, greaterThan(20));
      });

      test('should detect Finnish', () async {
        const text = 'Kissa syö koiran ruokaa ja nukkuu sohvalla. Se on hyvin suuri eläin.';
        final result = await service.detectWithConfidence(text);

        expect(result.languageCode, equals('fi'));
        expect(result.confidence, greaterThan(20));
      });

      test('should detect Czech', () async {
        const text = 'Kočka sní jídlo psa a spí na pohovce. Je to velmi velké zvíře.';
        final result = await service.detectWithConfidence(text);

        expect(result.languageCode, equals('cs'));
        expect(result.confidence, greaterThan(20));
      });

      test('should detect Romanian', () async {
        const text = 'Pisica mănâncă mâncarea câinelui și doarme pe canapea. Este un animal foarte mare.';
        final result = await service.detectWithConfidence(text);

        expect(result.languageCode, equals('ro'));
        expect(result.confidence, greaterThan(20));
      });

      test('should detect Hungarian', () async {
        const text = 'A macska megeszi a kutya ételét és a kanapén alszik. Nagyon nagy állat.';
        final result = await service.detectWithConfidence(text);

        expect(result.languageCode, equals('hu'));
        expect(result.confidence, greaterThan(20));
      });

      test('should detect Indonesian', () async {
        const text = 'Kucing memakan makanan anjing dan tidur di sofa. Ini adalah hewan yang sangat besar.';
        final result = await service.detectWithConfidence(text);

        expect(result.languageCode, equals('id'));
        expect(result.confidence, greaterThan(20));
      });

      test('should detect Vietnamese', () async {
        const text = 'Con mèo ăn thức ăn của con chó và ngủ trên ghế sofa. Đây là một con vật rất lớn.';
        final result = await service.detectWithConfidence(text);

        expect(result.languageCode, equals('vi'));
        expect(result.confidence, greaterThan(20));
      });
    });

    group('N-gram Detection', () {
      test('should detect English using n-grams (longer text)', () async {
        const text = 'The quick brown fox jumps over the lazy dog. '
            'Pack my box with five dozen liquor jugs. '
            'How vexingly quick daft zebras jump! '
            'The five boxing wizards jump quickly.';
        final result = await service.detectWithConfidence(text);

        expect(result.languageCode, equals('en'));
        // Longer text should have higher confidence
        expect(result.confidence, greaterThan(50));
      });

      test('should detect Spanish using n-grams', () async {
        const text = 'El rápido zorro marrón salta sobre el perro perezoso. '
            'Empaca mi caja con cinco docenas de botellas de licor. '
            '¡Qué rápido saltan los cebras locos! '
            'Los cinco magos boxeadores saltan rápidamente.';
        final result = await service.detectWithConfidence(text);

        expect(result.languageCode, equals('es'));
        expect(result.confidence, greaterThan(40));
      });

      test('should detect French using n-grams', () async {
        const text = 'Le rapide renard brun saute par-dessus le chien paresseux. '
            'Emballez ma boîte avec cinq douzaines de bouteilles de liqueur. '
            'Comme les zèbres fous sautent vite! '
            'Les cinq magiciens boxeurs sautent rapidement.';
        final result = await service.detectWithConfidence(text);

        expect(result.languageCode, equals('fr'));
        expect(result.confidence, greaterThan(40));
      });

      test('should detect German using n-grams', () async {
        const text = 'Der schnelle braune Fuchs springt über den faulen Hund. '
            'Packe meine Kiste mit fünf Dutzend Flaschen Likör. '
            'Wie schnell die verrückten Zebras springen! '
            'Die fünf boxenden Zauberer springen schnell.';
        final result = await service.detectWithConfidence(text);

        expect(result.languageCode, equals('de'));
        expect(result.confidence, greaterThan(40));
      });
    });

    group('Edge Cases', () {
      test('should handle very short text', () async {
        const shortTexts = ['Hi', 'Hola', 'Bonjour', 'Ciao'];

        for (final text in shortTexts) {
          final result = await service.detectWithConfidence(text);
          expect(result.languageCode, isNotEmpty);
          expect(result.confidence, greaterThanOrEqualTo(0));
        }
      });

      test('should handle single character', () async {
        final result = await service.detectWithConfidence('a');
        expect(result.languageCode, isNotEmpty);
        // Very short text may have low confidence
        expect(result.confidence, greaterThanOrEqualTo(0));
      });

      test('should handle empty text', () async {
        final result = await service.detectWithConfidence('');
        expect(result.languageCode, equals('en')); // Default
        expect(result.confidence, equals(0));
      });

      test('should handle whitespace only', () async {
        final result = await service.detectWithConfidence('   \n\t  ');
        expect(result.languageCode, equals('en')); // Default
      });

      test('should handle text with only numbers', () async {
        final result = await service.detectWithConfidence('1234567890');
        expect(result.languageCode, isNotEmpty);
      });

      test('should handle text with numbers and words', () async {
        const text = 'I have 123 apples and 456 oranges. Total is 579 fruits.';
        final result = await service.detectWithConfidence(text);

        expect(result.languageCode, equals('en'));
        expect(result.confidence, greaterThan(30));
      });

      test('should handle text with special characters', () async {
        const text = 'Hello! @user #hashtag \$100 %discount &more';
        final result = await service.detectWithConfidence(text);

        expect(result.languageCode, equals('en'));
        expect(result.confidence, greaterThan(20));
      });

      test('should handle text with URLs', () async {
        const text = 'Visit https://example.com for more info. Also check http://test.org/page?query=value';
        final result = await service.detectWithConfidence(text);

        expect(result.languageCode, equals('en'));
      });

      test('should handle text with email addresses', () async {
        const text = 'Contact us at support@example.com or sales@test.org for help.';
        final result = await service.detectWithConfidence(text);

        expect(result.languageCode, equals('en'));
      });

      test('should handle text with emojis', () async {
        const text = 'Hello! 😊 How are you? 🎉 Have a great day! ❤️';
        final result = await service.detectWithConfidence(text);

        expect(result.languageCode, equals('en'));
        expect(result.confidence, greaterThan(20));
      });

      test('should handle text with mixed case', () async {
        const text = 'HeLLo WoRLd, HoW aRe YoU? ThIs Is MiXeD cAsE tExT.';
        final result = await service.detectWithConfidence(text);

        expect(result.languageCode, equals('en'));
      });

      test('should handle text with punctuation only', () async {
        final result = await service.detectWithConfidence(r'!@#$%^&*()');
        expect(result.languageCode, isNotEmpty);
      });

      test('should handle text with repeated characters', () async {
        final result = await service.detectWithConfidence('aaaaaaaaaaaaaa');
        expect(result.languageCode, isNotEmpty);
      });
    });

    group('Mixed Language Text', () {
      test('should detect languages in mixed English-Spanish text', () async {
        const text = 'Hello! ¿Cómo estás? I am fine, gracias. See you later, adiós.';
        final results = await service.detectMixedLanguages(text);

        expect(results, isNotEmpty);
        expect(results.any((r) => r.languageCode == 'en'), isTrue);
        expect(results.any((r) => r.languageCode == 'es'), isTrue);
      });

      test('should detect dominant language in mostly English text', () async {
        const text = 'This is mostly English text with just a few Spanish words '
            'like gracias and amigo mixed in. The majority is still English language.';
        final results = await service.detectMixedLanguages(text);

        expect(results, isNotEmpty);
        // English should have highest proportion
        expect(results.first.languageCode, equals('en'));
        expect(results.first.proportion, greaterThan(0.5));
      });

      test('should handle text with proper nouns from other languages', () async {
        const text = 'I went to a restaurant called Café du Monde and ordered croissants. '
            'Then I visited the Musée d\'Orsay to see art.';
        final result = await service.detectWithConfidence(text);

        expect(result.languageCode, equals('en'));
        // Should still detect English despite French proper nouns
      });

      test('should detect multiple languages in code-switched text', () async {
        const text = 'Bonjour! Hello! ¿Hola? Ciao! Guten Tag! Olá!';
        final results = await service.detectMixedLanguages(text);

        expect(results, isNotEmpty);
      });
    });

    group('Confidence Scoring', () {
      test('should have higher confidence for longer text', () async {
        const shortText = 'Hello';
        const longText = 'Hello, how are you today? I hope you are doing well. '
            'The weather is beautiful and I am enjoying my day.';

        final shortResult = await service.detectWithConfidence(shortText);
        final longResult = await service.detectWithConfidence(longText);

        // Longer text should generally have higher confidence
        expect(longResult.confidence, greaterThanOrEqualTo(shortResult.confidence));
      });

      test('should have high confidence for unique scripts', () async {
        const chineseText = '这是一段很长的中文文本，包含了独特的汉字字符。'
            '中文字符非常独特，不会与其他语言混淆。'
            '因此，中文检测的置信度应该非常高。';

        final result = await service.detectWithConfidence(chineseText);

        expect(result.languageCode, equals('zh'));
        expect(result.confidence, greaterThan(80));
      });

      test('should have lower confidence for ambiguous short text', () async {
        const text = 'Hi';
        final result = await service.detectWithConfidence(text);

        // Very short ambiguous text should have low confidence
        expect(result.confidence, lessThan(50));
      });

      test('should provide confidence score', () async {
        const text = 'The quick brown fox jumps over the lazy dog.';
        final result = await service.detectWithConfidence(text);

        expect(result.confidence, inInclusiveRange(0, 100));
      });
    });

    group('Caching', () {
      test('should cache detection results', () async {
        const text = 'Hello world, this is a test for caching.';
        await service.clearCache();

        // First call
        final result1 = await service.detectWithConfidence(text);

        // Second call should use cache
        final result2 = await service.detectWithConfidence(text);

        expect(result1.languageCode, equals(result2.languageCode));
        expect(result1.confidence, equals(result2.confidence));
      });

      test('should track cache statistics', () async {
        final stats = service.getCacheStats();

        expect(stats, containsPair('size', isA<int>()));
        expect(stats, containsPair('maxSize', equals(100)));
        expect(stats, containsPair('usagePercent', isA<int>()));
      });

      test('should clear cache', () async {
        await service.clearCache();
        final stats = service.getCacheStats();

        expect(stats['size'], equals(0));
        expect(stats['usagePercent'], equals(0));
      });

      test('should handle cache eviction when full', () async {
        await service.clearCache();

        // Add more items than cache size
        for (int i = 0; i < 150; i++) {
          await service.detectWithConfidence('Test text number $i with some content.');
        }

        final stats = service.getCacheStats();
        // Should not exceed max size
        expect(stats['size'], lessThanOrEqualTo(100));
      });
    });

    group('Simple Detection Method', () {
      test('should return language code only', () async {
        const text = 'Bonjour le monde';
        final language = await service.detectLanguage(text);

        expect(language, equals('fr'));
      });

      test('should handle empty text with default', () async {
        final language = await service.detectLanguage('');

        expect(language, isNotEmpty);
      });
    });

    group('Method Detection', () {
      test('should use script method for non-Latin text', () async {
        const text = 'こんにちは世界';
        final result = await service.detectWithConfidence(text);

        expect(result.method, equals(DetectionMethod.script));
      });

      test('should use stopword method for Latin text with stopwords', () async {
        const text = 'The quick brown fox jumps over the lazy dog.';
        final result = await service.detectWithConfidence(text);

        expect(result.method, isIn([DetectionMethod.stopwords, DetectionMethod.ngram]));
      });

      test('should use ngram method for longer text', () async {
        const text = 'The quick brown fox jumps over the lazy dog. '
            'Pack my box with five dozen liquor jugs. '
            'How vexingly quick daft zebras jump! '
            'The five boxing wizards jump quickly. '
            'Sphinx of black quartz, judge my vow. '
            'Jackdaws love my big sphinx of quartz.';

        final result = await service.detectWithConfidence(text);

        expect(result.method, isIn([DetectionMethod.ngram, DetectionMethod.stopwords]));
      });
    });

    group('Language Variants and Dialects', () {
      test('should detect Spanish regardless of region', () async {
        final variants = [
          'Hola, ¿cómo estás?', // ES (Spain)
          'Hola, ¿cómo estás?', // MX (Mexico) - same in this case
          'Buenos días',
        ];

        for (final text in variants) {
          final result = await service.detectWithConfidence(text);
          expect(result.languageCode, equals('es'), reason: 'Failed for: $text');
        }
      });

      test('should detect Portuguese variants', () async {
        final ptText = 'Obrigado pela ajuda.'; // PT-PT
        final brText = 'Obrigado pela ajuda.'; // PT-BR (same here)

        final result1 = await service.detectWithConfidence(ptText);
        final result2 = await service.detectWithConfidence(brText);

        expect(result1.languageCode, equals('pt'));
        expect(result2.languageCode, equals('pt'));
      });

      test('should handle Chinese characters (simplified/traditional)', () async {
        final simplified = '你好世界';
        final traditional = '你好世界';

        final result1 = await service.detectWithConfidence(simplified);
        final result2 = await service.detectWithConfidence(traditional);

        // Both should be detected as Chinese
        expect(result1.languageCode, equals('zh'));
        expect(result2.languageCode, equals('zh'));
      });
    });

    group('Real-world Text Samples', () {
      test('should detect news headline style', () async {
        const text = 'Breaking News: Scientists Discover New Species in Amazon Rainforest';
        final result = await service.detectWithConfidence(text);

        expect(result.languageCode, equals('en'));
        expect(result.confidence, greaterThan(40));
      });

      test('should detect conversational text', () async {
        const text = 'Hey! What\'s up? Not much, just hanging out. Want to grab some food later?';
        final result = await service.detectWithConfidence(text);

        expect(result.languageCode, equals('en'));
        expect(result.confidence, greaterThan(40));
      });

      test('should detect formal text', () async {
        const text = 'Dear Sir or Madam, I am writing to inquire about your services.';
        final result = await service.detectWithConfidence(text);

        expect(result.languageCode, equals('en'));
        expect(result.confidence, greaterThan(40));
      });

      test('should detect technical text', () async {
        const text = 'The implementation uses a recursive algorithm to traverse the binary tree data structure.';
        final result = await service.detectWithConfidence(text);

        expect(result.languageCode, equals('en'));
      });
    });

    group('Configuration', () {
      test('should allow setting minimum confidence threshold', () {
        service.setMinConfidence(75);
        // Threshold is used internally for filtering
        expect(service._minConfidence, equals(75));
      });

      test('should clamp confidence threshold to valid range', () {
        service.setMinConfidence(150);
        expect(service._minConfidence, equals(100));

        service.setMinConfidence(-10);
        expect(service._minConfidence, equals(0));
      });
    });

    group('Singleton Pattern', () {
      test('should return same instance', () {
        final instance1 = LanguageDetectionService.instance;
        final instance2 = LanguageDetectionService.instance;

        expect(identical(instance1, instance2), isTrue);
      });
    });

    group('Resource Management', () {
      test('should close and cleanup', () async {
        final testService = LanguageDetectionService.instance;
        await testService.init();
        await testService.close();

        // Should not throw
        await expectLater(testService.close(), completes);
      });

      test('should reinitialize after close', () async {
        final testService = LanguageDetectionService.instance;
        await testService.close();

        await testService.init();
        expect(testService.isInitialized, isTrue);
      });
    });
  });
}

/// Extension to test private minConfidence
extension LanguageDetectionServiceTestExtension on LanguageDetectionService {
  int get _minConfidence => 50; // Default value
}
