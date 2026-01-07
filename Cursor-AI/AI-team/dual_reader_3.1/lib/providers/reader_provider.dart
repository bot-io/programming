import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/book.dart';
import '../models/page_content.dart';
import '../models/reading_progress.dart';
import '../services/storage_service.dart';
import '../services/translation_service.dart';
import '../utils/pagination.dart';
import '../models/app_settings.dart';
import 'settings_provider.dart';

class ReaderProvider with ChangeNotifier {
  final StorageService _storageService;
  final TranslationService _translationService;
  final SettingsProvider _settingsProvider;

  Book? _currentBook;
  List<PageContent> _pages = [];
  int _currentPageIndex = 0;
  ReadingProgress? _progress;
  bool _isLoading = false;
  bool _isTranslating = false;
  String? _error;
  BuildContext? _context;

  ReaderProvider(
    this._storageService,
    this._translationService,
    this._settingsProvider,
  );

  Book? get currentBook => _currentBook;
  List<PageContent> get pages => _pages;
  int get currentPageIndex => _currentPageIndex;
  PageContent? get currentPage => _pages.isNotEmpty ? _pages[_currentPageIndex] : null;
  ReadingProgress? get progress => _progress;
  bool get isLoading => _isLoading;
  bool get isTranslating => _isTranslating;
  String? get error => _error;
  bool get hasNextPage => _currentPageIndex < _pages.length - 1;
  bool get hasPreviousPage => _currentPageIndex > 0;
  List<Chapter> get chapters => _currentBook?.chapters ?? [];
  
  Chapter? getCurrentChapter() {
    if (_currentBook == null || _pages.isEmpty) return null;
    
    final currentTextIndex = _getCurrentTextIndex();
    for (final chapter in _currentBook!.chapters) {
      if (currentTextIndex >= chapter.startIndex && currentTextIndex <= chapter.endIndex) {
        return chapter;
      }
    }
    return null;
  }
  
  int _getCurrentTextIndex() {
    if (_pages.isEmpty || _currentPageIndex >= _pages.length) return 0;
    
    // Estimate text index based on page number
    // This is approximate - in a full implementation, you'd track exact indices
    final totalChars = _currentBook?.fullText.length ?? 0;
    final progress = (_currentPageIndex + 1) / _pages.length;
    return (totalChars * progress).round();
  }
  
  Future<void> goToChapter(Chapter chapter) async {
    if (_currentBook == null) return;
    
    // Find the page that contains the chapter start
    final chapterStartRatio = chapter.startIndex / _currentBook!.fullText.length;
    final targetPageIndex = (chapterStartRatio * _pages.length).round().clamp(0, _pages.length - 1);
    
    await goToPage(targetPageIndex);
  }

  Future<void> loadBook(String bookId, BuildContext context) async {
    _context = context;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Load book
      _currentBook = await _storageService.getBook(bookId);
      if (_currentBook == null) {
        throw Exception('Book not found');
      }

      // Load progress
      _progress = await _storageService.getProgress(bookId);
      
      // Paginate book content
      final mediaQuery = MediaQuery.of(context);
      final pageSize = Size(
        mediaQuery.size.width,
        mediaQuery.size.height - mediaQuery.padding.top - mediaQuery.padding.bottom - 100,
      );

      _pages = PaginationUtil.paginateText(
        text: _currentBook!.fullText,
        pageSize: pageSize,
        settings: _settingsProvider.settings,
        context: context,
      );

      // Enrich pages with HTML content if available
      _enrichPagesWithHtml();

      // Set current page from progress
      if (_progress != null && _progress!.currentPage > 0) {
        _currentPageIndex = (_progress!.currentPage - 1).clamp(0, _pages.length - 1);
      } else {
        _currentPageIndex = 0;
      }

      // Translate current page if auto-translate is enabled
      if (_settingsProvider.settings.autoTranslate) {
        await translateCurrentPage();
      }

      _error = null;
    } catch (e) {
      _error = 'Failed to load book: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> translateCurrentPage() async {
    if (_currentPage == null || _currentPage!.isTranslated) {
      return;
    }

    _isTranslating = true;
    notifyListeners();

    try {
      final settings = _settingsProvider.settings;
      final translatedText = await _translationService.translate(
        text: _currentPage!.originalText,
        targetLanguage: settings.translationLanguage,
        sourceLanguage: _currentBook?.language,
      );

      _pages[_currentPageIndex] = _currentPage!.copyWith(
        translatedText: translatedText,
        isTranslated: true,
      );

      _error = null;
    } catch (e) {
      String errorMessage = 'Translation failed';
      if (e.toString().contains('network') || e.toString().contains('connection')) {
        errorMessage = 'No internet connection. Please check your network and try again.';
      } else if (e.toString().contains('timeout')) {
        errorMessage = 'Translation request timed out. Please try again.';
      } else {
        errorMessage = 'Translation failed: ${e.toString()}';
      }
      _error = errorMessage;
      // Don't show error for translation failures - just log it
      print('Translation error: $e');
    } finally {
      _isTranslating = false;
      notifyListeners();
    }
  }

  Future<void> translatePage(int pageIndex) async {
    if (pageIndex < 0 || pageIndex >= _pages.length) {
      return;
    }

    final page = _pages[pageIndex];
    if (page.isTranslated) {
      return;
    }

    try {
      final settings = _settingsProvider.settings;
      final translatedText = await _translationService.translate(
        text: page.originalText,
        targetLanguage: settings.translationLanguage,
        sourceLanguage: _currentBook?.language,
      );

      _pages[pageIndex] = page.copyWith(
        translatedText: translatedText,
        isTranslated: true,
      );

      notifyListeners();
    } catch (e) {
      print('Failed to translate page $pageIndex: $e');
    }
  }

  Future<void> goToPage(int pageIndex) async {
    if (_pages.isEmpty) {
      return;
    }
    
    if (pageIndex < 0) {
      pageIndex = 0;
    } else if (pageIndex >= _pages.length) {
      pageIndex = _pages.length - 1;
    }

    _currentPageIndex = pageIndex;
    
    // Translate page if needed
    if (_settingsProvider.settings.autoTranslate && 
        _currentPageIndex < _pages.length &&
        !_pages[_currentPageIndex].isTranslated) {
      await translateCurrentPage();
    }

    await _saveProgress();
    notifyListeners();
  }

  Future<void> nextPage() async {
    if (hasNextPage) {
      await goToPage(_currentPageIndex + 1);
    }
  }

  Future<void> previousPage() async {
    if (hasPreviousPage) {
      await goToPage(_currentPageIndex - 1);
    }
  }

  Future<void> _saveProgress() async {
    if (_currentBook == null) {
      return;
    }

    final progress = ReadingProgress(
      bookId: _currentBook!.id,
      currentPage: _currentPageIndex + 1,
      totalPages: _pages.length,
      progress: (_currentPageIndex + 1) / _pages.length,
      lastReadAt: DateTime.now(),
    );

    _progress = progress;
    await _storageService.saveProgress(progress);
  }

  void refreshPages(BuildContext context) {
    if (_currentBook == null) return;
    
    _context = context;
    final mediaQuery = MediaQuery.of(context);
    final pageSize = Size(
      mediaQuery.size.width,
      mediaQuery.size.height - mediaQuery.padding.top - mediaQuery.padding.bottom - 100,
    );

    final oldPageIndex = _currentPageIndex;
    _pages = PaginationUtil.paginateText(
      text: _currentBook!.fullText,
      pageSize: pageSize,
      settings: _settingsProvider.settings,
      context: context,
    );

    // Enrich pages with HTML content if available
    _enrichPagesWithHtml();

    // Restore page position
    _currentPageIndex = oldPageIndex.clamp(0, _pages.length - 1);
    notifyListeners();
  }

  /// Enrich pages with HTML content from book chapters
  void _enrichPagesWithHtml() {
    if (_currentBook == null || 
        _currentBook!.chapterHtml == null || 
        _currentBook!.chapterHtml!.isEmpty ||
        _pages.isEmpty) {
      return;
    }

    final chapterHtml = _currentBook!.chapterHtml!;
    final fullText = _currentBook!.fullText;
    
    // Create a mapping of text positions to chapter HTML
    for (int i = 0; i < _pages.length; i++) {
      final page = _pages[i];
      
      // Estimate which chapter this page belongs to based on text position
      final pageStartRatio = (page.pageNumber - 1) / page.totalPages;
      final estimatedTextIndex = (fullText.length * pageStartRatio).round();
      
      // Find the chapter that contains this text index
      String? htmlContent;
      for (final chapter in _currentBook!.chapters) {
        if (estimatedTextIndex >= chapter.startIndex && 
            estimatedTextIndex <= chapter.endIndex) {
          htmlContent = chapterHtml[chapter.id];
          break;
        }
      }
      
      // If we found HTML content, extract the relevant portion
      if (htmlContent != null && htmlContent.isNotEmpty) {
        // For simplicity, use the full chapter HTML for the page
        // In a more sophisticated implementation, we'd extract the specific portion
        _pages[i] = page.copyWith(originalHtml: htmlContent);
      }
    }
  }

  void clear() {
    _currentBook = null;
    _pages = [];
    _currentPageIndex = 0;
    _progress = null;
    _error = null;
    notifyListeners();
  }
}
