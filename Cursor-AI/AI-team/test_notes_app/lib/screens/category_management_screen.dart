import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:simplenotes/models/category.dart';
import 'package:simplenotes/providers/category_provider.dart';
import 'package:simplenotes/widgets/empty_state.dart';
import 'package:simplenotes/utils/responsive.dart';

/// Screen for managing categories.
/// 
/// This screen allows users to:
/// - View all categories in a list
/// - Create new categories
/// - Edit existing categories (name and color)
/// - Delete categories with confirmation
/// - See note counts for each category
class CategoryManagementScreen extends StatefulWidget {
  const CategoryManagementScreen({super.key});

  @override
  State<CategoryManagementScreen> createState() => _CategoryManagementScreenState();
}

class _CategoryManagementScreenState extends State<CategoryManagementScreen> {
  @override
  void initState() {
    super.initState();
    // Load categories when screen is initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final categoryProvider = context.read<CategoryProvider>();
      categoryProvider.loadCategories();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Manage Categories',
          style: TextStyle(
            fontSize: Theme.of(context).textTheme.titleLarge?.fontSize != null
                ? Theme.of(context).textTheme.titleLarge!.fontSize! * Responsive.getFontSizeMultiplier(context)
                : null,
          ),
        ),
      ),
      body: Consumer<CategoryProvider>(
        builder: (context, categoryProvider, child) {
          // Show loading indicator
          if (categoryProvider.isLoading && categoryProvider.categories.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          // Show error message if there's an error
          if (categoryProvider.hasError && categoryProvider.categories.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: Responsive.getEmptyStateIconSize(context),
                    color: Theme.of(context).colorScheme.error,
                  ),
                  SizedBox(height: Responsive.getSpacing(context) * 2),
                  Text(
                    'Error loading categories',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontSize: Theme.of(context).textTheme.titleMedium?.fontSize != null
                          ? Theme.of(context).textTheme.titleMedium!.fontSize! * Responsive.getFontSizeMultiplier(context)
                          : null,
                    ),
                  ),
                  SizedBox(height: Responsive.getSpacing(context)),
                  Text(
                    categoryProvider.error ?? 'Unknown error',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: Theme.of(context).textTheme.bodyMedium?.fontSize != null
                          ? Theme.of(context).textTheme.bodyMedium!.fontSize! * Responsive.getFontSizeMultiplier(context)
                          : null,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: Responsive.getSpacing(context) * 3),
                  ElevatedButton(
                    onPressed: () => categoryProvider.loadCategories(),
                    style: ElevatedButton.styleFrom(
                      padding: Responsive.getButtonPadding(context),
                    ),
                    child: Text(
                      'Retry',
                      style: TextStyle(
                        fontSize: Theme.of(context).textTheme.labelLarge?.fontSize != null
                            ? Theme.of(context).textTheme.labelLarge!.fontSize! * Responsive.getFontSizeMultiplier(context)
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          // Show empty state if no categories
          if (categoryProvider.isEmpty) {
            return EmptyState(
              icon: Icons.category_outlined,
              message: 'No categories yet',
              subtitle: 'Create your first category to organize your notes',
              actionText: 'Create Category',
              onActionPressed: () => _showCreateCategoryDialog(context),
            );
          }

          // Show category list
          return RefreshIndicator(
            onRefresh: () => categoryProvider.loadCategories(),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = Responsive.isMobile(context);
                
                if (isMobile) {
                  // Mobile: Single column list
                  return ListView.builder(
                    padding: Responsive.getPadding(context),
                    itemCount: categoryProvider.categories.length,
                    itemBuilder: (context, index) {
                      final category = categoryProvider.categories[index];
                      return _CategoryListItem(
                        category: category,
                        onEdit: () => _showEditCategoryDialog(context, category),
                        onDelete: () => _showDeleteCategoryDialog(context, category),
                      );
                    },
                  );
                } else {
                  // Tablet/Desktop: Grid layout with max width
                  return Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: Responsive.getMaxContentWidth(context),
                      ),
                      child: GridView.builder(
                        padding: Responsive.getPadding(context),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: Responsive.getGridColumns(context),
                          crossAxisSpacing: Responsive.getSpacing(context) * 2,
                          mainAxisSpacing: Responsive.getSpacing(context) * 2,
                          childAspectRatio: Responsive.getCategoryCardAspectRatio(context),
                        ),
                        itemCount: categoryProvider.categories.length,
                        itemBuilder: (context, index) {
                          final category = categoryProvider.categories[index];
                          return _CategoryListItem(
                            category: category,
                            onEdit: () => _showEditCategoryDialog(context, category),
                            onDelete: () => _showDeleteCategoryDialog(context, category),
                          );
                        },
                      ),
                    ),
                  );
                }
              },
            ),
          );
        },
      ),
      floatingActionButton: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = Responsive.isDesktop(context);
          final isTablet = Responsive.isTablet(context);
          
          if (isDesktop || isTablet) {
            return FloatingActionButton.extended(
              onPressed: () => _showCreateCategoryDialog(context),
              icon: Icon(Icons.add, size: Responsive.getIconSize(context, baseSize: 20)),
              label: Text(
                'Create Category',
                style: TextStyle(
                  fontSize: Theme.of(context).textTheme.labelLarge?.fontSize != null
                      ? Theme.of(context).textTheme.labelLarge!.fontSize! * Responsive.getFontSizeMultiplier(context)
                      : null,
                ),
              ),
            );
          }
          
          return FloatingActionButton(
            onPressed: () => _showCreateCategoryDialog(context),
            tooltip: 'Create Category',
            child: Icon(Icons.add, size: Responsive.getIconSize(context, baseSize: 24)),
          );
        },
      ),
    );
  }

  /// Shows a dialog for creating a new category.
  void _showCreateCategoryDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: Responsive.getDialogWidth(context),
          ),
          child: _CategoryDialog(
            category: null,
            onSave: (name, color) async {
              final categoryProvider = context.read<CategoryProvider>();
              try {
                await categoryProvider.createCategory(
                  name: name,
                  color: color?.isEmpty ?? true ? null : color,
                );
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Category created successfully'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              } catch (e) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(
                      content: Text('Failed to create category: ${e.toString()}'),
                      backgroundColor: Theme.of(dialogContext).colorScheme.error,
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }
              }
            },
          ),
        ),
      ),
    );
  }

  /// Shows a dialog for editing an existing category.
  void _showEditCategoryDialog(BuildContext context, Category category) {
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: Responsive.getDialogWidth(context),
          ),
          child: _CategoryDialog(
            category: category,
            onSave: (name, color) async {
              final categoryProvider = context.read<CategoryProvider>();
              try {
                await categoryProvider.updateCategory(
                  categoryId: category.id,
                  name: name != category.name ? name : null,
                  color: color?.isEmpty ?? true ? null : color,
                );
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Category updated successfully'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              } catch (e) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(
                      content: Text('Failed to update category: ${e.toString()}'),
                      backgroundColor: Theme.of(dialogContext).colorScheme.error,
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }
              }
            },
          ),
        ),
      ),
    );
  }

  /// Shows a confirmation dialog for deleting a category.
  void _showDeleteCategoryDialog(BuildContext context, Category category) {
    showDialog(
      context: context,
      builder: (dialogContext) => LayoutBuilder(
        builder: (context, constraints) => SizedBox(
          width: Responsive.getDialogWidth(context),
          child: AlertDialog(
        contentPadding: Responsive.getPadding(context),
        title: Text(
          'Delete Category',
          style: TextStyle(
            fontSize: Theme.of(context).textTheme.titleLarge?.fontSize != null
                ? Theme.of(context).textTheme.titleLarge!.fontSize! * Responsive.getFontSizeMultiplier(context)
                : null,
          ),
        ),
        content: FutureBuilder<int>(
          future: context.read<CategoryProvider>().getNoteCount(category.id),
          builder: (context, snapshot) {
            final noteCount = snapshot.data ?? 0;
            return Text(
              noteCount > 0
                  ? 'Are you sure you want to delete "${category.name}"?\n\n'
                      'This category has $noteCount note${noteCount == 1 ? '' : 's'}. '
                      'These notes will be unassigned from this category.'
                  : 'Are you sure you want to delete "${category.name}"?',
              style: TextStyle(
                fontSize: Theme.of(context).textTheme.bodyMedium?.fontSize != null
                    ? Theme.of(context).textTheme.bodyMedium!.fontSize! * Responsive.getFontSizeMultiplier(context)
                    : null,
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            style: TextButton.styleFrom(
              padding: Responsive.getButtonPadding(context),
            ),
            child: Text(
              'Cancel',
              style: TextStyle(
                fontSize: Theme.of(context).textTheme.labelLarge?.fontSize != null
                    ? Theme.of(context).textTheme.labelLarge!.fontSize! * Responsive.getFontSizeMultiplier(context)
                    : null,
              ),
            ),
          ),
          FilledButton(
            onPressed: () async {
              final categoryProvider = context.read<CategoryProvider>();
              try {
                final reassignedCount = await categoryProvider.deleteCategory(
                  categoryId: category.id,
                  reassignToCategoryId: null,
                );
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        reassignedCount > 0
                            ? 'Category deleted. $reassignedCount note${reassignedCount == 1 ? '' : 's'} unassigned.'
                            : 'Category deleted successfully',
                      ),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              } catch (e) {
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to delete category: ${e.toString()}'),
                      backgroundColor: Theme.of(context).colorScheme.error,
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              padding: Responsive.getButtonPadding(context),
            ),
            child: Text(
              'Delete',
              style: TextStyle(
                fontSize: Theme.of(context).textTheme.labelLarge?.fontSize != null
                    ? Theme.of(context).textTheme.labelLarge!.fontSize! * Responsive.getFontSizeMultiplier(context)
                    : null,
              ),
            ),
          ),
        ],
          ),
        ),
      ),
    );
  }
}

/// A list item widget for displaying a category with edit and delete actions.
class _CategoryListItem extends StatelessWidget {
  /// The category to display.
  final Category category;

  /// Callback invoked when edit is requested.
  final VoidCallback onEdit;

  /// Callback invoked when delete is requested.
  final VoidCallback onDelete;

  const _CategoryListItem({
    required this.category,
    required this.onEdit,
    required this.onDelete,
  });

  /// Parses a hex color string to a Color object.
  Color? _parseColor(String? colorString) {
    if (colorString == null || colorString.isEmpty) {
      return null;
    }

    try {
      String hex = colorString.replaceFirst('#', '');
      if (hex.length == 6) {
        return Color(int.parse('FF$hex', radix: 16));
      }
      if (hex.length == 8) {
        return Color(int.parse(hex, radix: 16));
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final categoryColor = _parseColor(category.color);
    final fontSizeMultiplier = Responsive.getFontSizeMultiplier(context);
    final iconSize = Responsive.getIconSize(context, baseSize: 24);

    return Card(
      margin: EdgeInsets.only(bottom: Responsive.getSpacing(context)),
      child: ListTile(
        contentPadding: Responsive.getCardPadding(context),
        leading: Container(
          width: Responsive.isMobile(context) ? 48 : 56,
          height: Responsive.isMobile(context) ? 48 : 56,
          decoration: BoxDecoration(
            color: categoryColor ?? colorScheme.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: categoryColor != null
              ? null
              : Icon(
                  Icons.category,
                  color: colorScheme.onPrimaryContainer,
                  size: iconSize,
                ),
        ),
        title: Text(
          category.name,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: theme.textTheme.titleMedium?.fontSize != null
                ? theme.textTheme.titleMedium!.fontSize! * fontSizeMultiplier
                : null,
          ),
        ),
        subtitle: FutureBuilder<int>(
          future: context.read<CategoryProvider>().getNoteCount(category.id),
          builder: (context, snapshot) {
            final noteCount = snapshot.data ?? 0;
            return Text(
              '$noteCount note${noteCount == 1 ? '' : 's'}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontSize: theme.textTheme.bodySmall?.fontSize != null
                    ? theme.textTheme.bodySmall!.fontSize! * fontSizeMultiplier
                    : null,
              ),
            );
          },
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.edit_outlined, size: iconSize),
              onPressed: onEdit,
              tooltip: 'Edit category',
            ),
            IconButton(
              icon: Icon(Icons.delete_outline, size: iconSize),
              onPressed: onDelete,
              tooltip: 'Delete category',
              color: colorScheme.error,
            ),
          ],
        ),
      ),
    );
  }
}

/// A dialog widget for creating or editing a category.
class _CategoryDialog extends StatefulWidget {
  /// The category to edit, or null if creating a new category.
  final Category? category;

  /// Callback invoked when the category is saved.
  /// 
  /// Parameters: (name, color)
  final Future<void> Function(String name, String? color) onSave;

  const _CategoryDialog({
    required this.category,
    required this.onSave,
  });

  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _colorController;
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.category?.name ?? '');
    _colorController = TextEditingController(text: widget.category?.color ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _colorController.dispose();
    super.dispose();
  }

  /// Validates the color format.
  String? _validateColor(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Color is optional
    }

    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null; // Empty string means no color
    }

    // Check if it's a valid hex color format
    final hexPattern = RegExp(r'^#([A-Fa-f0-9]{6}|[A-Fa-f0-9]{8})$');
    if (!hexPattern.hasMatch(trimmed)) {
      return 'Color must be in hex format (e.g., #RRGGBB or #AARRGGBB)';
    }

    return null;
  }

  /// Validates the category name.
  String? _validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Category name is required';
    }

    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return 'Category name cannot be whitespace only';
    }

    if (trimmed.length > 100) {
      return 'Category name cannot exceed 100 characters';
    }

    return null;
  }

  /// Handles the save action.
  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final name = _nameController.text.trim();
      final color = _colorController.text.trim();
      await widget.onSave(name, color.isEmpty ? null : color);
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.category != null;
    final fontSizeMultiplier = Responsive.getFontSizeMultiplier(context);
    final spacing = Responsive.getSpacing(context) * 2;

    return AlertDialog(
      contentPadding: Responsive.getPadding(context),
      title: Text(
        isEditing ? 'Edit Category' : 'Create Category',
        style: TextStyle(
          fontSize: theme.textTheme.titleLarge?.fontSize != null
              ? theme.textTheme.titleLarge!.fontSize! * fontSizeMultiplier
              : null,
        ),
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                style: TextStyle(
                  fontSize: theme.textTheme.bodyLarge?.fontSize != null
                      ? theme.textTheme.bodyLarge!.fontSize! * fontSizeMultiplier
                      : null,
                ),
                decoration: InputDecoration(
                  labelText: 'Category Name',
                  hintText: 'Enter category name',
                  prefixIcon: Icon(Icons.label_outline, size: Responsive.getIconSize(context, baseSize: 24)),
                  contentPadding: Responsive.getTextFieldPadding(context),
                ),
                textCapitalization: TextCapitalization.words,
                autofocus: true,
                enabled: !_isSaving,
                validator: _validateName,
                onFieldSubmitted: (_) => _handleSave(),
              ),
              SizedBox(height: spacing),
              TextFormField(
                controller: _colorController,
                style: TextStyle(
                  fontSize: theme.textTheme.bodyLarge?.fontSize != null
                      ? theme.textTheme.bodyLarge!.fontSize! * fontSizeMultiplier
                      : null,
                ),
                decoration: InputDecoration(
                  labelText: 'Color (Optional)',
                  hintText: '#RRGGBB or #AARRGGBB',
                  prefixIcon: Icon(Icons.palette_outlined, size: Responsive.getIconSize(context, baseSize: 24)),
                  helperText: 'Hex color code (e.g., #2196F3)',
                  contentPadding: Responsive.getTextFieldPadding(context),
                ),
                enabled: !_isSaving,
                validator: _validateColor,
                onFieldSubmitted: (_) => _handleSave(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            padding: Responsive.getButtonPadding(context),
          ),
          child: Text(
            'Cancel',
            style: TextStyle(
              fontSize: theme.textTheme.labelLarge?.fontSize != null
                  ? theme.textTheme.labelLarge!.fontSize! * fontSizeMultiplier
                  : null,
            ),
          ),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _handleSave,
          style: FilledButton.styleFrom(
            padding: Responsive.getButtonPadding(context),
          ),
          child: _isSaving
              ? SizedBox(
                  width: Responsive.getIconSize(context, baseSize: 16),
                  height: Responsive.getIconSize(context, baseSize: 16),
                  child: const CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  isEditing ? 'Save' : 'Create',
                  style: TextStyle(
                    fontSize: theme.textTheme.labelLarge?.fontSize != null
                        ? theme.textTheme.labelLarge!.fontSize! * fontSizeMultiplier
                        : null,
                  ),
                ),
        ),
      ],
    );
  }
}
