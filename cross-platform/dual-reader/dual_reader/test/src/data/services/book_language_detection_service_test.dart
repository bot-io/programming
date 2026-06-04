import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:dual_reader/src/data/services/book_language_detection_service.dart';
import 'package:dual_reader/src/data/services/language_detection_service.dart';
import 'package:dual_reader/src/domain/entities/book_entity.dart';
import 'package:dual_reader/src/domain/repositories/book_repository.dart';

// Generate mocks with: flutter pub run build_runner build --delete-conflicting-outputs
@GenerateMocks([
  BookRepository,
  LanguageDetectionService,
])
import 'book_language_detection_service_test.mocks.dart';

/// Tests for BookLanguageDetectionService.
///
/// Test coverage:
/// - Per-book language detection caching
/// - Reuse of detection across pages
/// - Confidence-based fallback
/// - User override capability
/// - Mixed language text handling
/// - Clearing cached detection
/// - Detection statistics
void main() {
  group('BookLanguageDetectionService', () {
    late BookLanguageDetectionService service;
    late MockBookRepository mockBookRepository;
    late MockLanguageDetectionService mockDetectionService;
    late BookEntity testBook;

    setUp(() {
      mockBookRepository = MockBookRepository();
      mockDetectionService = MockLanguageDetectionService();
      service = BookLanguageDetectionService(
        bookRepository: mockBookRepository,
        languageDetectionService: mockDetectionService,
      );

      testBook = BookEntity(
        id: 'test-book-id',
        title: 'Test Book',
        author: 'Test Author',
        coverPath: '/covers/test.jpg',
        filePath: '/books/test.epub',
        importedDate: DateTime.now(),
      );
    });

    group('Language Detection for Books', () {
      test('should detect language and cache in book entity', () async {
        const sampleText = 'This is a sample text in English for testing.';
        const detectedLanguage = 'en';
        const confidence = 95;

        when(mockDetectionService.detectWithConfidence(any))
            .thenAnswer((_) async => LanguageDetectionResult(
                  languageCode: detectedLanguage,
                  confidence: confidence,
                  method: DetectionMethod.script,
                ));
        when(mockBookRepository.updateBook(any)).thenAnswer((_) async {});

        final result = await service.detectLanguageForBook(
          testBook,
          sampleText: sampleText,
        );

        expect(result, equals(detectedLanguage));
        verify(mockDetectionService.detectWithConfidence(sampleText)).called(1);
        verify(mockBookRepository.updateBook(argThat(
          allOf(
            predicate((BookEntity b) => b.detectedLanguage == detectedLanguage),
            predicate((BookEntity b) => b.languageDetectionConfidence == confidence),
            predicate((BookEntity b) => b.languageDetectionDate != null),
          ),
        ))).called(1);
      });

      test('should use cached detection if recent and high confidence', () async {
        const cachedLanguage = 'es';
        const cachedConfidence = 90;

        final cachedBook = testBook.copyWith(
          detectedLanguage: cachedLanguage,
          languageDetectionConfidence: cachedConfidence,
          languageDetectionDate: DateTime.now(),
        );

        final result = await service.detectLanguageForBook(
          cachedBook,
          sampleText: 'Any text',
        );

        expect(result, equals(cachedLanguage));
        verifyNever(mockDetectionService.detectWithConfidence(any));
        verifyNever(mockBookRepository.updateBook(any));
      });

      test('should re-detect if cached detection is old (more than 7 days)', () async {
        const newLanguage = 'fr';
        const oldLanguage = 'es';

        final oldBook = testBook.copyWith(
          detectedLanguage: oldLanguage,
          languageDetectionConfidence: 90,
          languageDetectionDate: DateTime.now().subtract(const Duration(days: 8)),
        );

        when(mockDetectionService.detectWithConfidence(any))
            .thenAnswer((_) async => LanguageDetectionResult(
                  languageCode: newLanguage,
                  confidence: 85,
                  method: DetectionMethod.stopwords,
                ));
        when(mockBookRepository.updateBook(any)).thenAnswer((_) async {});

        final result = await service.detectLanguageForBook(
          oldBook,
          sampleText: 'Sample text',
        );

        expect(result, equals(newLanguage));
        verify(mockDetectionService.detectWithConfidence(any)).called(1);
      });

      test('should re-detect if cached confidence is below threshold', () async {
        const newLanguage = 'de';
        const lowConfidence = 30;
        const minConfidence = 50;

        final lowConfidenceBook = testBook.copyWith(
          detectedLanguage: 'en',
          languageDetectionConfidence: lowConfidence,
          languageDetectionDate: DateTime.now(),
        );

        when(mockDetectionService.detectWithConfidence(any))
            .thenAnswer((_) async => LanguageDetectionResult(
                  languageCode: newLanguage,
                  confidence: 85,
                  method: DetectionMethod.stopwords,
                ));
        when(mockBookRepository.updateBook(any)).thenAnswer((_) async {});

        final result = await service.detectLanguageForBook(
          lowConfidenceBook,
          sampleText: 'Sample text',
          minConfidence: minConfidence,
        );

        expect(result, equals(newLanguage));
        verify(mockDetectionService.detectWithConfidence(any)).called(1);
      });
    });

    group('User Override', () {
      test('should use user-provided language override', () async {
        const userOverride = 'es';
        when(mockBookRepository.updateBook(any)).thenAnswer((_) async {});

        final result = await service.detectLanguageForBook(
          testBook,
          sampleText: 'English text',
          userOverride: userOverride,
        );

        expect(result, equals(userOverride));
        verifyNever(mockDetectionService.detectWithConfidence(any));
        verify(mockBookRepository.updateBook(argThat(
          predicate((BookEntity b) => b.detectedLanguage == userOverride),
        ))).called(1);
      });

      test('should prioritize override over cached detection', () async {
        const cachedLanguage = 'en';
        const userOverride = 'fr';

        final cachedBook = testBook.copyWith(
          detectedLanguage: cachedLanguage,
          languageDetectionConfidence: 95,
          languageDetectionDate: DateTime.now(),
        );

        final result = await service.detectLanguageForBook(
          cachedBook,
          sampleText: 'Any text',
          userOverride: userOverride,
        );

        expect(result, equals(userOverride));
      });

      test('should use override for page detection', () async {
        const userOverride = 'de';

        final result = await service.detectLanguageForPage(
          testBook,
          pageText: 'English text',
          userOverride: userOverride,
        );

        expect(result, equals(userOverride));
        verifyNever(mockDetectionService.detectWithConfidence(any));
      });
    });

    group('Page-Level Detection', () {
      test('should use book-level cached detection for pages', () async {
        const cachedLanguage = 'es';

        final cachedBook = testBook.copyWith(
          detectedLanguage: cachedLanguage,
          languageDetectionConfidence: 90,
          languageDetectionDate: DateTime.now(),
        );

        final result = await service.detectLanguageForPage(
          cachedBook,
          pageText: 'Page text content',
        );

        expect(result, equals(cachedLanguage));
        verifyNever(mockDetectionService.detectWithConfidence(any));
      });

      test('should detect language for page if book has no cache', () async {
        const detectedLanguage = 'fr';

        when(mockDetectionService.detectWithConfidence(any))
            .thenAnswer((_) async => LanguageDetectionResult(
                  languageCode: detectedLanguage,
                  confidence: 85,
                  method: DetectionMethod.stopwords,
                ));
        when(mockBookRepository.updateBook(any)).thenAnswer((_) async {});

        final result = await service.detectLanguageForPage(
          testBook,
          pageText: 'Page content in French',
        );

        expect(result, equals(detectedLanguage));
        verify(mockDetectionService.detectWithConfidence(any)).called(1);
      });
    });

    group('Mixed Language Detection', () {
      test('should detect mixed languages in text', () async {
        const text = 'Hello world! ¿Cómo estás? I am fine. Merci beaucoup!';
        const targetLanguage = 'en';

        final detections = [
          MixedLanguageResult(
            languageCode: 'en',
            confidence: 90,
            proportion: 0.5,
            textSample: 'Hello world',
          ),
          MixedLanguageResult(
            languageCode: 'es',
            confidence: 85,
            proportion: 0.25,
            textSample: '¿Cómo estás?',
          ),
          MixedLanguageResult(
            languageCode: 'fr',
            confidence: 80,
            proportion: 0.25,
            textSample: 'Merci beaucoup',
          ),
        ];

        when(mockDetectionService.detectMixedLanguages(any))
            .thenAnswer((_) async => detections);
        // _splitTextByLanguageDetections calls detectWithConfidence for each sentence
        when(mockDetectionService.detectWithConfidence(any))
            .thenAnswer((invocation) async {
              final text = invocation.positionalArguments[0] as String;
              if (text.contains('Hello')) {
                return LanguageDetectionResult(languageCode: 'en', confidence: 90, method: DetectionMethod.script);
              } else if (text.contains('Cóm')) {
                return LanguageDetectionResult(languageCode: 'es', confidence: 85, method: DetectionMethod.script);
              } else if (text.contains('fine')) {
                return LanguageDetectionResult(languageCode: 'en', confidence: 90, method: DetectionMethod.script);
              } else if (text.contains('Merci')) {
                return LanguageDetectionResult(languageCode: 'fr', confidence: 80, method: DetectionMethod.script);
              }
              return LanguageDetectionResult(languageCode: 'en', confidence: 50, method: DetectionMethod.unknown);
            });

        final units = await service.detectMixedLanguagesForTranslation(
          text,
          targetLanguage,
        );

        expect(units, hasLength(4));

        // English segments should not need translation
        final englishUnits = units.where((u) => u.detectedLanguage == 'en');
        for (final unit in englishUnits) {
          expect(unit.needsTranslation, isFalse);
        }

        // Spanish should need translation
        final spanishUnit = units.firstWhere((u) => u.detectedLanguage == 'es');
        expect(spanishUnit.needsTranslation, isTrue);

        // French should need translation
        final frenchUnit = units.firstWhere((u) => u.detectedLanguage == 'fr');
        expect(frenchUnit.needsTranslation, isTrue);
      });

      test('should mark all text as needing translation if single language', () async {
        const text = 'Hello world! How are you today?';
        const targetLanguage = 'es';

        final detections = [
          MixedLanguageResult(
            languageCode: 'en',
            confidence: 95,
            proportion: 1.0,
            textSample: 'Hello world',
          ),
        ];

        when(mockDetectionService.detectMixedLanguages(any))
            .thenAnswer((_) async => detections);

        final units = await service.detectMixedLanguagesForTranslation(
          text,
          targetLanguage,
        );

        expect(units, hasLength(1));
        expect(units.first.needsTranslation, isTrue);
        expect(units.first.detectedLanguage, equals('en'));
      });

      test('should handle empty detection results', () async {
        const text = 'Some text';
        const targetLanguage = 'es';

        when(mockDetectionService.detectMixedLanguages(any))
            .thenAnswer((_) async => []);

        final units = await service.detectMixedLanguagesForTranslation(
          text,
          targetLanguage,
        );

        expect(units, hasLength(1));
        expect(units.first.needsTranslation, isTrue);
        expect(units.first.text, equals(text));
      });
    });

    group('Clear Detection', () {
      test('should clear language detection from book', () async {
        final detectedBook = testBook.copyWith(
          detectedLanguage: 'en',
          languageDetectionConfidence: 90,
          languageDetectionDate: DateTime.now(),
        );

        when(mockBookRepository.updateBook(any)).thenAnswer((_) async {});

        await service.clearDetection(detectedBook);

        verify(mockBookRepository.updateBook(argThat(
          allOf(
            predicate((BookEntity b) => b.detectedLanguage == null),
            predicate((BookEntity b) => b.languageDetectionConfidence == null),
            predicate((BookEntity b) => b.languageDetectionDate == null),
          ),
        ))).called(1);
      });
    });

    group('Detection Statistics', () {
      test('should provide detection statistics', () async {
        final bookWithDetection = testBook.copyWith(
          detectedLanguage: 'es',
          languageDetectionConfidence: 85,
          languageDetectionDate: DateTime.now(),
        );

        final stats = service.getDetectionStats(bookWithDetection);

        expect(stats.detectedLanguage, equals('es'));
        expect(stats.confidence, equals(85));
        expect(stats.detectionDate, isNotNull);
        expect(stats.isRecent, isTrue);
        expect(stats.isReliable, isTrue);
      });

      test('should indicate unreliable detection for low confidence', () async {
        final lowConfidenceBook = testBook.copyWith(
          detectedLanguage: 'en',
          languageDetectionConfidence: 30,
          languageDetectionDate: DateTime.now(),
        );

        final stats = service.getDetectionStats(lowConfidenceBook);

        expect(stats.isReliable, isFalse);
      });

      test('should indicate old detection', () async {
        final oldDetectionBook = testBook.copyWith(
          detectedLanguage: 'fr',
          languageDetectionConfidence: 90,
          languageDetectionDate: DateTime.now().subtract(const Duration(days: 10)),
        );

        final stats = service.getDetectionStats(oldDetectionBook);

        expect(stats.isRecent, isFalse);
      });

      test('should recommend confirmation for low confidence', () async {
        final lowConfidenceBook = testBook.copyWith(
          detectedLanguage: 'en',
          languageDetectionConfidence: 30,
          languageDetectionDate: DateTime.now(),
        );

        final shouldConfirm = service.shouldRecommendUserConfirmation(lowConfidenceBook);

        expect(shouldConfirm, isTrue);
      });

      test('should recommend confirmation for old detection', () async {
        final oldDetectionBook = testBook.copyWith(
          detectedLanguage: 'es',
          languageDetectionConfidence: 90,
          languageDetectionDate: DateTime.now().subtract(const Duration(days: 10)),
        );

        final shouldConfirm = service.shouldRecommendUserConfirmation(oldDetectionBook);

        expect(shouldConfirm, isTrue);
      });

      test('should not recommend confirmation for recent high confidence', () async {
        final reliableBook = testBook.copyWith(
          detectedLanguage: 'de',
          languageDetectionConfidence: 95,
          languageDetectionDate: DateTime.now(),
        );

        final shouldConfirm = service.shouldRecommendUserConfirmation(reliableBook);

        expect(shouldConfirm, isFalse);
      });
    });

    group('Edge Cases', () {
      test('should handle empty sample text', () async {
        when(mockDetectionService.detectWithConfidence(any))
            .thenAnswer((_) async => LanguageDetectionResult(
                  languageCode: 'en',
                  confidence: 0,
                  method: DetectionMethod.unknown,
                ));
        when(mockBookRepository.updateBook(any)).thenAnswer((_) async {});

        final result = await service.detectLanguageForBook(
          testBook,
          sampleText: '',
        );

        expect(result, isNotEmpty);
        verify(mockDetectionService.detectWithConfidence('')).called(1);
      });

      test('should handle repository update errors gracefully', () async {
        when(mockDetectionService.detectWithConfidence(any))
            .thenAnswer((_) async => LanguageDetectionResult(
                  languageCode: 'en',
                  confidence: 90,
                  method: DetectionMethod.script,
                ));
        when(mockBookRepository.updateBook(any))
            .thenThrow(Exception('Database error'));

        // Should not throw even if update fails
        final result = await service.detectLanguageForBook(
          testBook,
          sampleText: 'Sample text',
        );

        expect(result, equals('en'));
      });

      test('should handle book with no language detection', () async {
        final stats = service.getDetectionStats(testBook);

        expect(stats.detectedLanguage, isNull);
        expect(stats.confidence, isNull);
        expect(stats.detectionDate, isNull);
        expect(stats.isRecent, isFalse);
        expect(stats.isReliable, isFalse);
      });

      test('should recommend confirmation for book with no detection', () async {
        final shouldConfirm = service.shouldRecommendUserConfirmation(testBook);
        expect(shouldConfirm, isTrue);
      });
    });

    group('TranslationLanguageUnit', () {
      test('should create valid translation unit', () {
        const unit = TranslationLanguageUnit(
          text: 'Hello world',
          detectedLanguage: 'en',
          confidence: 95,
          needsTranslation: true,
          startIndex: 0,
          endIndex: 11,
        );

        expect(unit.text, equals('Hello world'));
        expect(unit.detectedLanguage, equals('en'));
        expect(unit.confidence, equals(95));
        expect(unit.needsTranslation, isTrue);
        expect(unit.isMixed, isFalse);
      });

      test('should create mixed language unit', () {
        const unit = TranslationLanguageUnit(
          text: 'Hola mundo',
          detectedLanguage: 'es',
          confidence: 90,
          needsTranslation: false,
          startIndex: 0,
          endIndex: 10,
          isMixed: true,
        );

        expect(unit.isMixed, isTrue);
        expect(unit.needsTranslation, isFalse);
      });

      test('should handle unit with null detected language', () {
        const unit = TranslationLanguageUnit(
          text: 'Unknown text',
          detectedLanguage: null,
          confidence: 0,
          needsTranslation: true,
          startIndex: 0,
          endIndex: 12,
        );

        expect(unit.detectedLanguage, isNull);
        expect(unit.confidence, equals(0));
      });
    });
  });

  group('BookEntity Language Detection Extensions', () {
    group('hasLanguageDetection', () {
      test('should return true when detection exists and meets threshold', () {
        final book = BookEntity(
          id: 'test',
          title: 'Test',
          author: 'Author',
          coverPath: '',
          filePath: '',
          importedDate: DateTime.now(),
          detectedLanguage: 'en',
          languageDetectionConfidence: 75,
        );

        expect(book.hasLanguageDetection(minConfidence: 50), isTrue);
        expect(book.hasLanguageDetection(minConfidence: 80), isFalse);
      });

      test('should return false when no detection', () {
        final book = BookEntity(
          id: 'test',
          title: 'Test',
          author: 'Author',
          coverPath: '',
          filePath: '',
          importedDate: DateTime.now(),
        );

        expect(book.hasLanguageDetection(), isFalse);
      });

      test('should return false when confidence is null', () {
        final book = BookEntity(
          id: 'test',
          title: 'Test',
          author: 'Author',
          coverPath: '',
          filePath: '',
          importedDate: DateTime.now(),
          detectedLanguage: 'en',
        );

        expect(book.hasLanguageDetection(), isFalse);
      });

      test('should return false when language is null', () {
        final book = BookEntity(
          id: 'test',
          title: 'Test',
          author: 'Author',
          coverPath: '',
          filePath: '',
          importedDate: DateTime.now(),
          languageDetectionConfidence: 90,
        );

        expect(book.hasLanguageDetection(), isFalse);
      });

      test('should return false when language is empty', () {
        final book = BookEntity(
          id: 'test',
          title: 'Test',
          author: 'Author',
          coverPath: '',
          filePath: '',
          importedDate: DateTime.now(),
          detectedLanguage: '',
          languageDetectionConfidence: 90,
        );

        expect(book.hasLanguageDetection(), isFalse);
      });
    });

    group('hasRecentLanguageDetection', () {
      test('should return true for detection within 7 days', () {
        final book = BookEntity(
          id: 'test',
          title: 'Test',
          author: 'Author',
          coverPath: '',
          filePath: '',
          importedDate: DateTime.now(),
          detectedLanguage: 'en',
          languageDetectionConfidence: 90,
          languageDetectionDate: DateTime.now().subtract(const Duration(days: 5)),
        );

        expect(book.hasRecentLanguageDetection(), isTrue);
      });

      test('should return false for detection older than 7 days', () {
        final book = BookEntity(
          id: 'test',
          title: 'Test',
          author: 'Author',
          coverPath: '',
          filePath: '',
          importedDate: DateTime.now(),
          detectedLanguage: 'en',
          languageDetectionConfidence: 90,
          languageDetectionDate: DateTime.now().subtract(const Duration(days: 8)),
        );

        expect(book.hasRecentLanguageDetection(), isFalse);
      });

      test('should return false when date is null', () {
        final book = BookEntity(
          id: 'test',
          title: 'Test',
          author: 'Author',
          coverPath: '',
          filePath: '',
          importedDate: DateTime.now(),
          detectedLanguage: 'en',
          languageDetectionConfidence: 90,
        );

        expect(book.hasRecentLanguageDetection(), isFalse);
      });

      test('should return true for detection today', () {
        final book = BookEntity(
          id: 'test',
          title: 'Test',
          author: 'Author',
          coverPath: '',
          filePath: '',
          importedDate: DateTime.now(),
          detectedLanguage: 'en',
          languageDetectionConfidence: 90,
          languageDetectionDate: DateTime.now(),
        );

        expect(book.hasRecentLanguageDetection(), isTrue);
      });
    });

    group('copyWith with language detection', () {
      test('should update language detection fields', () {
        final book = BookEntity(
          id: 'test',
          title: 'Test',
          author: 'Author',
          coverPath: '',
          filePath: '',
          importedDate: DateTime.now(),
        );

        final updated = book.copyWith(
          detectedLanguage: 'es',
          languageDetectionConfidence: 85,
          languageDetectionDate: DateTime.now(),
        );

        expect(updated.detectedLanguage, equals('es'));
        expect(updated.languageDetectionConfidence, equals(85));
        expect(updated.languageDetectionDate, isNotNull);
      });

      test('should clear language detection', () {
        final book = BookEntity(
          id: 'test',
          title: 'Test',
          author: 'Author',
          coverPath: '',
          filePath: '',
          importedDate: DateTime.now(),
          detectedLanguage: 'en',
          languageDetectionConfidence: 90,
          languageDetectionDate: DateTime.now(),
        );

        final cleared = book.copyWith(clearLanguageDetection: true);

        expect(cleared.detectedLanguage, isNull);
        expect(cleared.languageDetectionConfidence, isNull);
        expect(cleared.languageDetectionDate, isNull);
      });

      test('should preserve other fields when updating language', () {
        final book = BookEntity(
          id: 'test-id',
          title: 'Test Title',
          author: 'Test Author',
          coverPath: '/cover.jpg',
          filePath: '/book.epub',
          importedDate: DateTime(2024, 1, 1),
          currentPage: 10,
          totalPages: 300,
        );

        final updated = book.copyWith(
          detectedLanguage: 'fr',
          languageDetectionConfidence: 95,
        );

        expect(updated.id, equals('test-id'));
        expect(updated.title, equals('Test Title'));
        expect(updated.author, equals('Test Author'));
        expect(updated.currentPage, equals(10));
        expect(updated.totalPages, equals(300));
        expect(updated.detectedLanguage, equals('fr'));
        expect(updated.languageDetectionConfidence, equals(95));
      });
    });
  });
}
