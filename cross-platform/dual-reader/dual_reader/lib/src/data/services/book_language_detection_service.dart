import 'package:dual_reader/src/data/services/language_detection_service.dart';
import 'package:dual_reader/src/domain/entities/book_entity.dart';
import 'package:dual_reader/src/domain/repositories/book_repository.dart';
import 'package:dual_reader/src/core/utils/logging_service.dart';

/// Service for detecting and caching language information for books.
///
/// This service integrates language detection with the book entity,
/// allowing:
/// - Per-book language detection caching
/// - Reuse of detection across pages
/// - Confidence-based fallback
/// - User override capability
class BookLanguageDetectionService {
  static const String _componentName = 'BookLanguageDetection';
  static const int _defaultMinConfidence = 50;
  static const int _cacheValidityDays = 7;

  final BookRepository _bookRepository;
  final LanguageDetectionService _languageDetectionService;

  BookLanguageDetectionService({
    required BookRepository bookRepository,
    LanguageDetectionService? languageDetectionService,
  })  : _bookRepository = bookRepository,
        _languageDetectionService = languageDetectionService ?? LanguageDetectionService.instance;

  /// Detect language for a book's text.
  ///
  /// This method:
  /// 1. Checks if book already has a recent, high-confidence detection
  /// 2. If not, performs new detection
  /// 3. Caches result in book entity
  ///
  /// Returns the detected language code.
  Future<String> detectLanguageForBook(
    BookEntity book, {
    required String sampleText,
    int minConfidence = _defaultMinConfidence,
    String? userOverride,
  }) async {
    // If user provided explicit override, use it
    if (userOverride != null && userOverride.isNotEmpty) {
      _componentName.logInfo('Using user-specified language override: $userOverride');
      await _updateBookLanguage(book, userOverride, 100);
      return userOverride;
    }

    // Check if book already has a recent, high-confidence detection
    if (book.hasLanguageDetection(minConfidence) && book.hasRecentLanguageDetection()) {
      _componentName.logInfo(
        'Using cached language detection: ${book.detectedLanguage} '
        '(${book.languageDetectionConfidence}% confidence, '
        '${DateTime.now().difference(book.languageDetectionDate!).inDays} days old)'
      );
      return book.detectedLanguage!;
    }

    // Perform new detection
    _componentName.logInfo('Detecting language for book "${book.title}"');
    final result = await _languageDetectionService.detectWithConfidence(sampleText);

    _componentName.logInfo(
      'Language detected: ${result.languageCode} '
      '(${result.confidence}% confidence, method: ${result.method})'
    );

    // Update book with detection result
    await _updateBookLanguage(book, result.languageCode, result.confidence);

    // Return detected language, or fallback if confidence is too low
    if (result.confidence < minConfidence) {
      _componentName.logWarning(
        'Low confidence detection (${result.confidence}% < ${minConfidence}%), '
        'recommending user confirmation'
      );
    }

    return result.languageCode;
  }

  /// Detect language for a page, using book-level cached detection if available.
  Future<String> detectLanguageForPage(
    BookEntity book, {
    required String pageText,
    int minConfidence = _defaultMinConfidence,
    String? userOverride,
  }) async {
    // If user provided explicit override, use it
    if (userOverride != null && userOverride.isNotEmpty) {
      return userOverride;
    }

    // Check if book has cached detection
    if (book.hasLanguageDetection(minConfidence) && book.hasRecentLanguageDetection()) {
      _componentName.logDebug('Using book-level cached language: ${book.detectedLanguage}');
      return book.detectedLanguage!;
    }

    // Detect from this page and cache it for the book
    return await detectLanguageForBook(
      book,
      sampleText: pageText,
      minConfidence: minConfidence,
    );
  }

  /// Detect mixed languages in text and return translation units.
  ///
  /// This method:
  /// 1. Detects all languages present in the text
  /// 2. Creates translation units that exclude the target language
  /// 3. Marks language boundaries
  ///
  /// Returns a list of translation units with language information.
  Future<List<TranslationLanguageUnit>> detectMixedLanguagesForTranslation(
    String text,
    String targetLanguage, {
    int minConfidence = _defaultMinConfidence,
  }) async {
    final detections = await _languageDetectionService.detectMixedLanguages(text);

    if (detections.isEmpty) {
      // Assume all text needs translation
      return [TranslationLanguageUnit(
        text: text,
        detectedLanguage: null,
        confidence: 0,
        needsTranslation: true,
        startIndex: 0,
        endIndex: text.length,
      )];
    }

    final units = <TranslationLanguageUnit>[];
    int currentIndex = 0;

    // Split text by detected language segments
    final segments = await _splitTextByLanguageDetections(text, detections);

    for (final segment in segments) {
      final needsTranslation = segment.languageCode != targetLanguage &&
          (segment.confidence ?? 0) >= minConfidence;

      units.add(TranslationLanguageUnit(
        text: segment.text,
        detectedLanguage: segment.languageCode,
        confidence: segment.confidence ?? 0,
        needsTranslation: needsTranslation,
        startIndex: segment.startIndex,
        endIndex: segment.endIndex,
        isMixed: segment.isMixed,
      ));

      currentIndex += segment.text.length;
    }

    return units;
  }

  /// Update book entity with language detection result.
  Future<void> _updateBookLanguage(
    BookEntity book,
    String languageCode,
    int confidence,
  ) async {
    try {
      final updatedBook = book.copyWith(
        detectedLanguage: languageCode,
        languageDetectionConfidence: confidence,
        languageDetectionDate: DateTime.now(),
      );

      await _bookRepository.updateBook(updatedBook);
      _componentName.logInfo('Updated book "${book.title}" with language: $languageCode ($confidence%)');
    } catch (e) {
      _componentName.logError('Failed to update book language detection', error: e);
      // Don't throw - translation can continue without caching
    }
  }

  /// Split text into segments based on detected languages.
  Future<List<TextLanguageSegment>> _splitTextByLanguageDetections(
    String text,
    List<MixedLanguageResult> detections,
  ) async {
    final segments = <TextLanguageSegment>[];

    if (detections.length == 1) {
      // Single language detected
      segments.add(TextLanguageSegment(
        text: text,
        languageCode: detections.first.languageCode,
        confidence: detections.first.confidence,
        startIndex: 0,
        endIndex: text.length,
        isMixed: false,
      ));
      return segments;
    }

    // Multiple languages - split by sentence boundaries
    final sentences = text.split(RegExp(r'(?<=[.!?])\s+'));
    int currentIndex = 0;

    for (final sentence in sentences) {
      if (sentence.isEmpty) continue;

      // Detect language for this sentence
      final result = await _languageDetectionService.detectWithConfidence(sentence);

      segments.add(TextLanguageSegment(
        text: sentence,
        languageCode: result.languageCode,
        confidence: result.confidence,
        startIndex: currentIndex,
        endIndex: currentIndex + sentence.length,
        isMixed: true,
      ));

      currentIndex += sentence.length + 1; // +1 for space
    }

    return segments;
  }

  /// Clear language detection for a book.
  Future<void> clearDetection(BookEntity book) async {
    try {
      final updatedBook = book.copyWith(clearLanguageDetection: true);
      await _bookRepository.updateBook(updatedBook);
      _componentName.logInfo('Cleared language detection for book "${book.title}"');
    } catch (e) {
      _componentName.logError('Failed to clear language detection', error: e);
    }
  }

  /// Get detection statistics for a book.
  BookDetectionStats getDetectionStats(BookEntity book) {
    return BookDetectionStats(
      detectedLanguage: book.detectedLanguage,
      confidence: book.languageDetectionConfidence,
      detectionDate: book.languageDetectionDate,
      isRecent: book.hasRecentLanguageDetection(),
      isReliable: book.hasLanguageDetection(_defaultMinConfidence),
    );
  }

  /// Recommend confirmation to user based on detection confidence.
  bool shouldRecommendUserConfirmation(BookEntity book) {
    return !book.hasLanguageDetection(_defaultMinConfidence) ||
        !book.hasRecentLanguageDetection();
  }
}

/// Represents a text segment with language information for translation.
class TranslationLanguageUnit {
  final String text;
  final String? detectedLanguage;
  final int confidence;
  final bool needsTranslation;
  final int startIndex;
  final int endIndex;
  final bool isMixed;

  const TranslationLanguageUnit({
    required this.text,
    required this.detectedLanguage,
    required this.confidence,
    required this.needsTranslation,
    required this.startIndex,
    required this.endIndex,
    this.isMixed = false,
  });

  @override
  String toString() => 'TranslationUnit('
      'lang: $detectedLanguage, '
      'confidence: $confidence%, '
      'needsTranslation: $needsTranslation, '
      'length: ${text.length})';
}

/// Internal text segment with language info.
class TextLanguageSegment {
  final String text;
  final String languageCode;
  final int confidence;
  final int startIndex;
  final int endIndex;
  final bool isMixed;

  const TextLanguageSegment({
    required this.text,
    required this.languageCode,
    required this.confidence,
    required this.startIndex,
    required this.endIndex,
    required this.isMixed,
  });
}

/// Statistics about book language detection.
class BookDetectionStats {
  final String? detectedLanguage;
  final int? confidence;
  final DateTime? detectionDate;
  final bool isRecent;
  final bool isReliable;

  const BookDetectionStats({
    required this.detectedLanguage,
    required this.confidence,
    required this.detectionDate,
    required this.isRecent,
    required this.isReliable,
  });

  @override
  String toString() => 'BookDetectionStats('
      'language: $detectedLanguage, '
      'confidence: $confidence%, '
      'recent: $isRecent, '
      'reliable: $isReliable)';
}
