/// Test Book Fixtures
///
/// Provides access to test book files and metadata for E2E testing.
/// This helper manages the test data used in parsing and format tests.

library;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'dart:io';

/// Test book metadata and file paths
class TestBook {
  final String filename;
  final String title;
  final String author;
  final String format;
  final int pageCount;
  final int chapterCount;
  final bool hasImages;
  final bool hasToc;
  final String description;

  const TestBook({
    required this.filename,
    required this.title,
    required this.author,
    required this.format,
    this.pageCount = 0,
    this.chapterCount = 0,
    this.hasImages = false,
    this.hasToc = true,
    this.description = '',
  });

  /// Get the full path to the test book file
  String get path {
    // In a real implementation, this would resolve to the test assets directory
    return 'test_assets/books/$filename';
  }

  /// Check if the test book file exists
  Future<bool> exists() async {
    return await File(path).exists();
  }

  /// Load the test book as bytes
  Future<Uint8List> loadBytes() async {
    final file = File(path);
    if (!await file.exists()) {
      throw TestBookException('Test book not found: $filename');
    }
    return await file.readAsBytes();
  }
}

/// Exception for test book errors
class TestBookException implements Exception {
  final String message;
  TestBookException(this.message);

  @override
  String toString() => 'TestBookException: $message';
}

/// Collection of test book fixtures
class TestBooks {
  // EPUB2 Test Books
  static const epub2Basic = TestBook(
    filename: 'epub2_basic.epub',
    title: 'EPUB2 Basic Test',
    author: 'Test Author',
    format: 'EPUB2',
    pageCount: 50,
    chapterCount: 5,
    hasImages: false,
    hasToc: true,
    description: 'Basic EPUB2 file for standard testing',
  );

  static const epub2WithImages = TestBook(
    filename: 'epub2_with_images.epub',
    title: 'EPUB2 with Images',
    author: 'Test Author',
    format: 'EPUB2',
    pageCount: 30,
    chapterCount: 3,
    hasImages: true,
    hasToc: true,
    description: 'EPUB2 with embedded images',
  );

  // EPUB3 Test Books
  static const epub3Basic = TestBook(
    filename: 'epub3_basic.epub',
    title: 'EPUB3 Basic Test',
    author: 'Test Author',
    format: 'EPUB3',
    pageCount: 50,
    chapterCount: 5,
    hasImages: false,
    hasToc: true,
    description: 'Basic EPUB3 file for standard testing',
  );

  static const epub3WithComplexFormatting = TestBook(
    filename: 'epub3_complex.epub',
    title: 'EPUB3 Complex Formatting',
    author: 'Test Author',
    format: 'EPUB3',
    pageCount: 40,
    chapterCount: 4,
    hasImages: true,
    hasToc: true,
    description: 'EPUB3 with complex CSS and formatting',
  );

  // MOBI Test Books
  static const mobiBasic = TestBook(
    filename: 'mobi_basic.mobi',
    title: 'MOBI Basic Test',
    author: 'Test Author',
    format: 'MOBI',
    pageCount: 50,
    chapterCount: 5,
    hasImages: false,
    hasToc: true,
    description: 'Basic MOBI file for standard testing',
  );

  static const mobiWithImages = TestBook(
    filename: 'mobi_with_images.mobi',
    title: 'MOBI with Images',
    author: 'Test Author',
    format: 'MOBI',
    pageCount: 30,
    chapterCount: 3,
    hasImages: true,
    hasToc: true,
    description: 'MOBI with embedded images',
  );

  // KF8/AZW Test Books
  static const kf8Basic = TestBook(
    filename: 'kf8_basic.kf8',
    title: 'KF8 Basic Test',
    author: 'Test Author',
    format: 'KF8',
    pageCount: 50,
    chapterCount: 5,
    hasImages: false,
    hasToc: true,
    description: 'Basic KF8 file for standard testing',
  );

  // Edge Case Books
  static const emptyBook = TestBook(
    filename: 'empty.epub',
    title: 'Empty Book',
    author: 'Test Author',
    format: 'EPUB2',
    pageCount: 0,
    chapterCount: 0,
    hasImages: false,
    hasToc: false,
    description: 'Book with no content',
  );

  static const onePageBook = TestBook(
    filename: 'one_page.epub',
    title: 'One Page Book',
    author: 'Test Author',
    format: 'EPUB2',
    pageCount: 1,
    chapterCount: 1,
    hasImages: false,
    hasToc: true,
    description: 'Book with only one page',
  );

  static const longChaptersBook = TestBook(
    filename: 'long_chapters.epub',
    title: 'Long Chapters',
    author: 'Test Author',
    format: 'EPUB2',
    pageCount: 200,
    chapterCount: 2,
    hasImages: false,
    hasToc: true,
    description: 'Book with very long chapters',
  );

  static const manyChaptersBook = TestBook(
    filename: 'many_chapters.epub',
    title: 'Many Chapters',
    author: 'Test Author',
    format: 'EPUB2',
    pageCount: 100,
    chapterCount: 100,
    hasImages: false,
    hasToc: true,
    description: 'Book with many short chapters',
  );

  static const noTocBook = TestBook(
    filename: 'no_toc.epub',
    title: 'No TOC',
    author: 'Test Author',
    format: 'EPUB2',
    pageCount: 30,
    chapterCount: 3,
    hasImages: false,
    hasToc: false,
    description: 'Book without table of contents',
  );

  static const corruptedBook = TestBook(
    filename: 'corrupted.epub',
    title: 'Corrupted',
    author: 'Test Author',
    format: 'EPUB2',
    pageCount: 0,
    chapterCount: 0,
    hasImages: false,
    hasToc: false,
    description: 'Corrupted book file',
  );

  static const invalidFormat = TestBook(
    filename: 'not_a_book.pdf',
    title: 'Invalid Format',
    author: 'Test Author',
    format: 'PDF',
    pageCount: 0,
    chapterCount: 0,
    hasImages: false,
    hasToc: false,
    description: 'File in unsupported format',
  );

  // Large Books
  static const largeBook = TestBook(
    filename: 'large_book.epub',
    title: 'Large Book',
    author: 'Test Author',
    format: 'EPUB2',
    pageCount: 1000,
    chapterCount: 50,
    hasImages: false,
    hasToc: true,
    description: 'Book with 1000+ pages',
  );

  static const veryLargeBook = TestBook(
    filename: 'very_large.epub',
    title: 'Very Large Book',
    author: 'Test Author',
    format: 'EPUB2',
    pageCount: 5000,
    chapterCount: 200,
    hasImages: true,
    hasToc: true,
    description: 'Book with 5000+ pages for stress testing',
  );

  // Language Specific Books
  static const rtlBook = TestBook(
    filename: 'arabic_book.epub',
    title: 'كتاب التجريب',
    author: 'مؤلف التجريب',
    format: 'EPUB3',
    pageCount: 50,
    chapterCount: 5,
    hasImages: false,
    hasToc: true,
    description: 'Arabic book for RTL testing',
  );

  static const chineseBook = TestBook(
    filename: 'chinese_book.epub',
    title: '测试书籍',
    author: '测试作者',
    format: 'EPUB3',
    pageCount: 50,
    chapterCount: 5,
    hasImages: false,
    hasToc: true,
    description: 'Chinese book for CJK testing',
  );

  static const japaneseBook = TestBook(
    filename: 'japanese_book.epub',
    title: 'テストブック',
    author: 'テスト著者',
    format: 'EPUB3',
    pageCount: 50,
    chapterCount: 5,
    hasImages: false,
    hasToc: true,
    description: 'Japanese book for CJK testing',
  );

  static const koreanBook = TestBook(
    filename: 'korean_book.epub',
    title: '테스트 책',
    author: '테스트 저자',
    format: 'EPUB3',
    pageCount: 50,
    chapterCount: 5,
    hasImages: false,
    hasToc: true,
    description: 'Korean book for CJK testing',
  );

  static const unicodeBook = TestBook(
    filename: 'unicode_book.epub',
    title: 'Über Ñiño Prüfung',
    author: 'François Müller',
    format: 'EPUB3',
    pageCount: 30,
    chapterCount: 3,
    hasImages: false,
    hasToc: true,
    description: 'Book with unicode characters in metadata',
  );

  // Special Formatting Books
  static const codeBlocksBook = TestBook(
    filename: 'code_blocks.epub',
    title: 'Code Examples',
    author: 'Test Author',
    format: 'EPUB3',
    pageCount: 40,
    chapterCount: 4,
    hasImages: false,
    hasToc: true,
    description: 'Book with code blocks and monospace text',
  );

  static const tablesBook = TestBook(
    filename: 'tables.epub',
    title: 'Data Tables',
    author: 'Test Author',
    format: 'EPUB3',
    pageCount: 30,
    chapterCount: 3,
    hasImages: false,
    hasToc: true,
    description: 'Book with HTML tables',
  );

  static const complexFormattingBook = TestBook(
    filename: 'complex_formatting.epub',
    title: 'Complex Formatting',
    author: 'Test Author',
    format: 'EPUB3',
    pageCount: 50,
    chapterCount: 5,
    hasImages: true,
    hasToc: true,
    description: 'Book with nested formatting and styles',
  );

  static const malformedHtmlBook = TestBook(
    filename: 'malformed_html.epub',
    title: 'Malformed HTML',
    author: 'Test Author',
    format: 'EPUB2',
    pageCount: 20,
    chapterCount: 2,
    hasImages: false,
    hasToc: true,
    description: 'Book with malformed HTML content',
  );

  /// Get all available test books
  static const List<TestBook> all = [
    epub2Basic,
    epub2WithImages,
    epub3Basic,
    epub3WithComplexFormatting,
    mobiBasic,
    mobiWithImages,
    kf8Basic,
    emptyBook,
    onePageBook,
    longChaptersBook,
    manyChaptersBook,
    noTocBook,
    rtlBook,
    chineseBook,
    japaneseBook,
    koreanBook,
    unicodeBook,
    codeBlocksBook,
    tablesBook,
    complexFormattingBook,
  ];

  /// Get test books by format
  static List<TestBook> byFormat(String format) {
    return all.where((book) => book.format == format).toList();
  }

  /// Get EPUB test books
  static List<TestBook> get epub => [
        epub2Basic,
        epub2WithImages,
        epub3Basic,
        epub3WithComplexFormatting,
        emptyBook,
        onePageBook,
        longChaptersBook,
        manyChaptersBook,
        noTocBook,
        rtlBook,
        chineseBook,
        japaneseBook,
        koreanBook,
        unicodeBook,
        codeBlocksBook,
        tablesBook,
        complexFormattingBook,
        malformedHtmlBook,
      ];

  /// Get MOBI test books
  static List<TestBook> get mobi => [
        mobiBasic,
        mobiWithImages,
        kf8Basic,
      ];

  /// Get edge case test books
  static List<TestBook> get edgeCases => [
        emptyBook,
        onePageBook,
        longChaptersBook,
        manyChaptersBook,
        noTocBook,
        corruptedBook,
        invalidFormat,
        malformedHtmlBook,
      ];

  /// Get large test books
  static List<TestBook> get large => [
        largeBook,
        veryLargeBook,
      ];

  /// Get language-specific test books
  static List<TestBook> get languageSpecific => [
        rtlBook,
        chineseBook,
        japaneseBook,
        koreanBook,
        unicodeBook,
      ];

  /// Check if a test book file exists in the test assets
  static Future<bool> bookExists(TestBook book) async {
    return await book.exists();
  }

  /// Load test book data for Flutter test assets
  ///
  /// This would typically be used with rootBundle for Flutter tests
  static Future<ByteData> loadAssetBook(String assetPath) async {
    try {
      return await rootBundle.load(assetPath);
    } catch (e) {
      throw TestBookException('Failed to load test book asset: $assetPath');
    }
  }
}

/// Helper functions for test book operations
class TestBookHelper {
  /// Import a test book into the library for testing
  static Future<void> importTestBook(
    WidgetTester tester,
    TestBook book,
  ) async {
    // In a real implementation, this would:
    // 1. Copy the test book to the app's library directory
    // 2. Trigger the import process
    // 3. Wait for import to complete
    // await tester.pumpAndSettle();
  }

  /// Verify a test book was imported correctly
  static Future<void> verifyBookImported(
    WidgetTester tester,
    TestBook book,
  ) async {
    // In a real implementation, this would:
    // 1. Check the library for the book
    // 2. Verify metadata matches
    // 3. Verify file was processed
  }

  /// Get the expected page count for a test book
  static int expectedPageCount(TestBook book) {
    return book.pageCount;
  }

  /// Get the expected chapter count for a test book
  static int expectedChapterCount(TestBook book) {
    return book.chapterCount;
  }
}
