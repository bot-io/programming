/// Test Data Builders
///
/// Provides builder classes for creating test data entities.
/// Uses the Builder pattern for flexible test data creation.

library;

import 'package:dual_reader/src/domain/entities/book.dart';
import 'package:dual_reader/src/domain/entities/chapter.dart';
import 'package:dual_reader/src/domain/entities/book_content.dart';
import 'package:dual_reader/src/domain/entities/translation_result.dart';
import 'package:dual_reader/src/domain/entities/settings_entity.dart';
import 'package:flutter/material.dart';

/// Builder for creating Book entities
class BookBuilder {
  String _id = 'test-book-id';
  String _title = 'Test Book';
  String _author = 'Test Author';
  String _format = 'EPUB';
  String _filePath = '/test/path/book.epub';
  String? _coverPath;
  int _totalPages = 100;
  int _currentPage = 0;
  double _progress = 0.0;
  String _language = 'en';
  DateTime _addedAt = DateTime.now();
  DateTime? _lastReadAt;

  BookBuilder();

  /// Set the book ID
  BookBuilder withId(String id) {
    _id = id;
    return this;
  }

  /// Set the book title
  BookBuilder withTitle(String title) {
    _title = title;
    return this;
  }

  /// Set the book author
  BookBuilder withAuthor(String author) {
    _author = author;
    return this;
  }

  /// Set the book format
  BookBuilder withFormat(String format) {
    _format = format;
    return this;
  }

  /// Set the file path
  BookBuilder withFilePath(String path) {
    _filePath = path;
    return this;
  }

  /// Set the cover path
  BookBuilder withCoverPath(String? path) {
    _coverPath = path;
    return this;
  }

  /// Set total pages
  BookBuilder withTotalPages(int pages) {
    _totalPages = pages;
    return this;
  }

  /// Set current page
  BookBuilder withCurrentPage(int page) {
    _currentPage = page;
    _progress = page / _totalPages;
    return this;
  }

  /// Set reading progress
  BookBuilder withProgress(double progress) {
    _progress = progress;
    _currentPage = (_progress * _totalPages).round();
    return this;
  }

  /// Set language
  BookBuilder withLanguage(String language) {
    _language = language;
    return this;
  }

  /// Set as last read
  BookBuilder asLastRead() {
    _lastReadAt = DateTime.now();
    return this;
  }

  /// Build the Book entity
  Book build() {
    return Book(
      id: _id,
      title: _title,
      author: _author,
      format: _format,
      filePath: _filePath,
      coverPath: _coverPath,
      totalPages: _totalPages,
      currentPage: _currentPage,
      progress: _progress,
      language: _language,
      addedAt: _addedAt,
      lastReadAt: _lastReadAt,
    );
  }
}

/// Builder for creating Chapter entities
class ChapterBuilder {
  String _id = 'test-chapter-id';
  String _bookId = 'test-book-id';
  String _title = 'Test Chapter';
  int _index = 0;
  int _contentOffset = 0;
  int _contentLength = 10000;

  ChapterBuilder();

  /// Set the chapter ID
  ChapterBuilder withId(String id) {
    _id = id;
    return this;
  }

  /// Set the book ID
  ChapterBuilder withBookId(String bookId) {
    _bookId = bookId;
    return this;
  }

  /// Set the chapter title
  ChapterBuilder withTitle(String title) {
    _title = title;
    return this;
  }

  /// Set the chapter index
  ChapterBuilder withIndex(int index) {
    _index = index;
    return this;
  }

  /// Set content offset
  ChapterBuilder withContentOffset(int offset) {
    _contentOffset = offset;
    return this;
  }

  /// Set content length
  ChapterBuilder withContentLength(int length) {
    _contentLength = length;
    return this;
  }

  /// Build the Chapter entity
  Chapter build() {
    return Chapter(
      id: _id,
      bookId: _bookId,
      title: _title,
      index: _index,
      contentOffset: _contentOffset,
      contentLength: _contentLength,
    );
  }

  /// Build a list of chapters
  static List<Chapter> buildMany(int count, {String bookId = 'test-book'}) {
    return List.generate(
      count,
      (index) => ChapterBuilder()
          .withBookId(bookId)
          .withId('$bookId-chapter-$index')
          .withTitle('Chapter ${index + 1}')
          .withIndex(index)
          .build(),
    );
  }
}

/// Builder for creating BookContent entities
class BookContentBuilder {
  String _bookId = 'test-book-id';
  int _chapterIndex = 0;
  String _title = 'Chapter 1';
  String _content = 'Test chapter content.';
  String _htmlContent = '<p>Test chapter content.</p>';

  BookContentBuilder();

  /// Set the book ID
  BookContentBuilder withBookId(String bookId) {
    _bookId = bookId;
    return this;
  }

  /// Set the chapter index
  BookContentBuilder withChapterIndex(int index) {
    _chapterIndex = index;
    return this;
  }

  /// Set the title
  BookContentBuilder withTitle(String title) {
    _title = title;
    return this;
  }

  /// Set the content
  BookContentBuilder withContent(String content) {
    _content = content;
    return this;
  }

  /// Set the HTML content
  BookContentBuilder withHtmlContent(String html) {
    _htmlContent = html;
    return this;
  }

  /// Generate multi-paragraph content
  BookContentBuilder withParagraphs(int paragraphCount, {int wordsPerParagraph = 50}) {
    final paragraphs = <String>[];
    for (int i = 0; i < paragraphCount; i++) {
      final words = List.generate(wordsPerParagraph, (j) => 'word${i}_$j').join(' ');
      paragraphs.add('Paragraph $i. $words.');
    }
    _content = paragraphs.join('\n\n');
    _htmlContent = paragraphs.map((p) => '<p>$p</p>').join('\n');
    return this;
  }

  /// Build the BookContent entity
  BookContent build() {
    return BookContent(
      bookId: _bookId,
      chapterIndex: _chapterIndex,
      title: _title,
      content: _content,
      htmlContent: _htmlContent,
    );
  }
}

/// Builder for creating TranslationResult entities
class TranslationResultBuilder {
  String _originalText = 'Hello world';
  String _translatedText = 'Hola mundo';
  String _sourceLanguage = 'en';
  String _targetLanguage = 'es';
  double _confidence = 1.0;

  TranslationResultBuilder();

  /// Set original text
  TranslationResultBuilder withOriginalText(String text) {
    _originalText = text;
    return this;
  }

  /// Set translated text
  TranslationResultBuilder withTranslatedText(String text) {
    _translatedText = text;
    return this;
  }

  /// Set source language
  TranslationResultBuilder withSourceLanguage(String language) {
    _sourceLanguage = language;
    return this;
  }

  /// Set target language
  TranslationResultBuilder withTargetLanguage(String language) {
    _targetLanguage = language;
    return this;
  }

  /// Set confidence score
  TranslationResultBuilder withConfidence(double confidence) {
    _confidence = confidence;
    return this;
  }

  /// Build the TranslationResult entity
  TranslationResult build() {
    return TranslationResult(
      originalText: _originalText,
      translatedText: _translatedText,
      sourceLanguage: _sourceLanguage,
      targetLanguage: _targetLanguage,
      confidence: _confidence,
    );
  }

  /// Create a word-replacement translation (predictable for testing)
  static TranslationResult createWordReplacement(
    String text,
    String targetLanguage,
  ) {
    final words = text.split(' ');
    final translatedWords = words.map((word) {
      if (word.isEmpty) return word;
      final cleanWord = word.replaceAll(RegExp(r'[^\w]'), '');
      final punctuation = word.substring(cleanWord.length);
      return '${cleanWord}_$targetLanguage$punctuation';
    }).join(' ');

    return TranslationResult(
      originalText: text,
      translatedText: translatedWords,
      sourceLanguage: 'en',
      targetLanguage: targetLanguage,
      confidence: 1.0,
    );
  }
}

/// Builder for creating SettingsEntity
class SettingsBuilder {
  ThemeMode _themeMode = ThemeMode.system;
  String _fontFamily = 'Roboto';
  double _fontSize = 16.0;
  double _lineHeight = 1.5;
  double _margin = 16.0;
  TextAlign _textAlign = TextAlign.left;
  double _panelWidthRatio = 0.5;
  String _targetTranslationLanguageCode = 'es';

  SettingsBuilder();

  /// Set theme mode
  SettingsBuilder withThemeMode(ThemeMode mode) {
    _themeMode = mode;
    return this;
  }

  /// Set font family
  SettingsBuilder withFontFamily(String family) {
    _fontFamily = family;
    return this;
  }

  /// Set font size
  SettingsBuilder withFontSize(double size) {
    _fontSize = size;
    return this;
  }

  /// Set line height
  SettingsBuilder withLineHeight(double height) {
    _lineHeight = height;
    return this;
  }

  /// Set margins
  SettingsBuilder withMargins(double margin) {
    _margin = margin;
    return this;
  }

  /// Set text alignment
  SettingsBuilder withTextAlign(TextAlign align) {
    _textAlign = align;
    return this;
  }

  /// Set panel width ratio
  SettingsBuilder withPanelWidthRatio(double ratio) {
    _panelWidthRatio = ratio;
    return this;
  }

  /// Set target translation language
  SettingsBuilder withTargetLanguage(String languageCode) {
    _targetTranslationLanguageCode = languageCode;
    return this;
  }

  /// Create default settings
  static SettingsEntity defaultSettings() {
    return SettingsBuilder().build();
  }

  /// Create dark mode settings
  static SettingsEntity darkMode() {
    return SettingsBuilder().withThemeMode(ThemeMode.dark).build();
  }

  /// Create large font settings
  static SettingsEntity largeFont() {
    return SettingsBuilder().withFontSize(20.0).build();
  }

  /// Build the SettingsEntity
  SettingsEntity build() {
    return SettingsEntity(
      themeMode: _themeMode,
      fontlFamily: _fontFamily,
      fontSize: _fontSize,
      lineHeight: _lineHeight,
      margin: _margin,
      textAlign: _textAlign,
      panelWidthRatio: _panelWidthRatio,
      targetTranslationLanguageCode: _targetTranslationLanguageCode,
    );
  }
}

/// Pagination result builder
class PaginationResultBuilder {
  String _bookId = 'test-book';
  int _totalPages = 100;
  List<PageInfo> _pages = [];

  PaginationResultBuilder();

  /// Set book ID
  PaginationResultBuilder withBookId(String id) {
    _bookId = id;
    return this;
  }

  /// Set total pages
  PaginationResultBuilder withTotalPages(int pages) {
    _totalPages = pages;
    return this;
  }

  /// Set pages
  PaginationResultBuilder withPages(List<PageInfo> pages) {
    _pages = pages;
    _totalPages = pages.length;
    return this;
  }

  /// Generate pages for a chapter
  PaginationResultBuilder generatePagesForChapter(int chapterIndex, {int pageCount = 10}) {
    final startIndex = _pages.length;
    for (int i = 0; i < pageCount; i++) {
      _pages.add(PageInfo(
        chapterIndex: chapterIndex,
        pageIndex: i,
        globalIndex: startIndex + i,
        contentOffset: i * 1000,
        contentLength: 1000,
        wordCount: 250,
      ));
    }
    _totalPages = _pages.length;
    return this;
  }

  /// Build the PaginationResult
  PaginationResult build() {
    return PaginationResult(
      bookId: _bookId,
      totalPages: _totalPages,
      pages: _pages,
      metadata: PaginationMetadata(
        bookId: _bookId,
        totalPages: _totalPages,
        totalChapters: 0,
        averageWordsPerPage: 250,
        generatedAt: DateTime.now(),
      ),
    );
  }
}
