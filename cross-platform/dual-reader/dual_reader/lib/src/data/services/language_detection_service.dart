import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:dual_reader/src/core/utils/logging_service.dart';

/// Enhanced language detection service with improved accuracy.
///
/// Features:
/// - Character-based script detection (Unicode ranges)
/// - N-gram frequency analysis for better accuracy
/// - Common word/stopword detection
/// - Statistical confidence scoring
/// - Detection result caching
/// - Mixed language text handling
/// - Short text edge case handling
///
/// Accuracy improvements:
/// - Uses multiple detection methods and combines results
/// - Confidence scoring to indicate detection reliability
/// - Handles edge cases (very short text, numbers, special characters)
/// - Proper Cyrillic language disambiguation (Bulgarian vs Russian vs Ukrainian)
class LanguageDetectionService {
  static const String _componentName = 'LanguageDetectionService';
  static const int _defaultMinConfidence = 50; // Minimum confidence threshold (0-100)
  static const int _cacheSize = 100; // Number of cached detections

  // Singleton instance
  static LanguageDetectionService? _instance;
  static LanguageDetectionService get instance {
    _instance ??= LanguageDetectionService._();
    return _instance!;
  }

  // Hive box for caching detection results
  late Box<Map> _cacheBox;
  bool _isInitialized = false;

  /// Check if the service is initialized
  bool get isInitialized => _isInitialized;

  // Minimum confidence threshold
  int _minConfidence = _defaultMinConfidence;

  LanguageDetectionService._();

  /// Initialize the service
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      _cacheBox = await Hive.openBox<Map>('language_detection_cache');
      _isInitialized = true;
      _componentName.logInfo('Language detection service initialized with ${_cacheBox.length} cached results');
    } catch (e) {
      _componentName.logError('Failed to initialize language detection cache', error: e);
      // Continue without cache
      _isInitialized = true;
    }
  }

  /// Set minimum confidence threshold (0-100)
  void setMinConfidence(int confidence) {
    _minConfidence = confidence.clamp(0, 100);
  }

  /// Get current minimum confidence threshold
  int get minConfidence => _minConfidence;

  /// Detect language with confidence score
  ///
  /// Returns [LanguageDetectionResult] with detected language and confidence.
  Future<LanguageDetectionResult> detectWithConfidence(String text) async {
    if (!_isInitialized) {
      await init();
    }

    // Handle edge cases
    if (text.trim().isEmpty) {
      return LanguageDetectionResult(
        languageCode: 'en',
        confidence: 0,
        method: DetectionMethod.default_,
      );
    }

    // Check cache first
    final cacheKey = _generateCacheKey(text);
    final cached = _cacheBox.get(cacheKey) as Map?;
    if (cached != null) {
      return LanguageDetectionResult(
        languageCode: cached['language'] as String,
        confidence: cached['confidence'] as int,
        method: DetectionMethod.values.firstWhere(
          (e) => e.name == cached['method'],
          orElse: () => DetectionMethod.unknown,
        ),
      );
    }

    // Run all detection methods
    final results = <DetectionResult>[];

    // 1. Character/script detection
    final scriptResult = _detectByScript(text);
    results.add(scriptResult);

    // 2. Stopword detection
    final stopwordResult = _detectByStopwords(text);
    results.add(stopwordResult);

    // 3. N-gram detection (for longer text)
    if (text.length > 50) {
      final ngramResult = _detectByNgrams(text);
      results.add(ngramResult);
    }

    // Combine results using weighted voting
    final finalResult = _combineDetectionResults(results);

    // Cache the result
    _cacheResult(cacheKey, finalResult);

    return finalResult;
  }

  /// Simple language detection (returns just the language code)
  Future<String> detectLanguage(String text) async {
    final result = await detectWithConfidence(text);
    return result.languageCode;
  }

  /// Detect all languages present in mixed text
  ///
  /// Returns a list of detected languages with their proportions.
  Future<List<MixedLanguageResult>> detectMixedLanguages(String text) async {
    if (text.trim().isEmpty) {
      return [];
    }

    // Split text into segments by language
    final segments = _splitByLanguage(text);

    // Analyze each segment
    final results = <MixedLanguageResult>[];
    for (final segment in segments) {
      if (segment.text.trim().isEmpty) continue;

      final detection = await detectWithConfidence(segment.text);
      results.add(MixedLanguageResult(
        languageCode: detection.languageCode,
        confidence: detection.confidence,
        proportion: segment.text.length / text.length,
        textSample: segment.text.substring(0, 100.clamp(0, segment.text.length)),
      ));
    }

    // Merge results for same language
    return _mergeMixedResults(results);
  }

  /// Generate cache key from text
  String _generateCacheKey(String text) {
    // Use first 100 chars + length for simple but effective cache key
    final sample = text.substring(0, 100.clamp(0, text.length));
    final bytes = utf8.encode(sample + text.length.toString());
    final encoded = base64Encode(bytes);
    return encoded.substring(0, encoded.length.clamp(0, 32));
  }

  /// Cache detection result
  void _cacheResult(String key, LanguageDetectionResult result) {
    try {
      // Check cache size and evict oldest if needed
      if (_cacheBox.length >= _cacheSize) {
        final keys = _cacheBox.keys.toList();
        if (keys.isNotEmpty) {
          _cacheBox.delete(keys.first);
        }
      }

      _cacheBox.put(key, {
        'language': result.languageCode,
        'confidence': result.confidence,
        'method': result.method.name,
      });
    } catch (e) {
      // Cache failure is not critical
      _componentName.logDebug('Failed to cache detection result: $e');
    }
  }

  /// Detect language by character script (Unicode ranges)
  DetectionResult _detectByScript(String text) {
    final scores = <String, int>{};
    int total = 0;

    // Count characters in each script range
    for (final rune in text.runes) {
      total++;

      // Latin script
      if ((rune >= 0x0000 && rune <= 0x007F) ||
          (rune >= 0x0080 && rune <= 0x00FF) ||
          (rune >= 0x0100 && rune <= 0x017F)) {
        scores['latin'] = (scores['latin'] ?? 0) + 1;
      }
      // Cyrillic
      else if (rune >= 0x0400 && rune <= 0x04FF) {
        scores['cyrillic'] = (scores['cyrillic'] ?? 0) + 1;
      }
      // Greek
      else if (rune >= 0x0370 && rune <= 0x03FF) {
        scores['el'] = (scores['el'] ?? 0) + 1;
      }
      // Arabic
      else if (rune >= 0x0600 && rune <= 0x06FF) {
        scores['ar'] = (scores['ar'] ?? 0) + 1;
      }
      // Hebrew
      else if (rune >= 0x0590 && rune <= 0x05FF) {
        scores['he'] = (scores['he'] ?? 0) + 1;
      }
      // Chinese (CJK Unified Ideographs)
      else if (rune >= 0x4E00 && rune <= 0x9FFF) {
        scores['zh'] = (scores['zh'] ?? 0) + 1;
      }
      // Japanese Hiragana
      else if (rune >= 0x3040 && rune <= 0x309F) {
        scores['ja'] = (scores['ja'] ?? 0) + 1;
      }
      // Japanese Katakana
      else if (rune >= 0x30A0 && rune <= 0x30FF) {
        scores['ja'] = (scores['ja'] ?? 0) + 1;
      }
      // Korean Hangul
      else if (rune >= 0xAC00 && rune <= 0xD7AF) {
        scores['ko'] = (scores['ko'] ?? 0) + 1;
      }
      // Thai
      else if (rune >= 0x0E00 && rune <= 0x0E7F) {
        scores['th'] = (scores['th'] ?? 0) + 1;
      }
      // Devanagari (Hindi, etc.)
      else if (rune >= 0x0900 && rune <= 0x097F) {
        scores['hi'] = (scores['hi'] ?? 0) + 1;
      }
    }

    if (total == 0) {
      return DetectionResult('en', 0, DetectionMethod.unknown);
    }

    // Find dominant script
    String dominantScript = 'en';
    int maxScore = 0;
    for (final entry in scores.entries) {
      if (entry.value > maxScore) {
        maxScore = entry.value;
        dominantScript = entry.key;
      }
    }

    // Disambiguate Cyrillic languages
    if (dominantScript == 'cyrillic') {
      dominantScript = _disambiguateCyrillic(text);
    }

    // Disambiguate Latin languages
    if (dominantScript == 'latin') {
      dominantScript = _disambiguateLatin(text);
    }

    final confidence = ((maxScore / total) * 100).round();
    return DetectionResult(dominantScript, confidence, DetectionMethod.script);
  }

  /// Disambiguate between Cyrillic languages (Bulgarian, Russian, Ukrainian)
  String _disambiguateCyrillic(String text) {
    final lower = text.toLowerCase();

    // Bulgarian-specific characters and patterns
    final bgChars = RegExp(r'[ъщ][а-я]*');
    final bgWords = ['и', 'да', 'на', 'е', 'се', 'в', 'за', 'не'];

    // Ukrainian-specific characters
    final hasUkrainianI = text.contains('ї') || text.contains('і') || text.contains('ґ');

    // Russian and Ukrainian use 'ы', Bulgarian doesn't
    final hasY = text.contains('ы') || text.contains('Ы');

    // Check for Ukrainian letter i with two dots
    if (hasUkrainianI) {
      return 'uk';
    }

    // Bulgarian patterns
    if (bgChars.hasMatch(text) ||
        bgWords.any((w) => RegExp(r'\b$w\b').hasMatch(lower))) {
      return 'bg';
    }

    // Default to Russian for Cyrillic
    return 'ru';
  }

  /// Disambiguate between Latin-script languages
  String _disambiguateLatin(String text) {
    return _detectByStopwords(text).language;
  }

  /// Detect language using stopwords/common words
  DetectionResult _detectByStopwords(String text) {
    final lower = text.toLowerCase();
    final scores = <String, int>{};

    // Count matches for each language's stopwords
    for (final entry in _stopwords.entries) {
      final lang = entry.key;
      final words = entry.value;

      int matches = 0;
      for (final word in words) {
        if (lower.contains(RegExp(r'\b' + RegExp.escape(word) + r'\b'))) {
          matches++;
        }
      }

      if (matches > 0) {
        scores[lang] = matches;
      }
    }

    if (scores.isEmpty) {
      return DetectionResult('en', 0, DetectionMethod.unknown);
    }

    // Find language with most matches
    String bestLang = 'en';
    int maxScore = 0;
    for (final entry in scores.entries) {
      if (entry.value > maxScore) {
        maxScore = entry.value;
        bestLang = entry.key;
      }
    }

    // Confidence based on number of matches (more matches = higher confidence)
    final confidence = (maxScore * 20).clamp(0, 100);
    return DetectionResult(bestLang, confidence, DetectionMethod.stopwords);
  }

  /// Detect language using n-gram frequency analysis
  DetectionResult _detectByNgrams(String text) {
    final lower = text.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');
    final tokens = lower.split(RegExp(r'\s+'));

    if (tokens.length < 3) {
      return DetectionResult('en', 0, DetectionMethod.unknown);
    }

    // Generate character n-grams (3-grams)
    final ngrams = <String>[];
    for (final token in tokens) {
      if (token.length >= 3) {
        for (int i = 0; i <= token.length - 3; i++) {
          ngrams.add(token.substring(i, i + 3));
        }
      }
    }

    if (ngrams.isEmpty) {
      return DetectionResult('en', 0, DetectionMethod.unknown);
    }

    // Score each language by n-gram frequency
    final scores = <String, double>{};
    for (final lang in _ngramProfiles.keys) {
      final profile = _ngramProfiles[lang]!;
      double score = 0;
      int matches = 0;

      for (final ngram in ngrams) {
        if (profile.containsKey(ngram)) {
          score += profile[ngram]!;
          matches++;
        }
      }

      if (matches > 0) {
        scores[lang] = score / matches;
      }
    }

    if (scores.isEmpty) {
      return DetectionResult('en', 0, DetectionMethod.unknown);
    }

    // Find best scoring language
    String bestLang = 'en';
    double bestScore = 0;
    for (final entry in scores.entries) {
      if (entry.value > bestScore) {
        bestScore = entry.value;
        bestLang = entry.key;
      }
    }

    // Confidence based on how unique the n-gram profile is
    final confidence = (bestScore * 100).round().clamp(0, 100);
    return DetectionResult(bestLang, confidence, DetectionMethod.ngram);
  }

  /// Combine multiple detection results using weighted voting
  LanguageDetectionResult _combineDetectionResults(List<DetectionResult> results) {
    if (results.isEmpty) {
      return LanguageDetectionResult(
        languageCode: 'en',
        confidence: 0,
        method: DetectionMethod.unknown,
      );
    }

    // Weight each method
    final weights = {
      DetectionMethod.script: 0.3,
      DetectionMethod.stopwords: 0.4,
      DetectionMethod.ngram: 0.3,
      DetectionMethod.unknown: 0.1,
    };

    // Score each language
    final scores = <String, double>{};
    final confidences = <String, List<int>>{};

    for (final result in results) {
      final weight = weights[result.method] ?? 0.1;
      scores[result.language] = (scores[result.language] ?? 0) + weight;

      confidences.putIfAbsent(result.language, () => []).add(result.confidence);
    }

    // Find highest scoring language
    String bestLang = 'en';
    double bestScore = 0;
    for (final entry in scores.entries) {
      if (entry.value > bestScore) {
        bestScore = entry.value;
        bestLang = entry.key;
      }
    }

    // Average confidence from all methods
    final avgConfidence = confidences[bestLang]?.isEmpty ?? false
        ? 0
        : confidences[bestLang]!.reduce((a, b) => a + b) ~/ confidences[bestLang]!.length;

    // Determine most successful method
    DetectionMethod method = DetectionMethod.unknown;
    if (results.isNotEmpty) {
      // Use method with highest confidence
      final sorted = results..sort((a, b) => b.confidence.compareTo(a.confidence));
      method = sorted.first.method;
    }

    return LanguageDetectionResult(
      languageCode: bestLang,
      confidence: avgConfidence,
      method: method,
    );
  }

  /// Split text into segments by detected language
  List<TextSegment> _splitByLanguage(String text) {
    final segments = <TextSegment>[];
    final sentences = text.split(RegExp(r'[.!?]+\s+'));

    String? currentLang;
    StringBuffer currentSegment = StringBuffer();

    for (final sentence in sentences) {
      if (sentence.trim().isEmpty) continue;

      // Quick detection for this sentence
      final detected = _detectByScript(sentence);

      if (currentLang == null) {
        currentLang = detected.language;
        currentSegment.write(sentence);
      } else if (detected.language == currentLang) {
        currentSegment.write(' $sentence');
      } else {
        // Language changed
        if (currentSegment.isNotEmpty) {
          segments.add(TextSegment(currentSegment.toString(), currentLang!));
        }
        currentLang = detected.language;
        currentSegment = StringBuffer()..write(sentence);
      }
    }

    // Add final segment
    if (currentSegment.isNotEmpty) {
      segments.add(TextSegment(currentSegment.toString(), currentLang ?? 'en'));
    }

    return segments;
  }

  /// Merge mixed language results for same language
  List<MixedLanguageResult> _mergeMixedResults(List<MixedLanguageResult> results) {
    final merged = <String, MixedLanguageResult>{};

    for (final result in results) {
      final existing = merged[result.languageCode];
      if (existing != null) {
        merged[result.languageCode] = MixedLanguageResult(
          languageCode: result.languageCode,
          confidence: (existing.confidence + result.confidence) ~/ 2,
          proportion: existing.proportion + result.proportion,
          textSample: existing.textSample,
        );
      } else {
        merged[result.languageCode] = result;
      }
    }

    // Sort by proportion
    final sorted = merged.values.toList()
      ..sort((a, b) => b.proportion.compareTo(a.proportion));

    return sorted;
  }

  /// Clear detection cache
  Future<void> clearCache() async {
    await _cacheBox.clear();
    _componentName.logInfo('Language detection cache cleared');
  }

  /// Get cache statistics
  Map<String, dynamic> getCacheStats() {
    return {
      'size': _cacheBox.length,
      'maxSize': _cacheSize,
      'usagePercent': (_cacheBox.length / _cacheSize * 100).round(),
    };
  }

  /// Close the service
  Future<void> close() async {
    await _cacheBox.close();
    _isInitialized = false;
    _componentName.logInfo('Language detection service closed');
  }

  // ========== Stopwords for common languages ==========
  static const Map<String, List<String>> _stopwords = {
    'en': [
      'the', 'be', 'to', 'of', 'and', 'a', 'in', 'that', 'have', 'i',
      'it', 'for', 'not', 'on', 'with', 'he', 'as', 'you', 'do', 'at',
    ],
    'es': [
      'el', 'la', 'de', 'que', 'y', 'a', 'en', 'un', 'ser', 'se',
      'no', 'haber', 'con', 'su', 'por', 'le', 'para', 'como', 'estar',
    ],
    'fr': [
      'le', 'de', 'un', 'être', 'et', 'à', 'il', 'avoir', 'ne', 'je',
      'son', 'que', 'se', 'qui', 'dans', 'ce', 'pour', 'pas', 'plus',
      'nous', 'vous', 'sont', 'très', 'cette', 'avec', 'mais', 'oui',
      'encore', 'aussi', 'beaucoup', 'toujours', 'jamais',
      'bien', 'fait', 'aussi', 'entre', 'sans', 'alors', 'peut',
    ],
    'de': [
      'der', 'die', 'und', 'in', 'den', 'von', 'zu', 'das', 'mit', 'sich',
      'des', 'sein', 'dass', 'er', 'es', 'ein', 'auf', 'für',
    ],
    'it': [
      'il', 'di', 'che', 'e', 'la', 'un', 'a', 'per', 'non', 'in',
      'una', 'si', 'è', 'da', 'del', 'lo', 'qua',
      'siamo', 'nostro', 'molto', 'oggi', 'questo', 'questa', 'ancora',
      'sempre', 'anche', 'bene', 'proprio', 'giorno', 'notte',
    ],
    'pt': [
      'o', 'de', 'a', 'e', 'do', 'da', 'em', 'um', 'para', 'é',
      'com', 'não', 'uma', 'os', 'no', 'se', 'na', 'por',
      'nós', 'nosso', 'muito', 'hoje', 'este', 'esta', 'ainda',
      'sempre', 'também', 'bem', 'então', 'dia', 'noite',
    ],
    'ru': [
      'и', 'в', 'не', 'на', 'я', 'быть', 'он', 'с', 'что', 'а',
      'по', 'это', 'она', 'оно', 'который', 'это', 'то', 'они', 'мы',
    ],
    'bg': [
      'и', 'в', 'не', 'на', 'се', 'да', 'е', 'че', 'за', 'ще',
      'с', 'ъ', 'а', 'се', 'от', 'как', 'са',
    ],
    'uk': [
      'і', 'в', 'не', 'на', 'що', 'я', 'це', 'з', 'бути', 'а',
      'до', 'або', 'у', 'що', 'його', 'вона',
    ],
    'nl': [
      'de', 'van', 'een', 'het', 'in', 'zijn', 'dat', 'hij', 'niet', 'op',
      'zijn', 'met', 'als', 'voor', 'was',
    ],
    'pl': [
      'w', 'nie', 'z', 'na', 'i', 'do', 'że', 'a', 'jest', 'się',
      'od', 'z', 'to', 'co', 'o', 'jako',
    ],
    'tr': [
      've', 'bir', 'bu', 'olan', 'var', 'için', 'ama', 'ile', 'daha', 'yok',
      'kadar', 'ya', 'her', 'ne', 'diye',
    ],
    'sv': [
      'och', 'att', 'det', 'i', 'en', 'av', 'på', 'är', 'som', 'med',
      'för', 'inte', 'har', 'till', 'den',
    ],
    'da': [
      'og', 'i', 'det', 'at', 'en', 'er', 'som', 'til', 'på', 'for',
      'med', 'ikke', 'der', 'var', 'af',
    ],
    'no': [
      'og', 'i', 'det', 'att', 'en', 'er', 'som', 'til', 'på', 'for',
      'med', 'ikke', 'der', 'var', 'av',
    ],
    'fi': [
      'ja', 'on', 'se', 'että', 'ole', 'ei', 'hänen', 'hänet', 'ei', 'jo',
      'olen', 'sinä', 'hän', 'me', 'te', 'he',
    ],
    'cs': [
      'a', 'se', 'na', 've', 'v', 'že', 'si', 'z', 'do', 'je',
      'ten', 's', 'tomu', 'jako',
    ],
    'el': [
      'και', 'το', 'να', 'είμαι', 'σε', 'ότι', 'μία', 'είναι', 'έχω', 'μη',
      'αυτό', 'των', 'των', 'πως', 'το', 'αυτός',
    ],
    'ro': [
      'și', 'să', 'nu', 'se', 'în', 'un', 'am', 'că', 'de', 'este',
      'la', 'care', 'mai', 'a', 'pentru',
    ],
    'hu': [
      'a', 'és', 'nem', 'az', 'hogy', 'van', 'egy', 'a', 'nem', 'benne',
      'lek', 'mint', 'mi', 'meg', 'már',
    ],
    'id': [
      'dan', 'di', 'ke', 'yang', 'adalah', 'ada', 'itu', 'untuk', 'dengan', 'tidak',
      'ini', 'juga', 'orang', 'bisa', 'karena',
    ],
    'vi': [
      'và', 'của', 'là', 'một', 'những', 'được', 'có', 'không', 'đã',
      'cho', 'với', 'này', 'đó', 'rất', 'cũng', 'về', 'từ',
      'chúng', 'muốn', 'biết', 'đi', 'làm', 'như', 'nhiều',
      'trong', 'của', 'nhưng', 'mà', 'những', 'các', 'phải', 'nếu',
    ],
    'th': [
      'และ', 'ของ', 'ใน', 'ที่', 'เป็น', 'เขา', 'กับ', 'เป็น', 'ที่จะ',
      'ดังนั้น', 'นี้', 'นั้น', 'แรก', 'ได้',
    ],
  };

  // ========== N-gram profiles for languages ==========
  // Simplified profiles using common character trigrams
  static const Map<String, Map<String, double>> _ngramProfiles = {
    'en': {
      'the': 0.05, 'ing': 0.04, 'and': 0.03, 'ion': 0.02, 'ent': 0.02,
      'for': 0.02, 'hat': 0.02, 'her': 0.02, 'ere': 0.01, 'ate': 0.01,
    },
    'es': {
      'que': 0.05, 'del': 0.04, 'ado': 0.03, 'los': 0.03, 'ión': 0.02,
      'por': 0.02, 'para': 0.02, 'con': 0.02, 'est': 0.02, 'aci': 0.01,
    },
    'fr': {
      'que': 0.04, 'ent': 0.03, 'eme': 0.02, 'ait': 0.02, 'les': 0.02,
      'des': 0.02, 'pour': 0.02, 'dan': 0.02, 'ave': 0.01, 'men': 0.01,
    },
    'de': {
      'der': 0.04, 'die': 0.04, 'che': 0.03, 'den': 0.02, 'ich': 0.02,
      'ein': 0.02, 'sch': 0.02, 'und': 0.02, 'ten': 0.01, 'gen': 0.01,
    },
    'it': {
      'che': 0.04, 'per': 0.03, 'del': 0.02, 'nte': 0.02, 'll': 0.02,
      'tion': 0.02, 'con': 0.02, ' Italian': 0.01, 'are': 0.01, 'zon': 0.01,
    },
    'pt': {
      'que': 0.04, 'ent': 0.03, 'ado': 0.02, 'nte': 0.02, 'con': 0.02,
      'par': 0.02, 'est': 0.02, 'ara': 0.01, 'são': 0.01, 'çã': 0.01,
    },
  };
}

/// Result of language detection with confidence
class LanguageDetectionResult {
  final String languageCode;
  final int confidence; // 0-100
  final DetectionMethod method;

  const LanguageDetectionResult({
    required this.languageCode,
    required this.confidence,
    required this.method,
  });

  @override
  String toString() => 'LanguageDetectionResult($languageCode, confidence: $confidence%, method: $method)';
}

/// Internal detection result
class DetectionResult {
  final String language;
  final int confidence;
  final DetectionMethod method;

  DetectionResult(this.language, this.confidence, this.method);
}

/// Method used for detection
enum DetectionMethod {
  script,
  stopwords,
  ngram,
  default_,
  unknown,
}

/// Result for mixed language text
class MixedLanguageResult {
  final String languageCode;
  final int confidence;
  final double proportion; // 0.0 to 1.0
  final String textSample;

  const MixedLanguageResult({
    required this.languageCode,
    required this.confidence,
    required this.proportion,
    required this.textSample,
  });

  @override
  String toString() => 'MixedLanguageResult($languageCode, ${(proportion * 100).toStringAsFixed(1)}%, confidence: $confidence)';
}

/// Text segment with language
class TextSegment {
  final String text;
  final String language;

  TextSegment(this.text, this.language);
}

/// Extension for clamping integers
extension ClampInt on int {
  int clamp(int min, int max) {
    if (this < min) return min;
    if (this > max) return max;
    return this;
  }
}
