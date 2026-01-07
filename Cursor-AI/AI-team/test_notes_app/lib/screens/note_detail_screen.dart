import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:simplenotes/models/note.dart';
import 'package:simplenotes/providers/note_provider.dart';
import 'package:simplenotes/widgets/note_editor.dart';
import 'package:simplenotes/utils/responsive.dart';

/// Screen for viewing and editing individual notes.
/// 
/// This screen allows users to:
/// - View note details
/// - Edit note title, content, and category using NoteEditor
/// - Delete notes with confirmation
/// - Navigate back after saving or deleting
/// - Create new notes when noteId is null
/// 
/// Example:
/// ```dart
/// // View/edit existing note
/// Navigator.push(
///   context,
///   MaterialPageRoute(
///     builder: (context) => NoteDetailScreen(noteId: 'note-123'),
///   ),
/// );
/// 
/// // Create new note
/// Navigator.push(
///   context,
///   MaterialPageRoute(
///     builder: (context) => const NoteDetailScreen(noteId: null),
///   ),
/// );
/// ```
class NoteDetailScreen extends StatefulWidget {
  /// The ID of the note to display and edit.
  /// If null, creates a new note.
  final String? noteId;

  /// Creates a [NoteDetailScreen] widget.
  /// 
  /// The [noteId] parameter is optional. If null, the screen will be in create mode.
  const NoteDetailScreen({
    super.key,
    this.noteId,
  });

  @override
  State<NoteDetailScreen> createState() => _NoteDetailScreenState();
}

class _NoteDetailScreenState extends State<NoteDetailScreen> {
  Note? _note;
  bool _isLoading = true;
  String? _error;
  bool _isSaving = false;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _loadNote();
  }

  /// Loads the note from the provider.
  Future<void> _loadNote() async {
    if (!mounted) return;

    // If noteId is null, we're creating a new note - no need to load
    if (widget.noteId == null) {
      setState(() {
        _note = null;
        _isLoading = false;
        _error = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final noteProvider = context.read<NoteProvider>();
      final note = await noteProvider.getNote(widget.noteId!);

      if (!mounted) return;

      if (note == null) {
        setState(() {
          _error = 'Note not found';
          _isLoading = false;
        });
      } else {
        setState(() {
          _note = note;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = 'Failed to load note: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  /// Handles saving the note.
  Future<void> _handleSave(String title, String content, String? categoryId) async {
    if (!mounted) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final noteProvider = context.read<NoteProvider>();
      
      if (widget.noteId == null) {
        // Creating a new note
        await noteProvider.createNote(
          title: title,
          content: content,
          categoryId: categoryId,
        );
      } else {
        // Updating an existing note
        await noteProvider.updateNote(
          id: widget.noteId!,
          title: title,
          content: content,
          categoryId: categoryId ?? '',
        );
      }

      if (!mounted) return;

      // Reload note to get updated data (or load the newly created note)
      await _loadNote();

      if (!mounted) return;

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.noteId == null ? 'Note created successfully' : 'Note saved successfully'),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
      
      // Navigate back after creating a new note
      if (widget.noteId == null && _note != null) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save note: ${e.toString()}'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  /// Handles deleting the note.
  Future<void> _handleDelete() async {
    // Cannot delete if noteId is null (creating new note)
    if (widget.noteId == null) {
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => LayoutBuilder(
        builder: (context, constraints) {
          final theme = Theme.of(context);
          final fontSizeMultiplier = Responsive.getFontSizeMultiplier(context);
          return SizedBox(
            width: Responsive.getDialogWidth(context),
            child: AlertDialog(
              contentPadding: Responsive.getPadding(context),
              title: Text(
                'Delete Note',
                style: TextStyle(
                  fontSize: theme.textTheme.titleLarge?.fontSize != null
                      ? theme.textTheme.titleLarge!.fontSize! * fontSizeMultiplier
                      : null,
                ),
              ),
              content: Text(
                'Are you sure you want to delete this note? This action cannot be undone.',
                style: TextStyle(
                  fontSize: theme.textTheme.bodyMedium?.fontSize != null
                      ? theme.textTheme.bodyMedium!.fontSize! * fontSizeMultiplier
                      : null,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
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
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                    padding: Responsive.getButtonPadding(context),
                  ),
                  child: Text(
                    'Delete',
                    style: TextStyle(
                      fontSize: theme.textTheme.labelLarge?.fontSize != null
                          ? theme.textTheme.labelLarge!.fontSize! * fontSizeMultiplier
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _isDeleting = true;
    });

    try {
      final noteProvider = context.read<NoteProvider>();
      final deleted = await noteProvider.deleteNote(widget.noteId!);

      if (!mounted) return;

      if (deleted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Note deleted successfully'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );

        // Navigate back
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _error = 'Note not found or already deleted';
          _isDeleting = false;
        });
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete note: ${e.toString()}'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );

      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
      }
    }
  }

  /// Handles cancel action - navigates back.
  void _handleCancel() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.noteId == null ? 'New Note' : 'Note Details',
          style: TextStyle(
            fontSize: Theme.of(context).textTheme.titleLarge?.fontSize != null
                ? Theme.of(context).textTheme.titleLarge!.fontSize! * Responsive.getFontSizeMultiplier(context)
                : null,
          ),
        ),
        actions: [
          // Delete button (only show for existing notes)
          if (widget.noteId != null && _note != null && !_isSaving)
            IconButton(
              icon: _isDeleting
                  ? SizedBox(
                      width: Responsive.getIconSize(context, baseSize: 20),
                      height: Responsive.getIconSize(context, baseSize: 20),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          colorScheme.onPrimary,
                        ),
                      ),
                    )
                  : Icon(Icons.delete_outline, size: Responsive.getIconSize(context, baseSize: 24)),
              onPressed: _isDeleting ? null : _handleDelete,
              tooltip: 'Delete note',
            ),
        ],
      ),
      body: _buildBody(theme, colorScheme),
    );
  }

  /// Builds the body of the screen based on current state.
  Widget _buildBody(ThemeData theme, ColorScheme colorScheme) {
    // Loading state
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    // Error state (only for existing notes, not for new note creation)
    if (widget.noteId != null && (_error != null || _note == null)) {
      return Center(
        child: Padding(
          padding: Responsive.getPadding(context),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: Responsive.getEmptyStateIconSize(context),
                color: colorScheme.error,
              ),
              SizedBox(height: Responsive.getSpacing(context) * 2),
              Text(
                _error ?? 'Note not found',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colorScheme.error,
                  fontSize: theme.textTheme.titleMedium?.fontSize != null
                      ? theme.textTheme.titleMedium!.fontSize! * Responsive.getFontSizeMultiplier(context)
                      : null,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: Responsive.getSpacing(context) * 3),
              ElevatedButton.icon(
                onPressed: _loadNote,
                icon: Icon(Icons.refresh, size: Responsive.getIconSize(context, baseSize: 20)),
                label: Text('Retry'),
                style: ElevatedButton.styleFrom(
                  padding: Responsive.getButtonPadding(context),
                ),
              ),
              SizedBox(height: Responsive.getSpacing(context) * 2),
              TextButton(
                onPressed: _handleCancel,
                style: TextButton.styleFrom(
                  padding: Responsive.getButtonPadding(context),
                ),
                child: Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    // Note content with editor
    return LayoutBuilder(
      builder: (context, constraints) {
        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: Responsive.isMobile(context) 
                  ? double.infinity 
                  : Responsive.getMaxContentWidth(context),
            ),
            child: SingleChildScrollView(
              padding: Responsive.getPadding(context),
              child: NoteEditor(
                note: _note,
                onSave: _handleSave,
                onCancel: _handleCancel,
                isLoading: _isSaving,
              ),
            ),
          ),
        );
      },
    );
  }
}
