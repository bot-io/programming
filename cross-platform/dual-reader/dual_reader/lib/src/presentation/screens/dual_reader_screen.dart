import 'package:flutter/material.dart';
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
import 'package:dual_reader/src/domain/usecases/update_book_progress_usecase.dart';
import 'package:dual_reader/src/domain/usecases/get_book_by_id_usecase.dart';
import 'package:dual_reader/src/presentation/providers/settings_notifier.dart';
import 'package:dual_reader/src/domain/entities/settings_entity.dart';
import 'package:dual_reader/src/presentation/screens/settings_screen.dart';
import 'package:html_unescape/html_unescape.dart';

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

class _DualReaderScreenState extends ConsumerState<DualReaderScreen> {
  BookEntity? _book;
  EpubBook? _epubBook;
  List<ChapterDisplayData> _chaptersDisplayData = [];
  List<String> _originalTextPages = [];
  final Map<int, String> _translatedTextPages = {};
  // Store paragraphs with their original indices for better translation
  final Map<int, List<String>> _pageParagraphs = {};
  int _currentOriginalPage = 0;
  int _totalOriginalPages = 0;
  bool _isLoading = true;
  String? _currentLanguage; // Track current language to detect changes

  final ScrollController _scrollController = ScrollController();

  final EpubParserService _epubParserService = sl<EpubParserService>();
  final PaginationService _paginationService = sl<PaginationService>();
  final TranslationService _translationService = sl<TranslationService>();
  final BookTranslationCacheService _bookTranslationCache = BookTranslationCacheService();
  final UpdateBookProgressUseCase _updateBookProgressUseCase = sl<UpdateBookProgressUseCase>();
  final GetBookByIdUseCase _getBookByIdUseCase = sl<GetBookByIdUseCase>();

  @override
  void initState() {
    super.initState();
    _bookTranslationCache.init();
    _loadBookAndPaginate();
    // No scroll sync needed - original panel is non-scrollable, translated panel is independently scrollable
  }

  Future<void> _loadBookAndPaginate() async {
    setState(() => _isLoading = true);

    final settings = ref.read(settingsProvider);
    _book = await _getBookByIdUseCase(widget.bookId);

    if (_book != null) {
      final fileBytes = await sl<BookRepository>().getBookBytes(_book!.id);
      if (fileBytes != null) {
        _epubBook = await _epubParserService.parseEpub(fileBytes);

        if (_epubBook != null && _epubBook!.Chapters != null && _epubBook!.Chapters!.isNotEmpty) {
          final unescape = HtmlUnescape();

          // Process each chapter separately to preserve chapter boundaries
          final List<String> allParagraphs = [];
          final List<ChapterDisplayData> tempChapters = [];
          int currentParagraphIndex = 0;

          for (final chapter in _epubBook!.Chapters!) {
            final chapterTitle = chapter.Title ?? 'Untitled Chapter';
            final content = chapter.HtmlContent ?? '';

            debugPrint('[DualReaderScreen] Processing chapter: "$chapterTitle"');
            debugPrint('[DualReaderScreen] Raw HTML length: ${content.length}');

            // Remove HTML tags but preserve content structure
            // Keep headings as they contain chapter titles and important content
            // Remove only common title-like paragraph patterns that duplicate chapter titles
            var cleaned = content.replaceAll(RegExp(r'''<p[^>]*class=["']?title["']?[^>]*>.*?</p>''', caseSensitive: false, dotAll: true), '');
            // Remove all other HTML tags except we keep the text content
            cleaned = cleaned.replaceAll(RegExp(r'<[^>]*>'), ' ');
            var unescaped = unescape.convert(cleaned).trim();

            // Add chapter title at the beginning if it's not already in the content
            final lowerTitle = chapterTitle.toLowerCase();
            if (!unescaped.toLowerCase().startsWith(lowerTitle)) {
              unescaped = '$chapterTitle\n\n$unescaped';
              debugPrint('[DualReaderScreen] Added chapter title to content. New length: ${unescaped.length}');
            }

            debugPrint('[DualReaderScreen] Cleaned text length: ${unescaped.length}');

            if (unescaped.isNotEmpty) {
              // Record where this chapter starts
              tempChapters.add(ChapterDisplayData(
                title: chapterTitle,
                startingPageIndex: currentParagraphIndex,
              ));

              // Split into paragraphs and add non-empty ones
              final paragraphs = unescaped
                  .split(RegExp(r'\n\s*\n'))
                  .map((p) => p.replaceAll(RegExp(r'\s+'), ' ').trim())
                  .where((p) {
                    // Filter out:
                    // 1. Empty paragraphs
                    // 2. Very short "paragraphs" (likely fragments)
                    if (p.isEmpty || p.length <= 2) return false;
                    return true;
                  })
                  .toList();

              debugPrint('[DualReaderScreen] Paragraphs in this chapter: ${paragraphs.length}');
              allParagraphs.addAll(paragraphs);
              currentParagraphIndex += paragraphs.length;
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
          _originalTextPages = _paginateByParagraphs(
            allParagraphs,
            constraints,
            textStyle,
            EdgeInsets.all(settings.margin),
            _pageParagraphs,
          );

          _totalOriginalPages = _originalTextPages.length;
          // Safety check: if no pages, set to 0
          if (_totalOriginalPages == 0) {
            debugPrint('[DualReaderScreen] WARNING: No pages generated from content');
            _currentOriginalPage = 0;
          } else {
            _currentOriginalPage = _book!.currentPage.clamp(0, _totalOriginalPages - 1);
          }

          // Convert paragraph-based chapter indices to page-based indices
          _chaptersDisplayData = [];
          for (final chapter in tempChapters) {
            // Find which page contains this paragraph index
            int accumulatedParagraphs = 0;
            int targetPageIndex = 0;
            for (int i = 0; i < _pageParagraphs.length; i++) {
              final paragraphsOnPage = _pageParagraphs[i]!.length;
              if (chapter.startingPageIndex >= accumulatedParagraphs &&
                  chapter.startingPageIndex < accumulatedParagraphs + paragraphsOnPage) {
                targetPageIndex = i;
                break;
              }
              accumulatedParagraphs += paragraphsOnPage;
            }

            _chaptersDisplayData.add(ChapterDisplayData(
              title: chapter.title,
              startingPageIndex: targetPageIndex,
            ));
          }

          _translateCurrentVisiblePage();
        }
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  /// Paginate text dynamically based on how much text fits in the text area
  /// Uses character-based pagination that respects sentence boundaries
  List<String> _paginateByParagraphs(
    List<String> paragraphs,
    BoxConstraints constraints,
    TextStyle textStyle,
    EdgeInsets padding,
    Map<int, List<String>> pageParagraphsMap,
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

    // For each page, extract which paragraphs it contains and preserve structure
    for (int i = 0; i < paginatedPages.length; i++) {
      final pageText = paginatedPages[i];
      pages.add(pageText);

      // Track paragraphs per page for translation
      // Split by double newlines to preserve paragraph structure
      final pageParagraphs = pageText.split(RegExp(r'\n\n+')).where((p) => p.trim().isNotEmpty).toList();
      pageParagraphsMap[i] = pageParagraphs;
    }

    debugPrint('[DualReaderScreen] Paginated into ${pages.length} pages');
    return pages;
  }

  Future<void> _translateCurrentVisiblePage() async {
    final settings = ref.read(settingsProvider);
    debugPrint('[DualReaderScreen] _translateCurrentVisiblePage: page=$_currentOriginalPage, targetLang=${settings.targetTranslationLanguageCode}');
    await _translatePageByParagraphs(_currentOriginalPage, settings.targetTranslationLanguageCode);
  }

  /// Translate page by paragraphs to maintain paragraph structure
  Future<void> _translatePageByParagraphs(int index, String targetLanguage) async {
    if (_translatedTextPages.containsKey(index)) {
      debugPrint('[DualReaderScreen] Page $index already translated, skipping');
      return;
    }
    if (index < 0 || index >= _originalTextPages.length) {
      debugPrint('[DualReaderScreen] Invalid index $index (total pages: ${_originalTextPages.length})');
      return;
    }

    try {
      final paragraphs = _pageParagraphs[index];
      if (paragraphs == null || paragraphs.isEmpty) {
        debugPrint('[DualReaderScreen] No paragraphs found for page $index');
        return;
      }

      final bookId = widget.bookId;
      final translatedParagraphs = <String>[];

      // Get the last sentence from the previous page for context (if available)
      String? contextSentence;
      if (index > 0 && _pageParagraphs.containsKey(index - 1)) {
        final prevParagraphs = _pageParagraphs[index - 1]!;
        if (prevParagraphs.isNotEmpty) {
          final lastParagraph = prevParagraphs.last;
          // Extract the last sentence from the previous paragraph
          final lastSentenceEnd = lastParagraph.lastIndexOf(RegExp(r'[.!?]\s'));
          if (lastSentenceEnd != -1 && lastSentenceEnd < lastParagraph.length - 2) {
            contextSentence = lastParagraph.substring(lastSentenceEnd + 1).trim();
            if (contextSentence.isNotEmpty) {
              debugPrint('[DualReaderScreen] Using context from previous page: "$contextSentence"');
            }
          }
        }
      }

      // Translate each paragraph separately
      for (int i = 0; i < paragraphs.length; i++) {
        final paragraph = paragraphs[i];
        // Create unique cache key by combining page and paragraph indices
        final cacheKey = '${index}_$i';

        // Check cache for this specific paragraph
        final cachedTranslation = _bookTranslationCache.getCachedTranslation(
          bookId,
          cacheKey.hashCode,
          targetLanguage,
        );

        if (cachedTranslation != null) {
          debugPrint('[DualReaderScreen] Using cached translation for paragraph $cacheKey');
          translatedParagraphs.add(cachedTranslation);
        } else {
          // Add context to the first paragraph of the page for better translation
          String textToTranslate = paragraph;
          if (i == 0 && contextSentence != null && contextSentence.isNotEmpty) {
            textToTranslate = '$contextSentence $paragraph';
            debugPrint('[DualReaderScreen] Translating with context (${textToTranslate.length} chars)');
          }

          debugPrint('[DualReaderScreen] Translating paragraph $cacheKey (${paragraph.length} chars) to $targetLanguage');
          final translated = await _translationService.translate(
            text: textToTranslate,
            targetLanguage: targetLanguage,
          );

          // If we added context, remove it from the translation before storing
          String translationToStore = translated;
          if (i == 0 && contextSentence != null && contextSentence.isNotEmpty) {
            // Try to remove the context from the beginning of the translation
            // This is a simple approach - the translator might not preserve the exact context
            final contextEnd = translated.indexOf(' ');
            if (contextEnd > 0 && contextEnd < translated.length / 3) {
              // The first word is likely the translated context, remove it
              translationToStore = translated.substring(contextEnd + 1).trim();
              debugPrint('[DualReaderScreen] Removed context from translation');
            }
          }

          // Cache this paragraph translation
          await _bookTranslationCache.cacheTranslation(
            bookId,
            cacheKey.hashCode,
            targetLanguage,
            translationToStore,
          );

          translatedParagraphs.add(translationToStore);
        }
      }

      // Join translated paragraphs with double newlines to preserve structure
      final translatedPage = translatedParagraphs.join('\n\n');
      _translatedTextPages[index] = translatedPage;

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('[DualReaderScreen] Translation error for page $index: $e');
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
        debugPrint('[DualReaderScreen] Using cached translation for page $index');
        translated = cachedTranslation;
      } else {
        debugPrint('[DualReaderScreen] Translating page $index (${originalText.length} chars) to $targetLanguage');
        translated = await _translationService.translate(
          text: originalText,
          targetLanguage: targetLanguage,
        );
        debugPrint('[DualReaderScreen] Translation complete for page $index, result length: ${translated.length}');

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
  void dispose() {
    _scrollController.dispose();
    if (_book != null) {
      _updateBookProgressUseCase.call(
        book: _book!,
        currentPage: _currentOriginalPage,
        totalPages: _totalOriginalPages,
      );
    }
    super.dispose();
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

    // Detect language change and refresh translations
    if (_currentLanguage != null && _currentLanguage != newLanguage) {
      debugPrint('[DualReaderScreen] Language changed from $_currentLanguage to $newLanguage, clearing translations');
      _translatedTextPages.clear();
      _currentLanguage = newLanguage;
      // Re-translate current page with new language
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _translateCurrentVisiblePage();
      });
    } else if (_currentLanguage == null) {
      _currentLanguage = newLanguage;
    }

    debugPrint('[DualReaderScreen] build: targetLang=$newLanguage, page=$_currentOriginalPage, translatedPages=${_translatedTextPages.keys.toList()}');

    return Scaffold(
      appBar: AppBar(
        title: Text(_book?.title ?? 'Dual Reader'),
        actions: [
          // Hot restart button (for development)
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _translatedTextPages.clear();
                _translateCurrentVisiblePage();
              });
            },
            tooltip: 'Refresh Translation',
          ),
          // Settings button
          IconButton(
            icon: const Icon(Icons.settings),
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
            Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.list_alt),
                onPressed: () => Scaffold.of(context).openEndDrawer(),
                tooltip: 'Table of Contents',
              ),
            ),
        ],
      ),
      endDrawer: _chaptersDisplayData.isNotEmpty
          ? Drawer(
              child: ListView.builder(
                itemCount: _chaptersDisplayData.length,
                itemBuilder: (context, index) {
                  final chapter = _chaptersDisplayData[index];
                  return ListTile(
                    title: Text(chapter.title),
                    onTap: () {
                      _goToPage(chapter.startingPageIndex);
                      Navigator.of(context).pop();
                    },
                  );
                },
              ),
            )
          : null,
      body: _isTwoPane()
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
      bottomNavigationBar: _buildPaginationControls(),
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
    final textStyle = Theme.of(context).textTheme.bodyLarge!.copyWith(
      fontSize: settings.fontSize,
      height: settings.lineHeight,
      fontFamily: settings.fontlFamily,
    );

    return Container(
      padding: EdgeInsets.all(settings.margin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.max,
        children: [
          SelectableText(title, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.grey)),
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
    final textStyle = Theme.of(context).textTheme.bodyLarge!.copyWith(
      fontSize: settings.fontSize,
      height: settings.lineHeight,
      fontFamily: settings.fontlFamily,
    );

    return Container(
      padding: EdgeInsets.all(settings.margin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(title, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.grey)),
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              child: SelectableText(
                content,
                textAlign: settings.textAlign,
                style: textStyle,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaginationControls() {
    return BottomAppBar(
      padding: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.arrow_back_ios, size: 20),
                onPressed: _currentOriginalPage > 0 ? () => _goToPage(_currentOriginalPage - 1) : null,
              ),
              Text(
                'Page ${_currentOriginalPage + 1} of $_totalOriginalPages',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.arrow_forward_ios, size: 20),
                onPressed: _currentOriginalPage < _totalOriginalPages - 1 ? () => _goToPage(_currentOriginalPage + 1) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _goToPage(int index) {
    if (index >= 0 && index < _totalOriginalPages) {
      setState(() {
        _currentOriginalPage = index;
        if (_scrollController.hasClients) _scrollController.jumpTo(0);
      });
      _translateCurrentVisiblePage();
    }
  }
}
