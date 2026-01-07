import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:simplenotes/models/category.dart';
import 'package:simplenotes/models/note.dart';
import 'package:simplenotes/providers/category_provider.dart';
import 'package:simplenotes/providers/note_provider.dart';
import 'package:simplenotes/widgets/category_chip.dart';
import 'package:simplenotes/utils/responsive.dart';

/// A widget for creating and editing notes.
/// 
/// This widget provides a form interface with:
/// - Title input field
/// - Content input field (multiline)
/// - Category selector dropdown
/// - Save and Cancel buttons
/// 
/// Example:
/// ```dart
/// // Create new note
/// NoteEditor(
///   onSave: (title, content, categoryId) async {
///     await noteProvider.createNote(
///       title: title,
///       content: content,
///       categoryId: categoryId,
///     );
///   },
///   onCancel: () => Navigator.pop(context),
/// )
/// 
/// // Edit existing note
/// NoteEditor(
///   note: existingNote,
///   onSave: (title, content, categoryId) async {
///     await noteProvider.updateNote(
///       id: existingNote.id,
///       title: title,
///       content: content,
///       categoryId: categoryId,
///     );
///   },
///   onCancel: () => Navigator.pop(context),
/// )
/// ```
class NoteEditor extends StatefulWidget {
  /// Optional existing note to edit. If null, creates a new note.
  final Note? note;

  /// Callback invoked when save is pressed.
  /// 
  /// Parameters: title, content, categoryId (nullable)
  final Future<void> Function(String title, String content, String? categoryId) onSave;

  /// Callback invoked when cancel is pressed.
  final VoidCallback onCancel;

  /// Whether to show a loading indicator during save operation.
  final bool isLoading;

  /// Creates a [NoteEditor] widget.
  /// 
  /// The [onSave] and [onCancel] parameters are required.
  /// 
  /// If [note] is provided, the editor will be in edit mode and pre-filled with note data.
  /// If [note] is null, the editor will be in create mode with empty fields.
  const NoteEditor({
    super.key,
    this.note,
    required this.onSave,
    required this.onCancel,
    this.isLoading = false,
  });

  @override
  State<NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<NoteEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  String? _selectedCategoryId;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _contentController = TextEditingController(text: widget.note?.content ?? '');
    _selectedCategoryId = widget.note?.categoryId;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
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
      final title = _titleController.text.trim();
      final content = _contentController.text;
      
      await widget.onSave(title, content, _selectedCategoryId);
      
      if (mounted) {
        // Success - widget.onSave will handle navigation/state updates
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save note: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  /// Handles the cancel action.
  void _handleCancel() {
    // Check if there are unsaved changes
    final hasChanges = _titleController.text.trim() != (widget.note?.title ?? '') ||
        _contentController.text != (widget.note?.content ?? '') ||
        _selectedCategoryId != widget.note?.categoryId;

    if (hasChanges) {
      showDialog(
        context: context,
        builder: (context) {
          final theme = Theme.of(context);
          final fontSizeMultiplier = Responsive.getFontSizeMultiplier(context);
          return AlertDialog(
            contentPadding: Responsive.getPadding(context),
            title: Text(
              'Discard changes?',
              style: TextStyle(
                fontSize: theme.textTheme.titleLarge?.fontSize != null
                    ? theme.textTheme.titleLarge!.fontSize! * fontSizeMultiplier
                    : null,
              ),
            ),
            content: Text(
              'You have unsaved changes. Are you sure you want to discard them?',
              style: TextStyle(
                fontSize: theme.textTheme.bodyMedium?.fontSize != null
                    ? theme.textTheme.bodyMedium!.fontSize! * fontSizeMultiplier
                    : null,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  padding: Responsive.getButtonPadding(context),
                ),
                child: Text(
                  'Keep editing',
                  style: TextStyle(
                    fontSize: theme.textTheme.labelLarge?.fontSize != null
                        ? theme.textTheme.labelLarge!.fontSize! * fontSizeMultiplier
                        : null,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onCancel();
                },
                style: TextButton.styleFrom(
                  padding: Responsive.getButtonPadding(context),
                ),
                child: Text(
                  'Discard',
                  style: TextStyle(
                    fontSize: theme.textTheme.labelLarge?.fontSize != null
                        ? theme.textTheme.labelLarge!.fontSize! * fontSizeMultiplier
                        : null,
                  ),
                ),
              ),
            ],
          );
        },
      );
    } else {
      widget.onCancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isSaving = _isSaving || widget.isLoading;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Title field
          TextFormField(
            controller: _titleController,
            decoration: InputDecoration(
              labelText: 'Title',
              hintText: 'Enter note title',
              prefixIcon: Icon(Icons.title, size: Responsive.getIconSize(context, baseSize: 24)),
              contentPadding: Responsive.getTextFieldPadding(context),
            ),
            textInputAction: TextInputAction.next,
            maxLength: 200,
            style: TextStyle(
              fontSize: (theme.textTheme.bodyLarge?.fontSize ?? 16) * Responsive.getFontSizeMultiplier(context),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Title cannot be empty';
              }
              if (value.length > 200) {
                return 'Title cannot exceed 200 characters';
              }
              return null;
            },
          ),
          SizedBox(height: Responsive.getSpacing(context) * 2),

          // Category selector
          Consumer<CategoryProvider>(
            builder: (context, categoryProvider, child) {
              final categories = categoryProvider.categories;
              
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Category',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: (theme.textTheme.labelLarge?.fontSize ?? 14) * Responsive.getFontSizeMultiplier(context),
                    ),
                  ),
                  SizedBox(height: Responsive.getSpacing(context)),
                  if (categories.isEmpty)
                    Container(
                      padding: Responsive.getCardPadding(context),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceVariant.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: colorScheme.outline.withOpacity(0.5),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: Responsive.getIconSize(context, baseSize: 20),
                            color: colorScheme.onSurfaceVariant,
                          ),
                          SizedBox(width: Responsive.getSpacing(context) / 2),
                          Expanded(
                              child: Text(
                                'No categories available',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: theme.textTheme.bodyMedium?.fontSize != null
                                      ? theme.textTheme.bodyMedium!.fontSize! * Responsive.getFontSizeMultiplier(context)
                                      : null,
                                ),
                              ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: Responsive.getCardPadding(context),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceVariant.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: colorScheme.outline.withOpacity(0.5),
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          value: _selectedCategoryId,
                          isExpanded: true,
                          hint: Text(
                            'Select a category (optional)',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: theme.textTheme.bodyMedium?.fontSize != null
                                  ? theme.textTheme.bodyMedium!.fontSize! * Responsive.getFontSizeMultiplier(context)
                                  : null,
                            ),
                          ),
                          items: [
                            // Option to remove category
                            DropdownMenuItem<String?>(
                              value: null,
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.cancel_outlined,
                                    size: Responsive.getIconSize(context, baseSize: 20),
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                  SizedBox(width: Responsive.getSpacing(context) / 2),
                                  Text(
                                    'No category',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontSize: theme.textTheme.bodyMedium?.fontSize != null
                                          ? theme.textTheme.bodyMedium!.fontSize! * Responsive.getFontSizeMultiplier(context)
                                          : null,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ...categories.map((category) {
                              return DropdownMenuItem<String?>(
                                value: category.id,
                                child: Row(
                                  children: [
                                    if (category.color != null) ...[
                                      Container(
                                        width: Responsive.isMobile(context) ? 12 : 14,
                                        height: Responsive.isMobile(context) ? 12 : 14,
                                        decoration: BoxDecoration(
                                          color: _parseColor(category.color),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: colorScheme.outline.withOpacity(0.3),
                                            width: 1,
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: Responsive.getSpacing(context) / 2),
                                    ],
                                    Expanded(
                                      child: Text(
                                        category.name,
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          fontSize: theme.textTheme.bodyMedium?.fontSize != null
                                              ? theme.textTheme.bodyMedium!.fontSize! * Responsive.getFontSizeMultiplier(context)
                                              : null,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedCategoryId = value;
                            });
                          },
                          selectedItemBuilder: (context) {
                            return [
                              // Build selected item display
                              if (_selectedCategoryId == null)
                                Row(
                                  children: [
                                    Icon(
                                      Icons.cancel_outlined,
                                      size: Responsive.getIconSize(context, baseSize: 20),
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                    SizedBox(width: Responsive.getSpacing(context) / 2),
                                    Text(
                                      'No category',
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        fontSize: theme.textTheme.bodyMedium?.fontSize != null
                                            ? theme.textTheme.bodyMedium!.fontSize! * Responsive.getFontSizeMultiplier(context)
                                            : null,
                                      ),
                                    ),
                                  ],
                                )
                              else
                                Builder(
                                  builder: (context) {
                                    final category = categories.firstWhere(
                                      (c) => c.id == _selectedCategoryId,
                                      orElse: () => categories.first,
                                    );
                                    return Row(
                                      children: [
                                        if (category.color != null) ...[
                                          Container(
                                            width: Responsive.isMobile(context) ? 12 : 14,
                                            height: Responsive.isMobile(context) ? 12 : 14,
                                            decoration: BoxDecoration(
                                              color: _parseColor(category.color),
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: colorScheme.outline.withOpacity(0.3),
                                                width: 1,
                                              ),
                                            ),
                                          ),
                                          SizedBox(width: Responsive.getSpacing(context) / 2),
                                        ],
                                        Expanded(
                                          child: Text(
                                            category.name,
                                            style: theme.textTheme.bodyMedium?.copyWith(
                                              fontSize: theme.textTheme.bodyMedium?.fontSize != null
                                                  ? theme.textTheme.bodyMedium!.fontSize! * Responsive.getFontSizeMultiplier(context)
                                                  : null,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                            ];
                          },
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          SizedBox(height: Responsive.getSpacing(context) * 2),

          // Content field
          TextFormField(
            controller: _contentController,
            decoration: InputDecoration(
              labelText: 'Content',
              hintText: 'Enter note content',
              alignLabelWithHint: true,
              prefixIcon: Padding(
                padding: EdgeInsets.only(bottom: Responsive.isMobile(context) ? 100 : 120),
                child: Icon(Icons.note, size: Responsive.getIconSize(context, baseSize: 24)),
              ),
              contentPadding: Responsive.getTextFieldPadding(context),
            ),
            maxLines: null,
            minLines: Responsive.isMobile(context) ? 8 : 10,
            textInputAction: TextInputAction.newline,
            maxLength: 100000,
            style: TextStyle(
              fontSize: (theme.textTheme.bodyLarge?.fontSize ?? 16) * Responsive.getFontSizeMultiplier(context),
            ),
            validator: (value) {
              if (value == null) {
                return null; // Content is optional
              }
              if (value.length > 100000) {
                return 'Content cannot exceed 100,000 characters';
              }
              return null;
            },
          ),
          SizedBox(height: Responsive.getSpacing(context) * 3),

          // Action buttons
          LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = Responsive.isMobile(context);
              
              if (isMobile) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Save button (full width on mobile)
                    ElevatedButton.icon(
                      onPressed: isSaving ? null : _handleSave,
                      style: ElevatedButton.styleFrom(
                        padding: Responsive.getButtonPadding(context),
                      ),
                      icon: isSaving
                          ? SizedBox(
                              width: Responsive.getIconSize(context, baseSize: 16),
                              height: Responsive.getIconSize(context, baseSize: 16),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  colorScheme.onPrimary,
                                ),
                              ),
                            )
                          : Icon(Icons.save, size: Responsive.getIconSize(context, baseSize: 20)),
                      label: Text(
                        widget.note == null ? 'Create' : 'Save',
                        style: TextStyle(
                          fontSize: theme.textTheme.labelLarge?.fontSize != null
                              ? theme.textTheme.labelLarge!.fontSize! * Responsive.getFontSizeMultiplier(context)
                              : null,
                        ),
                      ),
                    ),
                    SizedBox(height: Responsive.getSpacing(context)),
                    // Cancel button (full width on mobile)
                    OutlinedButton(
                      onPressed: isSaving ? null : _handleCancel,
                      style: OutlinedButton.styleFrom(
                        padding: Responsive.getButtonPadding(context),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: theme.textTheme.labelLarge?.fontSize != null
                              ? theme.textTheme.labelLarge!.fontSize! * Responsive.getFontSizeMultiplier(context)
                              : null,
                        ),
                      ),
                    ),
                  ],
                );
              }
              
              // Tablet/Desktop: buttons side by side
              return Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Cancel button
                  TextButton(
                    onPressed: isSaving ? null : _handleCancel,
                    style: TextButton.styleFrom(
                      padding: Responsive.getButtonPadding(context),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: theme.textTheme.labelLarge?.fontSize != null
                            ? theme.textTheme.labelLarge!.fontSize! * Responsive.getFontSizeMultiplier(context)
                            : null,
                      ),
                    ),
                  ),
                  SizedBox(width: Responsive.getSpacing(context) / 2),
                  // Save button
                  ElevatedButton.icon(
                    onPressed: isSaving ? null : _handleSave,
                    style: ElevatedButton.styleFrom(
                      padding: Responsive.getButtonPadding(context),
                    ),
                    icon: isSaving
                        ? SizedBox(
                            width: Responsive.getIconSize(context, baseSize: 16),
                            height: Responsive.getIconSize(context, baseSize: 16),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                colorScheme.onPrimary,
                              ),
                            ),
                          )
                        : Icon(Icons.save, size: Responsive.getIconSize(context, baseSize: 20)),
                    label: Text(
                      widget.note == null ? 'Create' : 'Save',
                      style: TextStyle(
                        fontSize: theme.textTheme.labelLarge?.fontSize != null
                            ? theme.textTheme.labelLarge!.fontSize! * Responsive.getFontSizeMultiplier(context)
                            : null,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  /// Parses a hex color string to a Color object.
  /// 
  /// Supports formats: #RRGGBB or #AARRGGBB
  /// Returns a default color if the color string is invalid.
  Color _parseColor(String? colorString) {
    if (colorString == null || colorString.isEmpty) {
      return Theme.of(context).colorScheme.primary;
    }

    try {
      // Remove the # if present
      String hex = colorString.replaceFirst('#', '');
      
      // Handle 6-digit hex (RRGGBB)
      if (hex.length == 6) {
        return Color(int.parse('FF$hex', radix: 16));
      }
      
      // Handle 8-digit hex (AARRGGBB)
      if (hex.length == 8) {
        return Color(int.parse(hex, radix: 16));
      }
      
      return Theme.of(context).colorScheme.primary;
    } catch (e) {
      return Theme.of(context).colorScheme.primary;
    }
  }
}
