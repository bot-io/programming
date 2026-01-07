import 'package:dual_reader/src/domain/services/translation_service.dart';
import 'package:dual_reader/src/data/services/translation_cache_service.dart';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

/// Mock translation service for testing purposes.
/// Provides simulated translations for demonstration.
class MockTranslationServiceImpl implements TranslationService {
  final TranslationCacheService _cacheService;

  // Supported languages in priority order
  static const List<String> _supportedLanguages = [
    'es', // Spanish (default target)
    'en', // English
    'bg', // Bulgarian
    'fr', // French
    'de', // German
    'it', // Italian
    'pt', // Portuguese
    'zh', // Chinese
    'ja', // Japanese
    'ru', // Russian
  ];

  MockTranslationServiceImpl(this._cacheService);

  /// Generate a cache key from text and target language.
  /// Uses hash for long texts to avoid Hive's 255 character key limit.
  String _generateCacheKey(String text, String targetLanguage) {
    if (text.length > 200) {
      final bytes = utf8.encode('${text.substring(0, 100)}...$text.substring(text.length - 100)}_$targetLanguage');
      final hash = sha256.convert(bytes);
      return 'trans_$hash';
    }
    return '${text}_$targetLanguage';
  }

  /// Get the first alternative language from the supported list
  String _getAlternativeLanguage(String excludeLanguage) {
    for (final lang in _supportedLanguages) {
      if (lang != excludeLanguage) {
        return lang;
      }
    }
    return 'en'; // Fallback to English
  }

  /// Split text into sentences for better translation
  List<String> _splitIntoSentences(String text) {
    // Split on sentence boundaries while keeping the delimiters
    final sentences = <String>[];
    final buffer = StringBuffer();

    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      if (text[i] == '.' || text[i] == '!' || text[i] == '?') {
        // Check if next char is whitespace or end of string
        if (i == text.length - 1 || text[i + 1] == ' ' || text[i + 1] == '\n') {
          sentences.add(buffer.toString().trim());
          buffer.clear();
        }
      }
    }

    // Add any remaining text
    if (buffer.isNotEmpty) {
      sentences.add(buffer.toString().trim());
    }

    return sentences.where((s) => s.isNotEmpty).toList();
  }

  /// Comprehensive word replacements for better translation quality
  Map<String, String> _getReplacements(String targetLanguage) {
    switch (targetLanguage) {
      case 'es':
        return {
          // Common words
          'the': 'el',
          'a': 'un',
          'an': 'un',
          'and': 'y',
          'or': 'o',
          'but': 'pero',
          'with': 'con',
          'without': 'sin',
          'for': 'para',
          'to': 'a',
          'of': 'de',
          'in': 'en',
          'at': 'en',
          'on': 'en',
          'from': 'de',
          'by': 'por',
          'about': 'acerca de',
          'as': 'como',
          'is': 'es',
          'are': 'son',
          'was': 'era',
          'were': 'eran',
          'be': 'ser',
          'been': 'sido',
          'being': 'siendo',
          'have': 'tener',
          'has': 'ha',
          'had': 'tenía',
          'do': 'hacer',
          'does': 'hace',
          'did': 'hizo',
          'will': 'va',
          'would': 'haría',
          'could': 'podría',
          'should': 'debería',
          'may': 'puede',
          'might': 'podría',
          'must': 'debe',
          'can': 'poder',
          'this': 'este',
          'that': 'ese',
          'these': 'estos',
          'those': 'esos',
          'my': 'mi',
          'your': 'tu',
          'his': 'su',
          'her': 'su',
          'its': 'su',
          'our': 'nuestro',
          'their': 'su',
          'i': 'yo',
          'you': 'tú',
          'he': 'él',
          'she': 'ella',
          'it': 'ello',
          'we': 'nosotros',
          'they': 'ellos',
          'what': 'qué',
          'which': 'cuál',
          'who': 'quién',
          'whom': 'a quién',
          'whose': 'de quién',
          'where': 'dónde',
          'when': 'cuándo',
          'why': 'por qué',
          'how': 'cómo',
          'all': 'todo',
          'each': 'cada',
          'every': 'cada',
          'some': 'alguno',
          'any': 'algún',
          'no': 'no',
          'none': 'ninguno',
          'both': 'ambos',
          'either': 'cualquiera',
          'neither': 'ninguno',
          'not': 'no',
          'only': 'solo',
          'also': 'también',
          'very': 'muy',
          'more': 'más',
          'most': 'más',
          'less': 'menos',
          'least': 'menos',
          'much': 'mucho',
          'many': 'muchos',
          'few': 'pocos',
          'little': 'poco',
          'own': 'propio',
          'same': 'mismo',
          'so': 'tan',
          'than': 'que',
          'too': 'demasiado',
          'such': 'tal',
          'just': 'justo',
          'now': 'ahora',
          'then': 'entonces',
          'here': 'aquí',
          'there': 'allí',
          'always': 'siempre',
          'never': 'nunca',
          'often': 'a menudo',
          'usually': 'generalmente',
          'still': 'todavía',
          'already': 'ya',
          'yes': 'sí',
          'no': 'no',
          'please': 'por favor',
          'thank': 'gracias',
          'hello': 'hola',
          'goodbye': 'adiós',
          // Book/reading related
          'book': 'libro',
          'chapter': 'capítulo',
          'page': 'página',
          'read': 'leer',
          'reading': 'leyendo',
          'text': 'texto',
          'word': 'palabra',
          'sentence': 'frase',
          'paragraph': 'párrafo',
          'story': 'historia',
          'author': 'autor',
          'title': 'título',
          'content': 'contenido',
          'ebook': 'libro electrónico',
          'use': 'uso',
          'cost': 'costo',
          'restriction': 'restricción',
          'world': 'mundo',
          'part': 'parte',
          'united': 'unidos',
          'states': 'estados',
          'america': 'américa',
          'anyone': 'cualquiera',
          'anywhere': 'dondequiera',
          'almost': 'casi',
          'whatsoever': 'absolutamente',
          'ebook': 'libro',
        };
      case 'bg':
        return {
          'the': '',
          'a': '',
          'an': '',
          'and': 'и',
          'or': 'или',
          'but': 'но',
          'with': 'с',
          'without': 'без',
          'for': 'за',
          'to': 'към',
          'of': 'на',
          'in': 'в',
          'at': 'в',
          'on': 'на',
          'from': 'от',
          'by': 'от',
          'about': 'за',
          'as': 'като',
          'is': 'е',
          'are': 'са',
          'was': 'бе',
          'were': 'бяха',
          'be': 'бъда',
          'been': 'бил',
          'have': 'имам',
          'has': 'има',
          'had': 'имаше',
          'this': 'този',
          'that': 'този',
          'these': 'тези',
          'those': 'тези',
          'my': 'моя',
          'your': 'ваша',
          'his': 'неговата',
          'her': 'нейната',
          'its': 'неговата',
          'our': 'нашата',
          'their': 'тяхната',
          'all': 'всички',
          'each': 'всеки',
          'every': 'всеки',
          'some': 'някои',
          'any': 'някой',
          'no': 'не',
          'none': 'нито един',
          'not': 'не',
          'only': 'само',
          'also': 'също',
          'very': 'много',
          'more': 'повече',
          'most': 'най-много',
          'book': 'книга',
          'chapter': 'глава',
          'page': 'страница',
          'read': 'чета',
          'world': 'свят',
          'ebook': 'електронна книга',
          'use': 'използване',
        };
      case 'fr':
        return {
          'the': 'le',
          'a': 'un',
          'an': 'un',
          'and': 'et',
          'or': 'ou',
          'but': 'mais',
          'with': 'avec',
          'without': 'sans',
          'for': 'pour',
          'to': 'à',
          'of': 'de',
          'in': 'dans',
          'at': 'à',
          'on': 'sur',
          'from': 'de',
          'by': 'par',
          'about': 'à propos',
          'as': 'comme',
          'is': 'est',
          'are': 'sont',
          'was': 'était',
          'were': 'étaient',
          'be': 'être',
          'have': 'avoir',
          'has': 'a',
          'had': 'avait',
          'this': 'ce',
          'that': 'cela',
          'these': 'ces',
          'those': 'ceux',
          'my': 'mon',
          'your': 'votre',
          'his': 'son',
          'her': 'sa',
          'its': 'son',
          'our': 'notre',
          'their': 'leur',
          'all': 'tout',
          'each': 'chaque',
          'every': 'chaque',
          'some': 'certains',
          'any': 'aucun',
          'no': 'non',
          'none': 'aucun',
          'not': 'pas',
          'only': 'seulement',
          'also': 'aussi',
          'very': 'très',
          'more': 'plus',
          'most': 'plus',
          'book': 'livre',
          'chapter': 'chapitre',
          'page': 'page',
          'read': 'lire',
          'ebook': 'livre numérique',
          'use': 'utilisation',
        };
      case 'de':
        return {
          'the': 'der',
          'a': 'ein',
          'an': 'ein',
          'and': 'und',
          'or': 'oder',
          'but': 'aber',
          'with': 'mit',
          'without': 'ohne',
          'for': 'für',
          'to': 'zu',
          'of': 'von',
          'in': 'in',
          'at': 'bei',
          'on': 'auf',
          'from': 'von',
          'by': 'von',
          'about': 'über',
          'as': 'als',
          'is': 'ist',
          'are': 'sind',
          'was': 'war',
          'were': 'waren',
          'be': 'sein',
          'have': 'haben',
          'has': 'hat',
          'had': 'hatte',
          'this': 'dies',
          'that': 'das',
          'these': 'diese',
          'those': 'jene',
          'my': 'mein',
          'your': 'dein',
          'his': 'sein',
          'her': 'ihr',
          'its': 'sein',
          'our': 'unser',
          'their': 'ihr',
          'all': 'alle',
          'each': 'jeder',
          'every': 'jeder',
          'some': 'einige',
          'any': 'kein',
          'no': 'kein',
          'none': 'keiner',
          'not': 'nicht',
          'only': 'nur',
          'also': 'auch',
          'very': 'sehr',
          'more': 'mehr',
          'most': 'am meisten',
          'book': 'buch',
          'chapter': 'kapitel',
          'page': 'seite',
          'read': 'lesen',
          'ebook': 'ebook',
          'use': 'verwendung',
        };
      default:
        return {};
    }
  }

  /// Improved context-aware mock translation that processes sentence by sentence
  String _mockTranslateText(String text, String targetLanguage) {
    if (targetLanguage == 'en') {
      return text; // No translation needed for English
    }

    final replacements = _getReplacements(targetLanguage);
    if (replacements.isEmpty) {
      final langNames = {
        'es': '🇪🇸 Spanish',
        'bg': '🇧🇬 Bulgarian',
        'fr': '🇫🇷 French',
        'de': '🇩🇪 German',
        'it': '🇮🇹 Italian',
        'pt': '🇵🇹 Portuguese',
        'zh': '🇨🇳 Chinese',
        'ja': '🇯🇵 Japanese',
        'ru': '🇷🇺 Russian',
      };
      return '[${langNames[targetLanguage] ?? targetLanguage}] $text';
    }

    // Split into sentences and translate each sentence
    final sentences = _splitIntoSentences(text);
    final translatedSentences = <String>[];

    for (final sentence in sentences) {
      String translated = sentence;

      // Apply replacements in order of length (longer phrases first)
      final sortedKeys = replacements.keys.toList()
        ..sort((a, b) => b.length.compareTo(a.length));

      for (final key in sortedKeys) {
        translated = translated.replaceAllMapped(
          RegExp('\\b${RegExp.escape(key)}\\b', caseSensitive: false),
          (match) {
            // Preserve capitalization
            final matched = match.group(0)!;
            final replacement = replacements[key]!;
            if (matched[0].toUpperCase() == matched[0]) {
              return replacement[0].toUpperCase() + replacement.substring(1);
            }
            return replacement;
          },
        );
      }

      translatedSentences.add(translated);
    }

    final result = translatedSentences.join(' ');
    return result;
  }

  @override
  Future<String> translate({
    required String text,
    required String targetLanguage,
    String? sourceLanguage,
  }) async {
    final detectedLanguage = sourceLanguage ?? await detectLanguage(text);

    String actualTargetLanguage = targetLanguage;
    if (detectedLanguage == targetLanguage) {
      actualTargetLanguage = _getAlternativeLanguage(targetLanguage);
      debugPrint('MockTranslation: Source ($detectedLanguage) = target, using $actualTargetLanguage');
    }

    final cacheKey = _generateCacheKey(text, actualTargetLanguage);
    final cachedTranslation = _cacheService.getCachedTranslation(cacheKey, actualTargetLanguage);
    if (cachedTranslation != null) {
      debugPrint('MockTranslation: Cache hit (${text.length} chars)');
      return cachedTranslation;
    }

    await Future.delayed(const Duration(milliseconds: 300));

    final translated = _mockTranslateText(text, actualTargetLanguage);
    debugPrint('MockTranslation: [$detectedLanguage -> $actualTargetLanguage] (${text.length} chars)');

    await _cacheService.cacheTranslation(cacheKey, actualTargetLanguage, translated);
    return translated;
  }

  @override
  Future<String> detectLanguage(String text) async {
    await Future.delayed(const Duration(milliseconds: 50));

    final lowerText = text.toLowerCase();

    // Check for Cyrillic (Bulgarian, Russian, etc.)
    if (RegExp(r'[а-я]').hasMatch(text)) {
      if (RegExp(r'[бгджзклмнптфцчшщъы]').hasMatch(text)) {
        debugPrint('MockTranslation: Detected Bulgarian (Cyrillic)');
        return 'bg';
      }
      debugPrint('MockTranslation: Detected Russian (Cyrillic)');
      return 'ru';
    }

    // Spanish patterns (more specific)
    if (lowerText.contains(' los ') || lowerText.contains(' las ') || lowerText.contains(' y ')) {
      if (!lowerText.contains(' the ')) {
        debugPrint('MockTranslation: Detected Spanish');
        return 'es';
      }
    }

    // French patterns
    if (lowerText.contains("d'") || lowerText.contains(" l'") ||
        (lowerText.contains(' le ') && lowerText.contains(' les '))) {
      if (!lowerText.contains(' the ')) {
        debugPrint('MockTranslation: Detected French');
        return 'fr';
      }
    }

    // German patterns
    if (lowerText.contains(' der ') || lowerText.contains(' die ') ||
        lowerText.contains(' das ') || lowerText.contains(' und ')) {
      if (!lowerText.contains(' the ')) {
        debugPrint('MockTranslation: Detected German');
        return 'de';
      }
    }

    // Italian patterns
    if (lowerText.contains(' il ') || lowerText.contains(' lo ') ||
        lowerText.contains(' la ') || lowerText.contains(' i ')) {
      if (!lowerText.contains(' the ') && !lowerText.contains(' is ')) {
        debugPrint('MockTranslation: Detected Italian');
        return 'it';
      }
    }

    // Portuguese patterns
    if ((lowerText.contains(' o ') || lowerText.contains(' um ') ||
         lowerText.contains(' uma ')) && !lowerText.contains(' the ')) {
      debugPrint('MockTranslation: Detected Portuguese');
      return 'pt';
    }

    // Chinese characters
    if (RegExp(r'[\u4e00-\u9fff]').hasMatch(text)) {
      debugPrint('MockTranslation: Detected Chinese');
      return 'zh';
    }

    // Japanese characters
    if (RegExp(r'[\u3040-\u309f\u30a0-\u30ff]').hasMatch(text)) {
      debugPrint('MockTranslation: Detected Japanese');
      return 'ja';
    }

    // Default to English (most common case)
    debugPrint('MockTranslation: Detected English (default)');
    return 'en';
  }
}
