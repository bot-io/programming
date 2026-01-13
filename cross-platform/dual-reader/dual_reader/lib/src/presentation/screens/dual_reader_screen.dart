import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// import 'package:dual_screen/dual_screen.dart';  // Temporarily disabled
import 'package:epubx/epubx.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dual_reader/src/core/di/injection_container.dart';
import 'package:dual_reader/src/domain/entities/book_entity.dart';
import 'package:dual_reader/src/domain/repositories/book_repository.dart';
import 'package:dual_reader/src/domain/services/epub_parser_service.dart';
import 'package:dual_reader/src/domain/services/pagination_service.dart';
import 'package:dual_reader/src/domain/services/translation_service.dart';
import 'package:dual_reader/src/data/services/book_translation_cache_service.dart';
import 'package:dual_reader/src/data/services/chunk_translation_service.dart';
import 'package:dual_reader/src/data/services/chunk_cache_service.dart';
import 'package:dual_reader/src/data/services/client_side_translation_service.dart';
import 'package:dual_reader/src/domain/usecases/update_book_progress_usecase.dart';
import 'package:dual_reader/src/domain/usecases/get_book_by_id_usecase.dart';
import 'package:dual_reader/src/presentation/providers/settings_notifier.dart';
import 'package:dual_reader/src/domain/entities/settings_entity.dart';
import 'package:dual_reader/src/presentation/screens/settings_screen.dart';
import 'package:html_unescape/html_unescape.dart';
import 'package:dual_reader/src/core/utils/logging_service.dart';

class ChapterDisplayData {
  final String title;
  final int startingPageIndex;

  ChapterDisplayData({required this.title, required this.startingPageIndex});
}

class DualReaderScreen extends ConsumerStatefulWidget {
  final String bookId;

  const DualReaderScreen({super.key, required this.bookId});

  @override
  ConsumerState<DualReaderScreen> createState() => _DualReaderScreenState();
}

class _DualReaderScreenState extends ConsumerState<DualReaderScreen> with WidgetsBindingObserver {
  static const String _componentName = 'DualReaderScreen';

  BookEntity? _book;
  EpubBook? _epubBook;
  List<ChapterDisplayData> _chaptersDisplayData = [];
  List<String> _originalTextPages = [];
  final Map<int, String> _translatedTextPages = {};
  int _currentOriginalPage = 0;
  int _totalOriginalPages = 0;
  bool _isLoading = true;
  bool _controlsVisible = false; // Controls initially hidden in full screen mode
  bool _chapterDrawerVisible = false; // Chapter drawer state
  bool _isPreTranslating = false; // Flag to prevent concurrent pre-translations
  String? _currentLanguage; // Track current language to detect changes
  SettingsEntity? _previousSettings; // Track previous settings to detect layout changes

  final ScrollController _scrollController = ScrollController();

  final EpubParserService _epubParserService = sl<EpubParserService>();
  final PaginationService _paginationService = sl<PaginationService>();
  final TranslationService _translationService = sl<TranslationService>();
  final BookTranslationCacheService _bookTranslationCache = BookTranslationCacheService();
  final ChunkCacheService _chunkCacheService = sl<ChunkCacheService>();
  late final ChunkTranslationService _chunkTranslationService;
  final UpdateBookProgressUseCase _updateBookProgressUseCase = sl<UpdateBookProgressUseCase>();
  final GetBookByIdUseCase _getBookByIdUseCase = sl<GetBookByIdUseCase>();

  @override
  void initState() {
    super.initState();
    LoggingService.info(_componentName, 'Screen initialized - bookId: ${widget.bookId}');
    WidgetsBinding.instance.addObserver(this);
    _bookTranslationCache.init();
    _initializeChunkServices();
    _setFullScreen(true);
    _loadBookAndPaginate();
  }

  Future<void> _initializeChunkServices() async {
    final clientSideTranslationService = _translationService as ClientSideTranslationService;
    _chunkTranslationService = ChunkTranslationService(
      cacheService: _chunkCacheService,
      translationService: clientSideTranslationService,
    );

    LoggingService.info(_componentName, 'Chunk translation services initialized');
  }

  @override
  void dispose() {
    _exitFullScreen();
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _exitFullScreen() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _setFullScreen(true);
    }
  }

  Future<void> _setFullScreen(bool value) async {
    if (value) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  void _toggleControls() {
    setState(() {
      _controlsVisible = !_controlsVisible;
    });
    LoggingService.debug(_componentName, 'Controls toggled - now: ${_controlsVisible ? "visible" : "hidden"}');
  }

  void _toggleChapterDrawer() {
    setState(() {
      _chapterDrawerVisible = !_chapterDrawerVisible;
      if (_chapterDrawerVisible) {
        _controlsVisible = false; // Hide controls when showing drawer
      }
    });
  }

  /// Handle language change with cache clearing and validation
  Future<void> _handleLanguageChange(String newLanguage) async {
    if (_currentLanguage != null && _currentLanguage != newLanguage) {
      LoggingService.info(_componentName, 'Language changed - from: $_currentLanguage, to: $newLanguage');

      // Get cache stats before clearing
      final statsBefore = await _bookTranslationCache.getStats();
      LoggingService.info(_componentName, 'Cache stats before language change - $statsBefore');

      // Clear in-memory translations
      final translationsCleared = _translatedTextPages.length;
      _translatedTextPages.clear();
      LoggingService.info(_componentName, 'Cleared $translationsCleared in-memory translations');

      // Clear disk cache for current book (old page-based cache)
      await _bookTranslationCache.clearBook(widget.bookId);

      // Clear chunk cache for current book and new language
      await _chunkTranslationService.clearBook(widget.bookId);
      LoggingService.info(_componentName, 'Cleared chunk cache for book ${widget.bookId}');

      // Validate cache was cleared
      final statsAfter = await _bookTranslationCache.getStats();
      LoggingService.info(_componentName, 'Cache stats after language change - $statsAfter');

      // Verify clearing worked
      if (statsAfter[widget.bookId] != null && statsAfter[widget.bookId]! > 0) {
        LoggingService.error(_componentName, 'Cache clearing failed - book ${widget.bookId} still has ${statsAfter[widget.bookId]} entries');
      } else {
        LoggingService.info(_componentName, 'Cache cleared successfully for book ${widget.bookId}');
      }

      setState(() {
        _currentLanguage = newLanguage;
      });

      // Re-translate current page with new language
      _translateCurrentVisiblePage();
    } else if (_currentLanguage == null) {
      setState(() {
        _currentLanguage = newLanguage;
      });
    }
  }

  void _handleScreenTap(TapDownDetails details) {
    final screenWidth = MediaQuery.of(context).size.width;
    final position = details.globalPosition.dx;

    // Left 20% - previous page
    // Right 20% - next page
    // Middle 60% - toggle controls
    if (position < screenWidth * 0.2) {
      _goToPreviousPage();
    } else if (position > screenWidth * 0.8) {
      _goToNextPage();
    } else {
      _toggleControls();
    }
  }

  /// Extract chapter title from HTML content
  /// Looks for <title>, <h1>, <h2>, or <h3> tags and returns the text content
  String _extractChapterTitle(String html) {
    // Try to extract from <title> tag first
    final titleMatch = RegExp(r'<title[^>]*>(.*?)</title>', caseSensitive: false).firstMatch(html);
    if (titleMatch != null && titleMatch.group(1) != null) {
      final title = HtmlUnescape().convert(titleMatch.group(1)!).trim();
      if (title.isNotEmpty && title.length < 100) {
        return title;
      }
    }

    // Try to extract from <h1> tag (most common for chapter titles)
    final h1Match = RegExp(r'<h1[^>]*>(.*?)</h1>', caseSensitive: false).firstMatch(html);
    if (h1Match != null && h1Match.group(1) != null) {
      // Remove any HTML tags inside the h1
      var title = h1Match.group(1)!.replaceAll(RegExp(r'<[^>]*>'), '').trim();
      title = HtmlUnescape().convert(title);
      if (title.isNotEmpty && title.length < 100) {
        return title;
      }
    }

    // Try <h2> tag
    final h2Match = RegExp(r'<h2[^>]*>(.*?)</h2>', caseSensitive: false).firstMatch(html);
    if (h2Match != null && h2Match.group(1) != null) {
      var title = h2Match.group(1)!.replaceAll(RegExp(r'<[^>]*>'), '').trim();
      title = HtmlUnescape().convert(title);
      if (title.isNotEmpty && title.length < 100) {
        return title;
      }
    }

    // Try <h3> tag
    final h3Match = RegExp(r'<h3[^>]*>(.*?)</h3>', caseSensitive: false).firstMatch(html);
    if (h3Match != null && h3Match.group(1) != null) {
      var title = h3Match.group(1)!.replaceAll(RegExp(r'<[^>]*>'), '').trim();
      title = HtmlUnescape().convert(title);
      if (title.isNotEmpty && title.length < 100) {
        return title;
      }
    }

    return '';
  }

  /// Parse HTML content while preserving text structure (headings, paragraphs, line breaks)
  String _parseHtmlContent(String html, String chapterTitle) {
    final unescape = HtmlUnescape();

    // Add chapter title as a heading
    var result = '$chapterTitle\n\n';

    // Remove script and style tags
    var cleanHtml = html.replaceAll(RegExp(r'<(script|style)[^>]*>.*?</\1>', caseSensitive: false, dotAll: true), '');

    // Replace block-level tags with newlines before processing
    cleanHtml = cleanHtml.replaceAll(RegExp(r'</(h[1-6]|p|div|blockquote|li|article|section)>', caseSensitive: false), '\n\n');
    cleanHtml = cleanHtml.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');

    // Replace opening block tags with spacing
    cleanHtml = cleanHtml.replaceAll(RegExp(r'<(h[1-6]|p|blockquote)[^>]*>', caseSensitive: false), '\n\n');

    // Handle list items
    cleanHtml = cleanHtml.replaceAll(RegExp(r'<li[^>]*>', caseSensitive: false), '\n• ');

    // Remove all remaining HTML tags
    cleanHtml = cleanHtml.replaceAll(RegExp(r'<[^>]*>'), '');

    // Unescape HTML entities
    final text = unescape.convert(cleanHtml);

    LoggingService.debug(_componentName, 'Parsed HTML for "$chapterTitle" - raw text starts with: ${text.substring(0, text.length > 100 ? 100 : text.length)}');

    // Clean up whitespace
    final lines = text.split('\n');
    final cleanedLines = <String>[];

    for (var line in lines) {
      final trimmed = line.trim();
      if (trimmed.isNotEmpty) {
        cleanedLines.add(trimmed);
      } else if (cleanedLines.isNotEmpty && cleanedLines.last.isNotEmpty) {
        // Preserve paragraph breaks
        cleanedLines.add('');
      }
    }

    // Join with appropriate spacing
    result += cleanedLines.join('\n');

    // Clean up excessive blank lines
    result = result.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    final finalResult = result.trim();
    LoggingService.debug(_componentName, 'Final parsed text for "$chapterTitle" starts with: ${finalResult.substring(0, finalResult.length > 200 ? 200 : finalResult.length)}');

    return finalResult;
  }

  Future<void> _loadBookAndPaginate() async {
    setState(() => _isLoading = true);

    final settings = ref.read(settingsProvider);
    _book = await _getBookByIdUseCase(widget.bookId);

    if (_book != null) {
      final fileBytes = await sl<BookRepository>().getBookBytes(_book!.id);
      if (fileBytes != null) {
        _epubBook = await _epubParserService.parseEpub(fileBytes);

        if (_epubBook != null) {
          final unescape = HtmlUnescape();

          // Log Spine information to understand EPUB structure
          LoggingService.info(_componentName, 'EPUB Spine: ${_epubBook!.Chapters != null ? _epubBook!.Chapters!.length : 0} chapters');

          if (_epubBook!.Chapters != null) {
            for (int i = 0; i < _epubBook!.Chapters!.length; i++) {
              final ch = _epubBook!.Chapters![i];
              LoggingService.info(_componentName, '  Spine[$i]: "${ch.Title}" - SubChapters: ${ch.SubChapters?.length ?? 0}');
            }
          }

          // Log the actual reading order (Source links)
          if (_epubBook!.Schema != null && _epubBook!.Schema!.Package != null) {
            LoggingService.info(_componentName, 'EPUB Schema found');
            if (_epubBook!.Schema!.Package!.Manifest != null && _epubBook!.Schema!.Package!.Manifest!.Items != null) {
              LoggingService.info(_componentName, 'EPUB Manifest items: ${_epubBook!.Schema!.Package!.Manifest!.Items!.length}');
              // Log first 10 manifest items to understand file structure
              for (int i = 0; i < min(10, _epubBook!.Schema!.Package!.Manifest!.Items!.length); i++) {
                final item = _epubBook!.Schema!.Package!.Manifest!.Items![i];
                LoggingService.info(_componentName, '  Manifest[$i]: href="${item.Href}" type="${item.MediaType}"');
              }
            }

            // Log Spine order (actual reading order)
            if (_epubBook!.Schema!.Package!.Spine != null && _epubBook!.Schema!.Package!.Spine!.Items != null) {
              LoggingService.info(_componentName, 'EPUB Spine items: ${_epubBook!.Schema!.Package!.Spine!.Items!.length}');
              for (int i = 0; i < min(10, _epubBook!.Schema!.Package!.Spine!.Items!.length); i++) {
                final spineItem = _epubBook!.Schema!.Package!.Spine!.Items![i];
                LoggingService.info(_componentName, '  SpineItem[$i]: idref="${spineItem.IdRef}"');
              }
            }
          }

          // Process each chapter separately to preserve chapter boundaries
          final List<String> allParagraphs = [];
          final List<ChapterDisplayData> tempChapters = [];
          int currentParagraphIndex = 0;

          // Try to read content in Spine order (the actual reading order)
          // This is more reliable than epubBook.Chapters which may be in wrong order
          if (_epubBook!.Schema?.Package?.Spine?.Items != null &&
              _epubBook!.Content?.Html != null) {

            final spineItems = _epubBook!.Schema!.Package!.Spine!.Items!;
            final htmlFiles = _epubBook!.Content!.Html!;

            LoggingService.info(_componentName, 'Reading content in Spine order - ${spineItems.length} spine items, ${htmlFiles.length} HTML files');

            for (int i = 0; i < spineItems.length; i++) {
              final spineItem = spineItems[i];
              final idRef = spineItem.IdRef;

              // Find the HTML file corresponding to this spine item
              // The manifest item with this id should have the href
              String? href;
              if (_epubBook!.Schema?.Package?.Manifest?.Items != null) {
                for (final manifestItem in _epubBook!.Schema!.Package!.Manifest!.Items!) {
                  if (manifestItem.Id == idRef) {
                    href = manifestItem.Href;
                    break;
                  }
                }
              }

              if (href == null) {
                LoggingService.warning(_componentName, 'Spine[$i]: Could not find href for idref="$idRef"');
                continue;
              }

              // Get the HTML content
              final htmlFile = htmlFiles[href];
              if (htmlFile == null) {
                LoggingService.warning(_componentName, 'Spine[$i]: Could not find HTML file for href="$href"');
                continue;
              }

              final content = htmlFile.Content;
              if (content == null || content.isEmpty) {
                LoggingService.warning(_componentName, 'Spine[$i]: Empty content for href="$href"');
                continue;
              }

              // Try to extract chapter title from HTML content
              // Look for <title>, <h1>, <h2>, or <h3> tags
              String chapterTitle = _extractChapterTitle(content);

              // Fallback to filename if no title found
              if (chapterTitle.isEmpty || chapterTitle.length > 100) {
                // Clean up the filename to make it more presentable
                chapterTitle = href.split('/').last.replaceAll('.html', '').replaceAll('.xhtml', '');
                // Remove common prefixes and make it more readable
                chapterTitle = chapterTitle.replaceAll('index_split_', '').replaceAll('_', ' ').replaceAll('-', ' ').replaceAll('  ', ' ').trim();
                // Capitalize first letter
                if (chapterTitle.isNotEmpty) {
                  chapterTitle = chapterTitle[0].toUpperCase() + chapterTitle.substring(1);
                }
              }

              LoggingService.info(_componentName, 'Spine[$i]: "$chapterTitle" (from $href) - HTML: ${content.length} chars');

              // Parse HTML while preserving structure
              final parsedText = _parseHtmlContent(content, chapterTitle);

              LoggingService.info(_componentName, 'Spine[$i] "$chapterTitle" - Parsed text length: ${parsedText.length}');
              if (parsedText.isNotEmpty && parsedText.length > 100) {
                final preview = parsedText.length > 300 ? parsedText.substring(0, 300) : parsedText;
                LoggingService.info(_componentName, 'Spine[$i] "$chapterTitle" - First 300 chars: "$preview"');
              }

              if (parsedText.isNotEmpty) {
                // Record where this chapter starts
                tempChapters.add(ChapterDisplayData(
                  title: chapterTitle,
                  startingPageIndex: currentParagraphIndex,
                ));

                // Split into paragraphs by double newlines (preserves paragraph structure)
                final paragraphs = parsedText
                    .split(RegExp(r'\n\s*\n'))
                    .map((p) => p.replaceAll(RegExp(r'[ \t]+', multiLine: true), ' ').trim())
                    .where((p) => p.isNotEmpty)
                    .toList();

                LoggingService.info(_componentName, 'Spine[$i] "$chapterTitle" - Paragraphs: ${paragraphs.length}');
                allParagraphs.addAll(paragraphs);
                currentParagraphIndex += paragraphs.length;
              }
            }

            if (allParagraphs.isEmpty) {
              LoggingService.warning(_componentName, 'No content found in Spine, falling back to Chapters');
            }
          }

          // Fallback: Use the EPUB's Chapters if Spine didn't work
          if (allParagraphs.isEmpty) {
            final chaptersToProcess = _epubBook!.Chapters;

            if (chaptersToProcess != null && chaptersToProcess.isNotEmpty) {
              LoggingService.info(_componentName, 'Processing ${chaptersToProcess.length} chapters from EPUB Chapters (fallback)');

              // Log ALL chapters with their SubChapters before processing
              for (int i = 0; i < chaptersToProcess.length; i++) {
                final chapter = chaptersToProcess[i];
                final chapterTitle = chapter.Title ?? 'Untitled Chapter';
                final content = chapter.HtmlContent ?? '';
                final subChapterCount = chapter.SubChapters?.length ?? 0;
                LoggingService.info(_componentName, '  Chapter $i: "$chapterTitle" - HTML: ${content.length} chars, SubChapters: $subChapterCount');

                // Log SubChapters if any
                if (chapter.SubChapters != null && chapter.SubChapters!.isNotEmpty) {
                  for (int j = 0; j < chapter.SubChapters!.length; j++) {
                    final subChapter = chapter.SubChapters![j];
                    final subTitle = subChapter.Title ?? 'Untitled SubChapter';
                    final subContent = subChapter.HtmlContent ?? '';
                    LoggingService.info(_componentName, '    SubChapter $j: "$subTitle" - HTML: ${subContent.length} chars');
                  }
                }
              }

              // Don't filter - process all chapters to see complete structure
              LoggingService.info(_componentName, 'Processing all ${chaptersToProcess.length} chapters (no filtering)');

              for (final chapter in chaptersToProcess) {
                final chapterTitle = chapter.Title ?? 'Untitled Chapter';
                final content = chapter.HtmlContent ?? '';

                LoggingService.info(_componentName, 'Processing chapter: "$chapterTitle" - HTML length: ${content.length}');

                // Parse HTML while preserving structure
                final parsedText = _parseHtmlContent(content, chapterTitle);

                LoggingService.info(_componentName, 'Chapter "$chapterTitle" - Parsed text length: ${parsedText.length}');
                if (parsedText.isNotEmpty) {
                  final preview = parsedText.length > 300 ? parsedText.substring(0, 300) : parsedText;
                  LoggingService.info(_componentName, 'Chapter "$chapterTitle" - First 300 chars: "$preview"');
                }

                if (parsedText.isNotEmpty) {
                  // Record where this chapter starts
                  tempChapters.add(ChapterDisplayData(
                    title: chapterTitle,
                    startingPageIndex: currentParagraphIndex,
                  ));

                  // Split into paragraphs by double newlines (preserves paragraph structure)
                  final paragraphs = parsedText
                      .split(RegExp(r'\n\s*\n'))
                      .map((p) => p.replaceAll(RegExp(r'[ \t]+', multiLine: true), ' ').trim())
                      .where((p) => p.isNotEmpty)
                      .toList();

                  LoggingService.info(_componentName, 'Chapter "$chapterTitle" - Paragraphs: ${paragraphs.length}');
                  allParagraphs.addAll(paragraphs);
                  currentParagraphIndex += paragraphs.length;
                }
              }
            } else {
              // Fallback: Use the book's Title/Author as chapter header with full content
              LoggingService.warning(_componentName, 'No chapters found in EPUB, using book content');
              final bookTitle = _epubBook!.Title ?? 'Unknown Book';
              final bookAuthor = _epubBook!.Author ?? 'Unknown Author';

              // Combine all content from the book
              final fullContent = StringBuffer();
              fullContent.writeln('$bookTitle by $bookAuthor');
              fullContent.writeln();

              // Try to get content from each chapter in the TOC
              if (_epubBook!.Chapters != null) {
                for (final chapter in _epubBook!.Chapters!) {
                  if (chapter.SubChapters != null && chapter.SubChapters!.isNotEmpty) {
                    for (final subChapter in chapter.SubChapters!) {
                      final content = subChapter.HtmlContent ?? '';
                      if (content.isNotEmpty) {
                        fullContent.writeln(content);
                      }
                    }
                  }
                }
              }

              final parsedText = _parseHtmlContent(fullContent.toString(), bookTitle);
              final paragraphs = parsedText
                  .split(RegExp(r'\n\s*\n'))
                  .map((p) => p.replaceAll(RegExp(r'[ \t]+', multiLine: true), ' ').trim())
                  .where((p) => p.isNotEmpty)
                  .toList();

              LoggingService.info(_componentName, 'Fallback mode - Total paragraphs: ${paragraphs.length}');
              allParagraphs.addAll(paragraphs);
            }
          }

          // Calculate proper text area height for ONE panel
          // Since we always have 2 panels (original + translated), each gets half the available height
          // Available height = screen height - appbar - status bar - bottom nav
          final mediaQuery = MediaQuery.of(context);
          final appBarHeight = AppBar().preferredSize.height;
          final bottomNavHeight = 80.0; // Approximate height for pagination controls
          final panelLabelHeight = 40.0; // Height for "Original"/"Translated" label + spacing
          final totalAvailableHeight = mediaQuery.size.height -
              appBarHeight -
              mediaQuery.padding.top -
              bottomNavHeight;

          // Each panel (original or translated) gets half the available height minus panel label
          // This applies to both portrait (stacked) and landscape (side-by-side) layouts
          final availableHeight = (totalAvailableHeight / 2) - panelLabelHeight;

          final constraints = BoxConstraints(
            maxWidth: mediaQuery.size.width / (_isTwoPane() ? 2 : 1) - (settings.margin * 2),
            maxHeight: availableHeight,
          );

          final textStyle = Theme.of(context).textTheme.bodyLarge!.copyWith(
            fontSize: settings.fontSize,
            height: settings.lineHeight,
            fontFamily: settings.fontlFamily,
          );

          // Paginate by paragraph to avoid breaking sentences
          LoggingService.info(_componentName, 'Starting pagination - ${allParagraphs.length} paragraphs total');
          LoggingService.info(_componentName, 'Text area constraints: ${constraints.maxWidth.toInt()}x${constraints.maxHeight.toInt()}');

          _originalTextPages = _paginateByParagraphs(
            allParagraphs,
            constraints,
            textStyle,
            EdgeInsets.all(settings.margin),
          );

          LoggingService.info(_componentName, 'Pagination complete - ${_originalTextPages.length} pages generated');

          _totalOriginalPages = _originalTextPages.length;
          // Safety check: if no pages, set to 0
          if (_totalOriginalPages == 0) {
            debugPrint('[DualReaderScreen] WARNING: No pages generated from content');
            _currentOriginalPage = 0;
          } else {
            final savedPage = _book!.currentPage;
            _currentOriginalPage = savedPage.clamp(0, _totalOriginalPages - 1);
            LoggingService.info(_componentName, 'Book opened - saved page: $savedPage, current page: $_currentOriginalPage (total pages: $_totalOriginalPages)');
          }

          // Log first few pages for debugging
          LoggingService.info(_componentName, 'First 5 pages content preview:');
          for (int i = 0; i < min(5, _originalTextPages.length); i++) {
            final pagePreview = _originalTextPages[i].length > 200
                ? _originalTextPages[i].substring(0, 200)
                : _originalTextPages[i];
            LoggingService.info(_componentName, '  Page $i (${_originalTextPages[i].length} chars): "$pagePreview..."');
          }

          // Convert paragraph-based chapter indices to page-based indices
          _chaptersDisplayData = [];
          int accumulatedParagraphs = 0;

          // Find actual page indices by counting which page each paragraph lands on
          LoggingService.info(_componentName, 'Calculating chapter start pages from paragraph indices...');

          for (final chapter in tempChapters) {
            // Find which page this paragraph index actually starts on
            // by scanning through pages and finding which page contains this paragraph
            int targetPageIndex = 0;

            // Scan through pages to find where this chapter's first paragraph appears
            int paragraphsSeen = 0;
            for (int pageIndex = 0; pageIndex < _originalTextPages.length; pageIndex++) {
              final pageContent = _originalTextPages[pageIndex];

              // Count how many paragraph breaks are in this page
              // We need to find which paragraph this page starts with
              // This is approximate but should work well enough
              final paragraphsInThisPage = pageContent.split('\n\n').length;
              paragraphsSeen += paragraphsInThisPage;

              if (paragraphsSeen >= chapter.startingPageIndex + 1) {
                targetPageIndex = pageIndex;
                break;
              }
            }

            LoggingService.info(_componentName, 'Chapter "${chapter.title}" - paragraph index: ${chapter.startingPageIndex} → page index: $targetPageIndex');

            _chaptersDisplayData.add(ChapterDisplayData(
              title: chapter.title,
              startingPageIndex: targetPageIndex,
            ));
          }

          // Translation will start after loading completes (see below)
        }
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }

    // Start translation AFTER loading is complete to avoid blocking UI
    // Use a short delay to ensure UI has time to render
    await Future.delayed(const Duration(milliseconds: 50));
    if (mounted) {
      // Wrap in try-catch to prevent crashes during initial translation
      Future.microtask(() async {
        try {
          await _translateCurrentVisiblePage();
        } catch (e, stackTrace) {
          LoggingService.error(_componentName, 'Error translating initial page', error: e, stackTrace: stackTrace);
        }
      });
    }
  }

  /// Paginate text dynamically based on how much text fits in the text area
  /// Uses character-based pagination that respects sentence boundaries
  List<String> _paginateByParagraphs(
    List<String> paragraphs,
    BoxConstraints constraints,
    TextStyle textStyle,
    EdgeInsets padding,
  ) {
    final List<String> pages = [];
    final double pageWidth = constraints.maxWidth - padding.horizontal;
    final double pageHeight = constraints.maxHeight - padding.vertical;

    // Combine all paragraphs with double newlines
    final fullText = paragraphs.join('\n\n');

    // Use the pagination service to split text into pages that fit
    final paginatedPages = _paginationService.paginateText(
      text: fullText,
      constraints: BoxConstraints(maxWidth: pageWidth, maxHeight: pageHeight),
      textStyle: textStyle,
      lineHeight: textStyle.height ?? 1.5,
      padding: EdgeInsets.zero,
    );

    // Return the paginated pages directly
    pages.addAll(paginatedPages);

    debugPrint('[DualReaderScreen] Paginated into ${pages.length} pages');
    return pages;
  }

  Future<void> _translateCurrentVisiblePage() async {
    final settings = ref.read(settingsProvider);
    LoggingService.info(_componentName, 'Translating current page - page: $_currentOriginalPage, targetLang: ${settings.targetTranslationLanguageCode}');
    await _translatePageByParagraphs(_currentOriginalPage, settings.targetTranslationLanguageCode);
  }

  /// Pre-translate nearby pages to improve reading experience.
  /// Pre-translates 1 page ahead in the background without blocking UI.
  Future<void> _preTranslateNearbyPages(String targetLanguage) async {
    // Prevent multiple concurrent pre-translations
    if (_isPreTranslating) {
      LoggingService.debug(_componentName, 'Pre-translation already in progress, skipping');
      return;
    }

    _isPreTranslating = true;

    try {
      const pagesToPreTranslate = 1;

      LoggingService.debug(_componentName,
        'Pre-translating up to $pagesToPreTranslate page(s)');

      int preTranslatedCount = 0;

      // Pre-translate forward pages
      for (int i = 1; i <= pagesToPreTranslate; i++) {
        final nextPageIndex = _currentOriginalPage + i;

        // Check bounds
        if (nextPageIndex >= _totalOriginalPages) {
          LoggingService.debug(_componentName,
            'No more pages to pre-translate - reached end of book');
          break;
        }

        // Check if already translated
        if (_translatedTextPages.containsKey(nextPageIndex)) {
          LoggingService.debug(_componentName,
            'Page $nextPageIndex already translated, skipping');
          continue;
        }

        // Check cache
        final cacheKey = nextPageIndex;
        final cachedTranslation = _bookTranslationCache.getCachedTranslation(
          widget.bookId,
          cacheKey,
          targetLanguage,
        );

        if (cachedTranslation != null &&
            !cachedTranslation.startsWith('Translation failed:') &&
            !cachedTranslation.startsWith('[Exception:') &&
            !cachedTranslation.contains('ML Kit error')) {
          // Use cached translation
          _translatedTextPages[nextPageIndex] = cachedTranslation;
          LoggingService.debug(_componentName,
            'Using cached translation for pre-translation - page: $nextPageIndex');
          preTranslatedCount++;
          continue;
        }

        // Translate in background - use microtask to avoid blocking
        LoggingService.debug(_componentName,
          'Pre-translating page $nextPageIndex in background');
        Future.microtask(() => _translatePageByParagraphs(nextPageIndex, targetLanguage));
        preTranslatedCount++;
      }

      LoggingService.debug(_componentName,
        'Pre-translation initiated - $preTranslatedCount page(s) queued');
    } catch (e) {
      LoggingService.error(_componentName, 'Pre-translation failed', error: e);
      // Don't throw - pre-translation is optional
    } finally {
      // Reset flag after a short delay to ensure translations started
      Future.delayed(const Duration(milliseconds: 500), () {
        _isPreTranslating = false;
      });
    }
  }

  /// Translate page using chunk-based translation for better quality.
  ///
  /// This method groups multiple pages into chunks (3000-5000 characters) for
  /// translation, providing better context to the translation model while
  /// maintaining display parity between original and translated pages.
  Future<void> _translatePageByParagraphs(int index, String targetLanguage) async {
    if (_translatedTextPages.containsKey(index)) {
      LoggingService.debug(_componentName, 'Page already translated - page: $index, skipping');
      return;
    }
    if (index < 0 || index >= _originalTextPages.length) {
      LoggingService.warning(_componentName, 'Invalid page index - index: $index, total pages: ${_originalTextPages.length}');
      return;
    }

    final stopwatch = Stopwatch()..start();

    try {
      final pageText = _originalTextPages[index];
      if (pageText.isEmpty) {
        LoggingService.warning(_componentName, 'Page is empty - page: $index');
        return;
      }

      final bookId = widget.bookId;
      LoggingService.info(_componentName, 'Translating page (chunk-based) - book: $bookId, page: $index, text length: ${pageText.length} chars, target: $targetLanguage');

      // Use chunk-based translation service
      final translatedPage = await _chunkTranslationService.getPageTranslation(
        bookId: bookId,
        pageIndex: index,
        originalPageText: pageText,
        targetLanguage: targetLanguage,
        allPages: _originalTextPages,
      );

      stopwatch.stop();
      LoggingService.info(_componentName, 'Translation complete - page: $index, result length: ${translatedPage.length} chars, duration: ${stopwatch.elapsed.inMilliseconds}ms');

      _translatedTextPages[index] = translatedPage;

      if (mounted) {
        setState(() {});
      }

      // Trigger pre-translation of nearby chunks (non-blocking)
      // Use microtask to ensure it runs after current UI update
      Future.microtask(() => _chunkTranslationService.preTranslateNearbyChunks(
        bookId: bookId,
        currentPageIndex: index,
        targetLanguage: targetLanguage,
        allPages: _originalTextPages,
      ));
    } catch (e, stackTrace) {
      stopwatch.stop();
      LoggingService.error(_componentName, 'Translation failed - page: $index, duration: ${stopwatch.elapsed.inMilliseconds}ms', error: e, stackTrace: stackTrace);
      if (mounted) {
        setState(() {
          _translatedTextPages[index] = 'Translation failed: $e';
        });
      }
    }
  }

  Future<void> _translatePage(int index, String targetLanguage) async {
    if (_translatedTextPages.containsKey(index)) {
      debugPrint('[DualReaderScreen] _translatePage: page $index already translated, skipping');
      return;
    }
    if (index < 0 || index >= _originalTextPages.length) {
      debugPrint('[DualReaderScreen] _translatePage: invalid index $index (total pages: ${_originalTextPages.length})');
      return;
    }

    try {
      final originalText = _originalTextPages[index];

      // Check book-specific cache first
      final bookId = widget.bookId;
      final cachedTranslation = _bookTranslationCache.getCachedTranslation(
        bookId,
        index,
        targetLanguage,
      );

      String translated;
      if (cachedTranslation != null) {
        // Check if cached translation is an error message
        if (cachedTranslation.startsWith('Translation failed:') ||
            cachedTranslation.startsWith('[Exception:') ||
            cachedTranslation.contains('ML Kit error')) {
          debugPrint('[DualReaderScreen] Cached translation is an error, discarding and retranslating');
          // Don't use the cached error, proceed to retranslate
        } else {
          debugPrint('[DualReaderScreen] Using cached translation for page $index');
          translated = cachedTranslation;
          _translatedTextPages[index] = translated;
          if (mounted) {
            setState(() {});
          }
          return;
        }
      }

      debugPrint('[DualReaderScreen] Translating page $index (${originalText.length} chars) to $targetLanguage');
      translated = await _translationService.translate(
        text: originalText,
        targetLanguage: targetLanguage,
      );
      debugPrint('[DualReaderScreen] Translation complete for page $index, result length: ${translated.length}');

      // Only cache successful translations (not error messages)
      if (!translated.startsWith('Translation failed:') &&
          !translated.startsWith('[Exception:') &&
          !translated.contains('ML Kit error')) {
        // Cache the translation for future use
        await _bookTranslationCache.cacheTranslation(
          bookId,
          index,
          targetLanguage,
          translated,
        );
      }

      _translatedTextPages[index] = translated;
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('[DualReaderScreen] Translation error for page $index: $e');
      // Make the failure visible in the UI instead of leaving "Translating..." forever.
      _translatedTextPages[index] = 'Translation failed: $e';
      if (mounted) {
        setState(() {});
      }
    }
  }

  bool _isTwoPane() {
    final mediaQuery = MediaQuery.of(context);
    return mediaQuery.size.width > 700;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final settings = ref.watch(settingsProvider);
    final newLanguage = settings.targetTranslationLanguageCode;

    // Check if layout-related settings changed (font size, margin, line height, font family)
    final layoutChanged = _previousSettings != null &&
        (_previousSettings!.fontSize != settings.fontSize ||
         _previousSettings!.margin != settings.margin ||
         _previousSettings!.lineHeight != settings.lineHeight ||
         _previousSettings!.fontlFamily != settings.fontlFamily);

    if (layoutChanged) {
      debugPrint('[DualReaderScreen] Layout settings changed - repaginating book');
      debugPrint('[DualReaderScreen] Font: ${_previousSettings!.fontSize}->${settings.fontSize}, Margin: ${_previousSettings!.margin}->${settings.margin}, LineHeight: ${_previousSettings!.lineHeight}->${settings.lineHeight}');

      // Save the first visible character of the current page to restore position after repagination
      final currentText = _originalTextPages.elementAtOrNull(_currentOriginalPage) ?? '';
      final firstChar = currentText.isNotEmpty ? currentText[0] : '';

      WidgetsBinding.instance.addPostFrameCallback((_) async {
        // Clear cache for this book since pagination changed
        await _bookTranslationCache.clearBook(widget.bookId);

        // Repaginate with new settings
        await _loadBookAndPaginate();

        // Try to find the page containing the first character from before the change
        for (int i = 0; i < _originalTextPages.length; i++) {
          if (_originalTextPages[i].isNotEmpty && _originalTextPages[i][0] == firstChar) {
            setState(() {
              _currentOriginalPage = i;
            });
            debugPrint('[DualReaderScreen] Restored position to page $i (first char: $firstChar)');
            break;
          }
        }

        // Clear translations and retranslate current page
        _translatedTextPages.clear();
        _translateCurrentVisiblePage();
      });

      _previousSettings = settings;
    } else if (_previousSettings == null) {
      _previousSettings = settings;
    }

    // Detect language change and refresh translations with cache clearing
    if (_currentLanguage != null && _currentLanguage != newLanguage) {
      // Use addPostFrameCallback to handle async cache clearing
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleLanguageChange(newLanguage);
      });
    } else if (_currentLanguage == null) {
      _currentLanguage = newLanguage;
    }

    debugPrint('[DualReaderScreen] build: targetLang=$newLanguage, page=$_currentOriginalPage, translatedPages=${_translatedTextPages.keys.toList()}');

    final progressPercentage = _totalOriginalPages > 0
        ? ((_currentOriginalPage + 1) / _totalOriginalPages * 100).toStringAsFixed(1)
        : '0.0';

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      body: Stack(
        children: [
          // Main content (no GestureDetector wrapper - allows text selection)
          _isTwoPane()
              ? Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: _buildOriginalTextPanel('Original', _originalTextPages.elementAtOrNull(_currentOriginalPage) ?? '', settings),
                    ),
                    Expanded(
                      flex: 1,
                      child: _buildTranslatedTextPanel('Translated', _translatedTextPages[_currentOriginalPage] ?? 'Translating...', settings),
                    ),
                  ],
                )
              : Column(
                  children: [
                    Expanded(
                      flex: 1,
                      child: _buildOriginalTextPanel('Original', _originalTextPages.elementAtOrNull(_currentOriginalPage) ?? '', settings),
                    ),
                    Expanded(
                      flex: 1,
                      child: _buildTranslatedTextPanel('Translated', _translatedTextPages[_currentOriginalPage] ?? 'Translating...', settings),
                    ),
                  ],
                ),
          // Middle zone (outside text areas) for toggling controls
          Positioned(
            left: MediaQuery.of(context).size.width * 0.25,
            right: MediaQuery.of(context).size.width * 0.25,
            top: 0,
            bottom: 0,
            child: GestureDetector(
              onTap: () {
                LoggingService.debug(_componentName, 'Middle area tapped - toggling controls');
                _toggleControls();
              },
              behavior: HitTestBehavior.translucent, // Let taps pass through to text
            ),
          ),
          // Left margin zone for previous page navigation (25% of screen width)
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: MediaQuery.of(context).size.width * 0.25,
            child: GestureDetector(
              onTap: () {
                LoggingService.debug(_componentName, 'Left margin tapped - navigating to previous page');
                _goToPreviousPage();
              },
              behavior: HitTestBehavior.opaque,
            ),
          ),
          // Right margin zone for next page navigation (25% of screen width)
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: MediaQuery.of(context).size.width * 0.25,
            child: GestureDetector(
              onTap: () {
                LoggingService.debug(_componentName, 'Right margin tapped - navigating to next page');
                _goToNextPage();
              },
              behavior: HitTestBehavior.opaque,
            ),
          ),
          // Top controls (app bar)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            top: _controlsVisible ? 0 : -kToolbarHeight,
            left: 0,
            right: 0,
            child: Container(
              color: isDark
                  ? (Theme.of(context).appBarTheme.backgroundColor?.withOpacity(0.9) ?? Colors.grey[900]?.withOpacity(0.9))
                  : Colors.grey[100]?.withOpacity(0.95),
              child: SafeArea(
                bottom: false,
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.arrow_back,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Expanded(
                      child: Text(
                        _book?.title ?? 'Dual Reader',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.refresh,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      onPressed: () {
                        setState(() {
                          _translatedTextPages.clear();
                          _translateCurrentVisiblePage();
                        });
                      },
                      tooltip: 'Refresh Translation',
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.settings,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (context) => const SettingsScreen(),
                          ),
                        );
                      },
                      tooltip: 'Settings',
                    ),
                    if (_chaptersDisplayData.isNotEmpty)
                      IconButton(
                        icon: Icon(
                          Icons.list_alt,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        onPressed: () => _toggleChapterDrawer(),
                        tooltip: 'Table of Contents',
                      ),
                  ],
                ),
              ),
            ),
          ),
          // Bottom pagination controls (syncs with top bar)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            bottom: _controlsVisible ? 0 : -150,
            left: 0,
            right: 0,
            child: _buildPaginationControls(),
          ),
          // Chapter drawer overlay
          if (_chapterDrawerVisible && _chaptersDisplayData.isNotEmpty)
            GestureDetector(
              onTap: _toggleChapterDrawer,
              child: Container(
                color: isDark ? Colors.black.withOpacity(0.5) : Colors.black.withOpacity(0.3),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: () {}, // Prevent tap from closing immediately
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.7,
                      color: isDark
                          ? (Theme.of(context).drawerTheme.backgroundColor ?? Colors.grey[900])
                          : Colors.white,
                      child: SafeArea(
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Table of Contents',
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.close,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                    onPressed: _toggleChapterDrawer,
                                  ),
                                ],
                              ),
                            ),
                            const Divider(),
                            Expanded(
                              child: ListView.builder(
                                itemCount: _chaptersDisplayData.length,
                                itemBuilder: (context, index) {
                                  final chapter = _chaptersDisplayData[index];
                                  return ListTile(
                                    title: Text(chapter.title),
                                    onTap: () {
                                      _goToPage(chapter.startingPageIndex);
                                      _toggleChapterDrawer();
                                    },
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTextPanel(String title, ScrollController controller, String content, SettingsEntity settings) {
    final textStyle = Theme.of(context).textTheme.bodyLarge!.copyWith(
      fontSize: settings.fontSize,
      height: settings.lineHeight,
      fontFamily: settings.fontlFamily,
    );

    debugPrint('[DualReaderScreen] _buildTextPanel: title="$title", contentLength=${content.length}');

    return Container(
      padding: EdgeInsets.all(settings.margin),
      child: SingleChildScrollView(
        controller: controller,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(title, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.grey)),
            const SizedBox(height: 8),
            SelectableText(
              content,
              textAlign: settings.textAlign,
              style: textStyle,
            ),
          ],
        ),
      ),
    );
  }

  /// Build original text panel - NON-SCROLLABLE, text fits exactly on page
  Widget _buildOriginalTextPanel(String title, String content, SettingsEntity settings) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textStyle = Theme.of(context).textTheme.bodyLarge!.copyWith(
      fontSize: settings.fontSize,
      height: settings.lineHeight,
      fontFamily: settings.fontlFamily,
      color: isDark ? Colors.white : null,
    );

    return Container(
      padding: EdgeInsets.all(settings.margin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.max,
        children: [
          SelectableText(
            title,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: isDark ? Colors.white70 : Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Align(
              alignment: Alignment.topLeft,
              child: SelectableText(
                content,
                textAlign: settings.textAlign,
                style: textStyle,
                maxLines: null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build translated text panel - SCROLLABLE to handle longer translations
  Widget _buildTranslatedTextPanel(String title, String content, SettingsEntity settings) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textStyle = Theme.of(context).textTheme.bodyLarge!.copyWith(
      fontSize: settings.fontSize,
      height: settings.lineHeight,
      fontFamily: settings.fontlFamily,
      color: isDark ? Colors.white : null,
    );

    return Container(
      padding: EdgeInsets.all(settings.margin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(
            title,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: isDark ? Colors.white70 : Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              child: Align(
                alignment: Alignment.topLeft,
                child: SelectableText(
                  content,
                  textAlign: settings.textAlign,
                  style: textStyle,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaginationControls() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final progressPercentage = _totalOriginalPages > 0
        ? ((_currentOriginalPage + 1) / _totalOriginalPages * 100).toStringAsFixed(1)
        : '0.0';

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? (Theme.of(context).appBarTheme.backgroundColor?.withOpacity(0.9) ??
                Colors.grey[900]?.withOpacity(0.9))
            : Colors.grey[100]?.withOpacity(0.95),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Page slider
            SizedBox(
              height: 30,
              child: Slider(
                value: _currentOriginalPage.toDouble(),
                min: 0,
                max: (_totalOriginalPages > 0 ? _totalOriginalPages - 1 : 0).toDouble(),
                divisions: _totalOriginalPages > 1 ? _totalOriginalPages : 1,
                onChanged: (double value) => _goToPage(value.round()),
              ),
            ),
            // Navigation buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_ios, size: 20),
                    color: isDark ? Colors.white : Colors.black87,
                    onPressed: _currentOriginalPage > 0
                        ? () => _goToPage(_currentOriginalPage - 1)
                        : null,
                  ),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Page ${_currentOriginalPage + 1} of $_totalOriginalPages',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                        ),
                        Text(
                          '$progressPercentage%',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: isDark ? Colors.white70 : Colors.black54,
                                fontSize: 10,
                              ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.arrow_forward_ios, size: 20),
                    color: isDark ? Colors.white : Colors.black87,
                    onPressed: _currentOriginalPage < _totalOriginalPages - 1
                        ? () => _goToPage(_currentOriginalPage + 1)
                        : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _goToPage(int index) {
    if (index >= 0 && index < _totalOriginalPages) {
      LoggingService.info(_componentName, 'User navigated to page - from: $_currentOriginalPage, to: $index, total: $_totalOriginalPages');
      setState(() {
        _currentOriginalPage = index;
        if (_scrollController.hasClients) _scrollController.jumpTo(0);
      });
      // Start translation in background with error handling
      Future.microtask(() async {
        try {
          await _translateCurrentVisiblePage();
        } catch (e, stackTrace) {
          LoggingService.error(_componentName, 'Error translating page after navigation - page: $index', error: e, stackTrace: stackTrace);
        }
      });
      _saveProgress();
    } else {
      LoggingService.warning(_componentName, 'Invalid page navigation attempted - index: $index, total: $_totalOriginalPages');
    }
  }

  void _goToNextPage() {
    if (_currentOriginalPage < _totalOriginalPages - 1) {
      LoggingService.debug(_componentName, 'User tapped next page - current: $_currentOriginalPage');
      _goToPage(_currentOriginalPage + 1);
    } else {
      LoggingService.debug(_componentName, 'Next page unavailable - already at last page');
    }
  }

  void _goToPreviousPage() {
    if (_currentOriginalPage > 0) {
      LoggingService.debug(_componentName, 'User tapped previous page - current: $_currentOriginalPage');
      _goToPage(_currentOriginalPage - 1);
    } else {
      LoggingService.debug(_componentName, 'Previous page unavailable - already at first page');
    }
  }

  Future<void> _saveProgress() async {
    if (_book != null) {
      try {
        await _updateBookProgressUseCase(
          book: _book!,
          currentPage: _currentOriginalPage,
          totalPages: _totalOriginalPages,
        );
        debugPrint('[DualReaderScreen] Saved progress: page $_currentOriginalPage/$_totalOriginalPages');
      } catch (e) {
        debugPrint('[DualReaderScreen] Error saving progress: $e');
      }
    }
  }
}
