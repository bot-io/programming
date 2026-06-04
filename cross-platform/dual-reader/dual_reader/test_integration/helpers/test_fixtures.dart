/// Test fixtures for E2E tests
///
/// Provides test data builders and fixtures for consistent test data.

library;

import 'package:dual_reader/src/domain/entities/book_entity.dart';
import 'package:dual_reader/src/domain/entities/settings_entity.dart';
import 'package:dual_reader/src/domain/entities/translation_chunk.dart';
import 'package:dual_reader/src/domain/entities/chapter_entity.dart';

/// Test data fixtures
class TestFixtures {
  /// Create a test book entity
  static BookEntity createTestBook({
    String? id,
    String? title,
    String? author,
    int? currentPage,
    int? totalPages,
  }) {
    return BookEntity(
      id: id ?? 'test-book-1',
      title: title ?? 'Test Book',
      author: author ?? 'Test Author',
      filePath: '/test/path/book.epub',
      format: BookFormat.epub,
      currentPage: currentPage ?? 0,
      totalPages: totalPages ?? 100,
      language: 'en',
      dateAdded: DateTime.now(),
      lastRead: DateTime.now(),
    );
  }

  /// Create a list of test books
  static List<BookEntity> createTestBooks({int count = 3}) {
    return List.generate(
      count,
      (i) => createTestBook(
        id: 'test-book-$i',
        title: 'Test Book $i',
        author: 'Test Author $i',
      ),
    );
  }

  /// Create default settings
  static SettingsEntity createDefaultSettings() {
    return const SettingsEntity(
      fontSize: 16.0,
      themeMode: ThemeMode.system,
      targetLanguage: 'es',
      sourceLanguage: 'en',
      enableTranslation: true,
      autoDownloadModels: false,
    );
  }

  /// Create custom settings
  static SettingsEntity createCustomSettings({
    double? fontSize,
    ThemeMode? themeMode,
    String? targetLanguage,
    bool? enableTranslation,
  }) {
    return SettingsEntity(
      fontSize: fontSize ?? 18.0,
      themeMode: themeMode ?? ThemeMode.dark,
      targetLanguage: targetLanguage ?? 'bg',
      sourceLanguage: 'en',
      enableTranslation: enableTranslation ?? true,
      autoDownloadModels: false,
    );
  }

  /// Create a translation chunk
  static TranslationChunk createTranslationChunk({
    String? originalText,
    String? translatedText,
    String? sourceLanguage,
    String? targetLanguage,
  }) {
    return TranslationChunk(
      id: 'chunk-${DateTime.now().millisecondsSinceEpoch}',
      originalText: originalText ?? 'Hello world',
      translatedText: translatedText ?? 'Hola mundo',
      sourceLanguage: sourceLanguage ?? 'en',
      targetLanguage: targetLanguage ?? 'es',
      isTranslated: translatedText != null,
    );
  }

  /// Create a chapter entity
  static ChapterEntity createChapter({
    String? id,
    String? title,
    List<String>? content,
  }) {
    return ChapterEntity(
      id: id ?? 'chapter-1',
      title: title ?? 'Chapter 1',
      content: content ?? ['Test content', 'More test content'],
    );
  }

  /// Test text samples for translation
  static const Map<String, Map<String, String>> translationSamples = {
    'simple': {
      'en': 'Hello',
      'es': 'Hola',
      'bg': 'Здравей',
      'fr': 'Bonjour',
    },
    'phrase': {
      'en': 'How are you?',
      'es': '¿Cómo estás?',
      'bg': 'Как си?',
      'fr': 'Comment allez-vous?',
    },
    'paragraph': {
      'en': 'The quick brown fox jumps over the lazy dog.',
      'es': 'El rápido zorro marrón salta sobre el perro perezoso.',
      'bg': 'Бързата кафява лисица скача над мързеливото куче.',
      'fr': 'Le rapide renard brun saute par-dessus le chien paresseux.',
    },
  };

  /// Test text with special characters
  static const Map<String, String> specialCharacterSamples = {
    'quotes': 'Text with "quotes" and \'apostrophes\'',
    'punctuation': 'Text with commas, periods, and semicolons;',
    'numbers': 'Text with numbers 1, 2, 3, and 100',
    'symbols': 'Text with symbols: @, #, $, %, &, *',
    'brackets': 'Text with (parentheses) and [brackets]',
    'ellipsis': 'Text with an ellipsis...',
    'emoji': 'Text with emoji 😀 📚 🌟',
  };

  /// Test text formats
  static const Map<String, String> formatSamples = {
    'bold': '**Bold text**',
    'italic': '*Italic text*',
    'mixed': '**Bold** and *italic* text',
    'link': 'Text with [link](https://example.com)',
  };

  /// Long text for pagination testing
  static const String longTextSample = '''
Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur.

Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum. Sed ut perspiciatis unde omnis iste natus error sit voluptatem accusantium doloremque laudantium, totam rem aperiam.

Nemo enim ipsam voluptatem quia voluptas sit aspernatur aut odit aut fugit, sed quia consequuntur magni dolores eos qui ratione voluptatem sequi nesciunt.
''';

  /// Create multiple translation chunks
  static List<TranslationChunk> createTranslationChunks({
    int count = 5,
    String sourceLanguage = 'en',
    String targetLanguage = 'es',
  }) {
    return List.generate(
      count,
      (i) => createTranslationChunk(
        originalText: 'Test text $i',
        translatedText: 'Texto de prueba $i',
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
      ),
    );
  }

  /// Get a random test book
  static BookEntity randomTestBook() {
    final random = DateTime.now().millisecondsSinceEpoch;
    return createTestBook(
      id: 'random-book-$random',
      title: 'Random Book $random',
      author: 'Random Author',
    );
  }
}

/// Book format enum for test fixtures
enum BookFormat {
  epub,
  mobi,
}

/// Import for BookFormat
import 'package:dual_reader/src/domain/entities/book_entity.dart' show BookFormat;
