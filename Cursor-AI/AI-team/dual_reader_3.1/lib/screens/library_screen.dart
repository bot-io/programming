import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'dart:html' as html show File, FileReader, document if (dart.library.html);
import 'dart:typed_data';
import '../providers/book_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/book_card.dart';
import '../widgets/quick_tips_banner.dart';
import '../widgets/welcome_dialog.dart';
import '../widgets/pwa_install_banner.dart';
import '../models/reading_progress.dart';
import '../models/book.dart';
import '../services/storage_service.dart';
import '../services/help_service.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({Key? key}) : super(key: key);

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final Map<String, ReadingProgress?> _progressMap = {};
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _sortBy = 'recent'; // 'recent', 'title', 'author', 'progress'
  bool _isDragging = false;
  bool _dragHandlersSetup = false;

  @override
  void initState() {
    super.initState();
    _loadProgress();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
    // Show welcome dialog for first-time users
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        WelcomeDialog.checkAndShow(context);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProgress() async {
    final storageService = Provider.of<StorageService>(context, listen: false);
    final bookProvider = Provider.of<BookProvider>(context, listen: false);
    
    for (final book in bookProvider.books) {
      final progress = await storageService.getProgress(book.id);
      setState(() {
        _progressMap[book.id] = progress;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dual Reader'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              context.push('/help');
            },
            tooltip: 'Help & Documentation',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              context.push('/settings');
            },
            tooltip: 'Settings',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Tooltip(
                  message: HelpService.getTooltip('library_search'),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search books...',
                        helperText: HelpService.getTooltip('library_search'),
                        prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                child: Row(
                  children: [
                    const Text('Sort by: '),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Tooltip(
                        message: HelpService.getTooltip('library_sort'),
                        child: SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'recent', label: Text('Recent')),
                            ButtonSegment(value: 'title', label: Text('Title')),
                            ButtonSegment(value: 'author', label: Text('Author')),
                            ButtonSegment(value: 'progress', label: Text('Progress')),
                          ],
                          selected: {_sortBy},
                          onSelectionChanged: (Set<String> selection) {
                            setState(() {
                              _sortBy = selection.first;
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: kIsWeb
          ? PwaInstallBanner(
              child: _buildDragTarget(context),
            )
          : Consumer<BookProvider>(
              builder: (context, bookProvider, child) {
                return Column(
                  children: [
                    const QuickTipsBanner(),
                    Expanded(
                      child: _buildBody(context, bookProvider),
                    ),
                  ],
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Provider.of<BookProvider>(context, listen: false).importBook();
        },
        icon: const Icon(Icons.add),
        label: const Text('Import Book'),
        tooltip: HelpService.getTooltip('import_book'),
      ),
    );
  }

  Widget _buildDragTarget(BuildContext context) {
    return Consumer<BookProvider>(
      builder: (context, bookProvider, child) {
        // Setup drag handlers once
        if (kIsWeb && !_dragHandlersSetup) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _setupWebDragHandlers(context, bookProvider);
              _dragHandlersSetup = true;
            }
          });
        }
        
        return Column(
          children: [
            const QuickTipsBanner(),
            Expanded(
              child: Stack(
                children: [
                  _buildBody(context, bookProvider),
                  if (_isDragging)
              Container(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary,
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).colorScheme.shadow.withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.cloud_upload,
                          size: 64,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Drop EPUB or MOBI file here',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Release to import',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ),
              ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  void _setupWebDragHandlers(BuildContext context, BookProvider bookProvider) {
    if (!kIsWeb || _dragHandlersSetup) return;
    
    html.document.body?.onDragOver.listen((event) {
      event.preventDefault();
      event.stopPropagation();
      
      if (mounted) {
        setState(() {
          _isDragging = true;
        });
      }
    });
    
    html.document.body?.onDragLeave.listen((event) {
      if (mounted) {
        setState(() {
          _isDragging = false;
        });
      }
    });
    
    html.document.body?.onDrop.listen((event) async {
      event.preventDefault();
      event.stopPropagation();
      
      if (mounted) {
        setState(() {
          _isDragging = false;
        });
      }
      
      final files = event.dataTransfer?.files;
      if (files == null || files.isEmpty) return;
      
      final file = files[0];
      final fileName = file.name.toLowerCase();
      
      if (!fileName.endsWith('.epub') && !fileName.endsWith('.mobi')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unsupported file format. Please use EPUB or MOBI files.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
      
      final reader = html.FileReader();
      reader.onLoadEnd.listen((event) {
        final bytes = reader.result as Uint8List?;
        if (bytes != null && bytes.isNotEmpty) {
          bookProvider.importBookFromData(file.name, bytes);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to read file. Please try again.'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      });
      
      reader.readAsArrayBuffer(file);
    });
  }

  Widget _buildBody(BuildContext context, BookProvider bookProvider) {
    return Consumer<BookProvider>(
      builder: (context, bookProvider, child) {
          if (bookProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (bookProvider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    bookProvider.error!,
                    style: Theme.of(context).textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      bookProvider.importBook();
                    },
                    child: const Text('Try Again'),
                  ),
                ],
              ),
            );
          }

          if (bookProvider.books.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.library_books_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No books yet',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Import an EPUB or MOBI file to get started',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    HelpService.getTooltip('import_book'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Import Book'),
                    onPressed: () => bookProvider.importBook(),
                  ),
                ],
              ),
            );
          }

          // Filter and sort books
          List<Book> filteredBooks = bookProvider.books.where((book) {
            if (_searchQuery.isEmpty) return true;
            return book.title.toLowerCase().contains(_searchQuery) ||
                book.author.toLowerCase().contains(_searchQuery);
          }).toList();

          // Sort books
          filteredBooks.sort((a, b) {
            switch (_sortBy) {
              case 'title':
                return a.title.compareTo(b.title);
              case 'author':
                return a.author.compareTo(b.author);
              case 'progress':
                final progressA = _progressMap[a.id]?.progress ?? 0.0;
                final progressB = _progressMap[b.id]?.progress ?? 0.0;
                return progressB.compareTo(progressA); // Descending
              case 'recent':
              default:
                return b.addedAt.compareTo(a.addedAt); // Descending
            }
          });

          return RefreshIndicator(
            onRefresh: () async {
              await _loadProgress();
            },
            child: filteredBooks.isEmpty && _searchQuery.isNotEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 64,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No books found',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Try a different search term',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: filteredBooks.length,
                    itemBuilder: (context, index) {
                      final book = filteredBooks[index];
                      final progress = _progressMap[book.id];

                return BookCard(
                  book: book,
                  progress: progress,
                  onTap: () {
                    context.push('/reader/${book.id}');
                  },
                  onDelete: () {
                    _showDeleteDialog(context, bookProvider, book.id);
                  },
                );
              },
            ),
          );
        },
      );
  }

  void _showDeleteDialog(BuildContext context, BookProvider bookProvider, String bookId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Book'),
        content: const Text('Are you sure you want to delete this book?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              bookProvider.deleteBook(bookId);
              Navigator.pop(context);
              setState(() {
                _progressMap.remove(bookId);
              });
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
