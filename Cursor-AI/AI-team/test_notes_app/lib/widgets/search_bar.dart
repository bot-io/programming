import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:simplenotes/providers/search_provider.dart';
import 'package:simplenotes/utils/responsive.dart';

/// A reusable search bar widget with text input, clear button, and debouncing.
/// 
/// This widget provides a Material Design 3 search input field that integrates
/// with [SearchProvider] for search functionality. It includes:
/// - Text field for search input
/// - Clear button that appears when there's text
/// - Automatic debouncing to prevent excessive search operations
/// - Integration with SearchProvider for state management
/// 
/// Example:
/// ```dart
/// SearchBar(
///   hintText: 'Search notes...',
///   debounceMs: 300,
/// )
/// ```
class SearchBar extends StatefulWidget {
  /// Optional hint text displayed in the search field.
  final String? hintText;

  /// Debounce delay in milliseconds. Defaults to 300ms.
  /// 
  /// This delay determines how long to wait after the user stops typing
  /// before performing the search operation.
  final int debounceMs;

  /// Optional callback called when the search query changes.
  /// 
  /// This is called immediately when the text changes, before debouncing.
  final ValueChanged<String>? onQueryChanged;

  /// Optional callback called when the clear button is pressed.
  final VoidCallback? onClear;

  /// Optional category ID to filter search results by.
  final String? categoryId;

  /// Optional padding around the search bar.
  final EdgeInsetsGeometry? padding;

  /// Creates a [SearchBar] widget.
  /// 
  /// The [hintText] parameter is optional and defaults to 'Search...'.
  /// The [debounceMs] parameter defaults to 300 milliseconds.
  const SearchBar({
    super.key,
    this.hintText,
    this.debounceMs = 300,
    this.onQueryChanged,
    this.onClear,
    this.categoryId,
    this.padding,
  });

  @override
  State<SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<SearchBar> {
  late final TextEditingController _controller;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    
    // Initialize with current search query from provider
    final searchProvider = context.read<SearchProvider>();
    if (searchProvider.query.isNotEmpty) {
      _controller.text = searchProvider.query;
    }

    // Listen to text changes for debouncing
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final query = _controller.text;
    
    // Call optional callback immediately
    widget.onQueryChanged?.call(query);

    // Cancel previous debounce timer
    _debounceTimer?.cancel();

    // Update provider query immediately for UI responsiveness
    final searchProvider = context.read<SearchProvider>();
    searchProvider.setQuery(query);

    // If query is empty, clear search immediately
    if (query.isEmpty) {
      searchProvider.clearSearch();
      return;
    }

    // Schedule debounced search
    _debounceTimer = Timer(Duration(milliseconds: widget.debounceMs), () {
      if (mounted) {
        searchProvider.searchDebounced(
          query: query,
          categoryId: widget.categoryId,
          debounceMs: widget.debounceMs,
        );
      }
    });
  }

  void _onClear() {
    _controller.clear();
    widget.onClear?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: widget.padding ?? Responsive.getPadding(context).copyWith(
        top: Responsive.getSpacing(context),
        bottom: Responsive.getSpacing(context),
      ),
      child: Consumer<SearchProvider>(
        builder: (context, searchProvider, child) {
          final hasText = _controller.text.isNotEmpty;

          return TextField(
            controller: _controller,
            decoration: InputDecoration(
              hintText: widget.hintText ?? 'Search...',
              prefixIcon: Icon(
                Icons.search,
                color: colorScheme.onSurfaceVariant,
                size: Responsive.getIconSize(context, baseSize: 24),
              ),
              suffixIcon: hasText
                  ? IconButton(
                      icon: Icon(
                        Icons.clear,
                        color: colorScheme.onSurfaceVariant,
                        size: Responsive.getIconSize(context, baseSize: 20),
                      ),
                      onPressed: _onClear,
                      tooltip: 'Clear search',
                    )
                  : null,
              filled: true,
              fillColor: colorScheme.surfaceVariant.withOpacity(0.3),
              contentPadding: EdgeInsets.symmetric(
                horizontal: Responsive.getSpacing(context) * 2,
                vertical: Responsive.getSpacing(context) * 1.5,
              ),
            ),
            style: TextStyle(
              fontSize: (theme.textTheme.bodyLarge?.fontSize ?? 16) * Responsive.getFontSizeMultiplier(context),
            ),
            textInputAction: TextInputAction.search,
            onSubmitted: (value) {
              // Perform immediate search on submit
              if (value.isNotEmpty) {
                _debounceTimer?.cancel();
                searchProvider.search(
                  query: value,
                  categoryId: widget.categoryId,
                );
              }
            },
          );
        },
      ),
    );
  }
}
