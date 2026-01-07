import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dual_reader/src/core/di/injection_container.dart';
import 'package:dual_reader/src/domain/usecases/import_book_usecase.dart';
import 'package:go_router/go_router.dart';
import 'package:dual_reader/src/domain/usecases/delete_book_usecase.dart';
import 'package:dual_reader/src/presentation/providers/book_list_notifier.dart';
import 'package:file_picker/file_picker.dart';
import 'package:universal_io/io.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final books = ref.watch(bookListProvider);

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
      body: books.isEmpty
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
    );
  }
}
