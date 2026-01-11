import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dual_reader/src/core/di/injection_container.dart';
import 'package:dual_reader/src/domain/usecases/import_book_usecase.dart';
import 'package:go_router/go_router.dart';
import 'package:dual_reader/src/domain/usecases/delete_book_usecase.dart';
import 'package:dual_reader/src/presentation/providers/book_list_notifier.dart';
import 'package:dual_reader/src/presentation/providers/language_model_notifier.dart';
import 'package:dual_reader/src/presentation/providers/settings_notifier.dart';
import 'package:dual_reader/src/core/utils/language_utils.dart';
import 'package:file_picker/file_picker.dart';
import 'package:universal_io/io.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final books = ref.watch(bookListProvider);
    final settings = ref.watch(settingsProvider);
    final modelState = ref.watch(languageModelProvider);
    final targetLanguage = settings.targetTranslationLanguageCode;

    // Trigger language model download check on mobile platforms
    if (Platform.isAndroid || Platform.isIOS) {
      // Listen for state changes to rebuild UI when status changes
      ref.listen(languageModelProvider, (previous, next) {
        // State changes will trigger rebuild
      });

      // Trigger model check on first build - checks readiness BEFORE showing download UI
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final notifier = ref.read(languageModelProvider.notifier);
        final currentState = ref.read(languageModelProvider);

        // Only trigger check if status is notStarted
        // This prevents re-checking on every rebuild when status is already completed
        if (currentState.status == ModelDownloadStatus.notStarted) {
          notifier.checkAndDownloadRequiredModel(targetLanguage);
        }
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Library'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.go('/settings'),
            tooltip: 'Settings',
          ),
          IconButton(
            icon: const Icon(Icons.add_box_outlined),
            onPressed: () async {
              try {
                // Trigger file picker directly in the click handler for web compatibility
                final result = await FilePicker.platform.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: ['epub'],
                  withData: true,
                );

                if (result != null) {
                  final importBook = sl<ImportBookUseCase>();
                  await importBook(pickResult: result);

                  if (context.mounted) {
                    ref.read(bookListProvider.notifier).refreshBooks();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Book imported successfully!')),
                    );
                  }
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to import book: $e')),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Language model download progress banner
          if (modelState.status == ModelDownloadStatus.inProgress)
            Material(
              elevation: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: Colors.deepPurple.shade50,
                child: Row(
                  children: [
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Downloading ${LanguageUtils.getLanguageName(modelState.languageCode)} translation model...',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          if (modelState.progressMessage != null)
                            Text(
                              modelState.progressMessage!,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // Download success banner - only show after actual download, not on app startup
          if (modelState.status == ModelDownloadStatus.completed && modelState.showNotification)
            Material(
              elevation: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: Colors.green.shade50,
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${LanguageUtils.getLanguageName(modelState.languageCode)} model ready! Translations will be faster.',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Colors.green,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      color: Colors.grey,
                      onPressed: () {
                        // Dismiss the notification by setting showNotification to false
                        ref.read(languageModelProvider.notifier).dismissNotification();
                      },
                    ),
                  ],
                ),
              ),
            ),
          // Download error banner
          if (modelState.status == ModelDownloadStatus.failed && modelState.showNotification)
            Material(
              elevation: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: Colors.red.shade50,
                child: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.red, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Model download failed',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: Colors.red,
                            ),
                          ),
                          if (modelState.errorMessage != null)
                            Text(
                              modelState.errorMessage!,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        ref.read(languageModelProvider.notifier).downloadLanguageModel(modelState.languageCode);
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          // Book grid
          Expanded(
            child: books.isEmpty
                ? const Center(
                    child: Text('No books imported yet. Click the + icon to import a book.'),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(16.0),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16.0,
                      mainAxisSpacing: 16.0,
                      childAspectRatio: 0.7,
                    ),
                    itemCount: books.length,
                    itemBuilder: (context, index) {
                      final book = books[index];
                      return InkWell(
                        onTap: () => context.go('/read/${book.id}'),
                        onLongPress: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Delete Book'),
                              content: Text('Are you sure you want to delete "${book.title}"?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () async {
                                    final deleteBook = sl<DeleteBookUseCase>();
                                    await deleteBook(book.id);
                                    ref.read(bookListProvider.notifier).refreshBooks();
                                    if (context.mounted) Navigator.of(context).pop();
                                  },
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          );
                        },
                        child: Card(
                          elevation: 4.0,
                          child: Column(
                            children: [
                              Expanded(
                                child: book.coverPath.isNotEmpty && !kIsWeb
                                    ? Image.file(
                                        File(book.coverPath),
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                      )
                                    : Container(
                                        color: Colors.grey[300],
                                        child: const Icon(Icons.book, size: 50, color: Colors.grey),
                                      ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      book.title,
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      book.author,
                                      style: const TextStyle(color: Colors.grey),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (book.totalPages > 0)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8.0),
                                        child: LinearProgressIndicator(
                                          value: book.currentPage / book.totalPages,
                                          backgroundColor: Colors.grey[300],
                                          color: Colors.deepPurpleAccent,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
