import 'package:flutter/material.dart';
import 'package:dual_reader/models/app_settings.dart';
import 'package:dual_reader/models/book.dart';
import 'package:dual_reader/models/bookmark.dart';
import 'package:dual_reader/models/chapter.dart';
import 'package:dual_reader/models/page_content.dart';

/// Test helper utilities for creating test data and mocks

class TestHelpers {
  /// Creates a default AppSettings for testing
  static AppSettings createTestSettings({
    String? theme,
    String? fontFamily,
    int? fontSize,
    double? lineHeight,
    int? marginSize,
    String? textAlignment,
    String? translationLanguage,
    bool? autoTranslate,
    double? panelRatio,
    bool? syncScrolling,
  }) {
    return AppSettings(
      theme: theme ?? 'dark',
      fontFamily: fontFamily ?? 'Roboto',
      fontSize: fontSize ?? 16,
      lineHeight: lineHeight ?? 1.6,
      marginSize: marginSize ?? 2,
      textAlignment: textAlignment ?? 'left',
      translationLanguage: translationLanguage ?? 'es',
      autoTranslate: autoTranslate ?? true,
      panelRatio: panelRatio ?? 0.5,
      syncScrolling: syncScrolling ?? true,
    );
  }

  /// Creates a test BuildContext with MediaQuery
  static Widget createTestWidget(Widget child) {
    return MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(
          size: Size(400, 800),
          padding: EdgeInsets.zero,
        ),
        child: child,
      ),
    );
  }

  /// Generates test text of specified length
  static String generateTestText(int wordCount) {
    final words = List.generate(
      wordCount,
      (index) => 'word${index + 1}',
    );
    return words.join(' ');
  }

  /// Generates test text with paragraphs
  static String generateTestTextWithParagraphs(int paragraphCount, int wordsPerParagraph) {
    final paragraphs = List.generate(
      paragraphCount,
      (index) => generateTestText(wordsPerParagraph),
    );
    return paragraphs.join('\n\n');
  }

  /// Creates a test Book
  static Book createTestBook({
    String? id,
    String? title,
    String? author,
    String? filePath,
    String? format,
    String? coverImagePath,
    List<Chapter>? chapters,
    String? fullText,
    DateTime? addedAt,
    String? language,
    int? totalPages,
  }) {
    return Book(
      id: id ?? 'test-book-1',
      title: title ?? 'Test Book',
      author: author ?? 'Test Author',
      filePath: filePath ?? '/path/to/test.epub',
      format: format ?? 'epub',
      coverImagePath: coverImagePath,
      chapters: chapters ?? [],
      fullText: fullText ?? 'Test content',
      addedAt: addedAt ?? DateTime.now(),
      language: language,
      totalPages: totalPages ?? 100,
    );
  }

  /// Creates a test Bookmark
  static Bookmark createTestBookmark({
    String? id,
    String? bookId,
    int? page,
    String? note,
    DateTime? createdAt,
    String? chapterId,
  }) {
    return Bookmark(
      id: id ?? 'test-bookmark-1',
      bookId: bookId ?? 'test-book-1',
      page: page ?? 1,
      note: note,
      createdAt: createdAt ?? DateTime.now(),
      chapterId: chapterId,
    );
  }

  /// Creates a test Chapter
  static Chapter createTestChapter({
    String? id,
    String? title,
    int? startIndex,
    int? endIndex,
    int? startPage,
    int? endPage,
    String? bookId,
    String? href,
  }) {
    return Chapter(
      id: id ?? 'test-chapter-1',
      title: title ?? 'Test Chapter',
      startIndex: startIndex ?? 0,
      endIndex: endIndex ?? 1000,
      startPage: startPage ?? 1,
      endPage: endPage ?? 10,
      bookId: bookId ?? 'test-book-1',
      href: href,
    );
  }

  /// Creates a test PageContent
  static PageContent createTestPageContent({
    String? originalText,
    String? translatedText,
    int? pageNumber,
    int? totalPages,
    bool? isTranslated,
  }) {
    return PageContent(
      originalText: originalText ?? 'Original text',
      translatedText: translatedText,
      pageNumber: pageNumber ?? 1,
      totalPages: totalPages ?? 10,
      isTranslated: isTranslated ?? false,
    );
  }
}
