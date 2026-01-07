import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:simplenotes/models/note.dart';
import 'package:simplenotes/models/category.dart';
import 'package:simplenotes/providers/note_provider.dart';
import 'package:simplenotes/providers/category_provider.dart';
import 'package:simplenotes/providers/search_provider.dart';
import 'package:simplenotes/widgets/search_bar.dart';
import 'package:simplenotes/widgets/note_card.dart';
import 'package:simplenotes/widgets/empty_state.dart';
import 'package:simplenotes/utils/responsive.dart';

class NoteListScreen extends StatefulWidget {
  const NoteListScreen({super.key});

  @override
  State<NoteListScreen> createState() => _NoteListScreenState();
}

class _NoteListScreenState extends State<NoteListScreen> {
  String? _selectedCategoryId;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadNotes() async {
    final noteProvider = context.read<NoteProvider>();
    await noteProvider.loadNotes();
  }

  void _onCategoryFilterChanged(String? categoryId) {
    setState(() {
      _selectedCategoryId = categoryId;
    });
  }

  void _onNoteTap(Note note) {
    Navigator.pushNamed(
      context,
      '/note-detail',
      arguments: note.id,
    );
  }

  void _onCreateNote() {
    Navigator.pushNamed(context, '/note-detail');
  }

  void _onManageCategories() {
    Navigator.pushNamed(context, '/category-management');
  }

  List<Note> _getFilteredNotes(
    List<Note> allNotes,
    SearchProvider searchProvider,
    String? categoryId,
  ) {
    List<Note> filtered = allNotes;
    final searchQuery = searchProvider.query;

    // Apply category filter
    if (categoryId != null) {
      filtered = filtered.where((note) => note.categoryId == categoryId).toList();
    }

    // Apply search filter
    if (searchQuery.isNotEmpty) {
      final searchResults = searchProvider.results;
      if (searchResults.isNotEmpty) {
        // Filter search results by category if category filter is active
        if (categoryId != null) {
          filtered = searchResults
              .where((note) => note.categoryId == categoryId)
              .toList();
        } else {
          filtered = searchResults;
        }
      } else {
        // If search has no results, return empty list
        filtered = [];
      }
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);
    final isTablet = Responsive.isTablet(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Notes',
          style: TextStyle(
            fontSize: Theme.of(context).textTheme.titleLarge?.fontSize != null
                ? Theme.of(context).textTheme.titleLarge!.fontSize! * Responsive.getFontSizeMultiplier(context)
                : null,
          ),
        ),
        actions: [
          if (isDesktop || isTablet)
            TextButton.icon(
              icon: Icon(Icons.category, size: Responsive.getIconSize(context, baseSize: 20)),
              label: Text('Categories'),
              onPressed: _onManageCategories,
              style: TextButton.styleFrom(
                padding: Responsive.getButtonPadding(context),
              ),
            )
          else
            IconButton(
              icon: Icon(Icons.category, size: Responsive.getIconSize(context, baseSize: 24)),
              onPressed: _onManageCategories,
              tooltip: 'Manage categories',
            ),
          if (isDesktop || isTablet)
            TextButton.icon(
              icon: Icon(Icons.filter_list, size: Responsive.getIconSize(context, baseSize: 20)),
              label: Text('Filter'),
              onPressed: () => _showCategoryFilterDialog(),
              style: TextButton.styleFrom(
                padding: Responsive.getButtonPadding(context),
              ),
            )
          else
            IconButton(
              icon: Icon(Icons.filter_list, size: Responsive.getIconSize(context, baseSize: 24)),
              onPressed: () => _showCategoryFilterDialog(),
              tooltip: 'Filter by category',
            ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          const SearchBar(
            hintText: 'Search notes...',
          ),

          // Category Filter Chip (if category is selected)
          if (_selectedCategoryId != null)
            Consumer<CategoryProvider>(
              builder: (context, categoryProvider, child) {
                final category = categoryProvider.categories.firstWhere(
                  (cat) => cat.id == _selectedCategoryId,
                  orElse: () => Category(
                    id: '',
                    name: 'Unknown',
                    createdAt: DateTime.now(),
                  ),
                );
                return Padding(
                  padding: Responsive.getHorizontalPadding(context),
                  child: Row(
                    children: [
                      FilterChip(
                        label: Text(
                          'Category: ${category.name}',
                          style: TextStyle(
                            fontSize: Theme.of(context).textTheme.bodyMedium?.fontSize != null
                                ? Theme.of(context).textTheme.bodyMedium!.fontSize! * Responsive.getFontSizeMultiplier(context)
                                : null,
                          ),
                        ),
                        selected: true,
                        onSelected: (selected) {
                          if (!selected) {
                            _onCategoryFilterChanged(null);
                          }
                        },
                        deleteIcon: Icon(Icons.close, size: Responsive.getIconSize(context, baseSize: 18)),
                        onDeleted: () => _onCategoryFilterChanged(null),
                      ),
                    ],
                  ),
                );
              },
            ),

          // Notes List
          Expanded(
            child: Consumer3<NoteProvider, CategoryProvider, SearchProvider>(
              builder: (context, noteProvider, categoryProvider, searchProvider, child) {
                if (noteProvider.isLoading) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (noteProvider.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading notes',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          noteProvider.error ?? 'Unknown error',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadNotes,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                final allNotes = noteProvider.notes;
                final searchQuery = searchProvider.query;
                final filteredNotes = _getFilteredNotes(
                  allNotes,
                  searchProvider,
                  _selectedCategoryId,
                );

                if (filteredNotes.isEmpty) {
                  return EmptyState(
                    icon: searchQuery.isNotEmpty || _selectedCategoryId != null
                        ? Icons.search_off
                        : Icons.note_add,
                    message: searchQuery.isNotEmpty || _selectedCategoryId != null
                        ? 'No notes found'
                        : 'No notes yet',
                    subtitle: searchQuery.isNotEmpty
                        ? 'Try a different search term'
                        : _selectedCategoryId != null
                            ? 'No notes in this category'
                            : 'Create your first note to get started',
                    actionText: searchQuery.isNotEmpty || _selectedCategoryId != null
                        ? null
                        : 'Create Note',
                    onActionPressed: searchQuery.isNotEmpty || _selectedCategoryId != null
                        ? null
                        : _onCreateNote,
                  );
                }

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final isMobile = Responsive.isMobile(context);
                    final isTablet = Responsive.isTablet(context);
                    final isDesktop = Responsive.isDesktop(context);
                    
                    if (isMobile) {
                      // Mobile: Single column list
                      return RefreshIndicator(
                        onRefresh: _loadNotes,
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: Responsive.getPadding(context),
                          itemCount: filteredNotes.length,
                          itemBuilder: (context, index) {
                            final note = filteredNotes[index];
                            final category = note.categoryId != null
                                ? categoryProvider.categories.firstWhere(
                                    (cat) => cat.id == note.categoryId,
                                    orElse: () => null,
                                  )
                                : null;

                            return Padding(
                              padding: EdgeInsets.only(bottom: Responsive.getSpacing(context)),
                              child: NoteCard(
                                note: note,
                                category: category,
                                onTap: () => _onNoteTap(note),
                              ),
                            );
                          },
                        ),
                      );
                    } else {
                      // Tablet/Desktop: Grid layout with max width and responsive columns
                      final columns = Responsive.getGridColumns(context);
                      final maxWidth = Responsive.getMaxContentWidth(context);
                      final aspectRatio = isTablet 
                          ? (Responsive.isLandscape(context) ? 1.1 : 1.2)
                          : 1.0;
                      
                      return RefreshIndicator(
                        onRefresh: _loadNotes,
                        child: Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: maxWidth,
                            ),
                            child: GridView.builder(
                              controller: _scrollController,
                              padding: Responsive.getPadding(context),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                crossAxisSpacing: Responsive.getSpacing(context) * 2,
                                mainAxisSpacing: Responsive.getSpacing(context) * 2,
                                childAspectRatio: aspectRatio,
                              ),
                              itemCount: filteredNotes.length,
                              itemBuilder: (context, index) {
                                final note = filteredNotes[index];
                                final category = note.categoryId != null
                                    ? categoryProvider.categories.firstWhere(
                                        (cat) => cat.id == note.categoryId,
                                        orElse: () => null,
                                      )
                                    : null;

                                return NoteCard(
                                  note: note,
                                  category: category,
                                  onTap: () => _onNoteTap(note),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = Responsive.isDesktop(context);
          final isTablet = Responsive.isTablet(context);
          
          if (isDesktop || isTablet) {
            return FloatingActionButton.extended(
              onPressed: _onCreateNote,
              icon: Icon(Icons.add, size: Responsive.getIconSize(context, baseSize: 20)),
              label: Text(
                'New Note',
                style: TextStyle(
                  fontSize: Theme.of(context).textTheme.labelLarge?.fontSize != null
                      ? Theme.of(context).textTheme.labelLarge!.fontSize! * Responsive.getFontSizeMultiplier(context)
                      : null,
                ),
              ),
            );
          }
          
          return FloatingActionButton(
            onPressed: _onCreateNote,
            tooltip: 'Create new note',
            child: Icon(
              Icons.add,
              size: Responsive.getIconSize(context, baseSize: 24),
            ),
          );
        },
      ),
    );
  }

  void _showCategoryFilterDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(Responsive.getBorderRadius(context)),
        ),
      ),
      builder: (context) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = Responsive.isMobile(context);
            final maxHeight = Responsive.getHeight(context) * Responsive.getBottomSheetHeight(context);
            
            return ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: Responsive.isMobile(context) 
                    ? double.infinity 
                    : Responsive.getDialogWidth(context),
                maxHeight: maxHeight,
              ),
              child: Consumer<CategoryProvider>(
                builder: (context, categoryProvider, child) {
                  final categories = categoryProvider.categories;
                  final padding = Responsive.getPadding(context);
                  final spacing = Responsive.getSpacing(context);
                  final fontSizeMultiplier = Responsive.getFontSizeMultiplier(context);
                  final theme = Theme.of(context);

                  return Container(
                    padding: padding,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Filter by Category',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontSize: theme.textTheme.titleLarge?.fontSize != null
                                ? theme.textTheme.titleLarge!.fontSize! * fontSizeMultiplier
                                : null,
                          ),
                        ),
                        SizedBox(height: spacing * 2),
                        Flexible(
                          child: ListView(
                            shrinkWrap: true,
                            children: [
                              ListTile(
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: spacing,
                                  vertical: spacing / 2,
                                ),
                                title: Text(
                                  'All Notes',
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    fontSize: theme.textTheme.bodyLarge?.fontSize != null
                                        ? theme.textTheme.bodyLarge!.fontSize! * fontSizeMultiplier
                                        : null,
                                  ),
                                ),
                                leading: Radio<String?>(
                                  value: null,
                                  groupValue: _selectedCategoryId,
                                  onChanged: (value) {
                                    _onCategoryFilterChanged(value);
                                    Navigator.pop(context);
                                  },
                                ),
                              ),
                              ...categories.map((category) {
                                return ListTile(
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: spacing,
                                    vertical: spacing / 2,
                                  ),
                                  title: Text(
                                    category.name,
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      fontSize: theme.textTheme.bodyLarge?.fontSize != null
                                          ? theme.textTheme.bodyLarge!.fontSize! * fontSizeMultiplier
                                          : null,
                                    ),
                                  ),
                                  leading: Radio<String?>(
                                    value: category.id,
                                    groupValue: _selectedCategoryId,
                                    onChanged: (value) {
                                      _onCategoryFilterChanged(value);
                                      Navigator.pop(context);
                                    },
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
          ),
        );
      },
    );
  }
}
