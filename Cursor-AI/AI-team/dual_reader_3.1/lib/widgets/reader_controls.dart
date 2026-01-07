import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/help_service.dart';
import 'help_icon.dart';

class ReaderControls extends StatefulWidget {
  final int currentPage;
  final int totalPages;
  final VoidCallback? onPreviousPage;
  final VoidCallback? onNextPage;
  final Function(int)? onPageChanged;
  final VoidCallback? onSettings;
  final VoidCallback? onBookmarks;
  final VoidCallback? onChapters;
  final VoidCallback? onBack;

  const ReaderControls({
    Key? key,
    required this.currentPage,
    required this.totalPages,
    this.onPreviousPage,
    this.onNextPage,
    this.onPageChanged,
    this.onSettings,
    this.onBookmarks,
    this.onChapters,
    this.onBack,
  }) : super(key: key);

  @override
  State<ReaderControls> createState() => _ReaderControlsState();
}

class _ReaderControlsState extends State<ReaderControls> {
  final TextEditingController _pageController = TextEditingController();
  bool _showPageInput = false;

  @override
  void initState() {
    super.initState();
    _pageController.text = widget.currentPage.toString();
  }

  @override
  void didUpdateWidget(ReaderControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentPage != widget.currentPage) {
      _pageController.text = widget.currentPage.toString();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _handlePageInput() {
    final input = int.tryParse(_pageController.text);
    if (input != null && input >= 1 && input <= widget.totalPages) {
      widget.onPageChanged?.call(input);
      setState(() {
        _showPageInput = false;
      });
    } else {
      // Reset to current page if invalid
      _pageController.text = widget.currentPage.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter a page number between 1 and ${widget.totalPages}'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Page slider
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: widget.onPreviousPage,
                    tooltip: HelpService.getTooltip('previous_page'),
                  ),
                  Expanded(
                    child: Tooltip(
                      message: HelpService.getTooltip('page_slider'),
                      child: Slider(
                        value: widget.currentPage.toDouble(),
                        min: 1,
                        max: widget.totalPages.toDouble(),
                        divisions: widget.totalPages > 1 ? widget.totalPages - 1 : 1,
                        label: '${widget.currentPage} / ${widget.totalPages}',
                        onChanged: (value) {
                          widget.onPageChanged?.call(value.round());
                        },
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: widget.onNextPage,
                    tooltip: HelpService.getTooltip('next_page'),
                  ),
                ],
              ),
              // Page input (toggleable)
              if (_showPageInput)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _pageController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Go to page',
                            hintText: '1-${widget.totalPages}',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          onSubmitted: (_) => _handlePageInput(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.check),
                        onPressed: _handlePageInput,
                        tooltip: HelpService.getTooltip('page_input'),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          setState(() {
                            _showPageInput = false;
                            _pageController.text = widget.currentPage.toString();
                          });
                        },
                        tooltip: 'Cancel',
                      ),
                    ],
                  ),
                ),
              // Page info and controls
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Tooltip(
                    message: HelpService.getTooltip('back_to_library'),
                    child: TextButton.icon(
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Back'),
                      onPressed: widget.onBack,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _showPageInput = !_showPageInput;
                        if (_showPageInput) {
                          _pageController.text = widget.currentPage.toString();
                          _pageController.selection = TextSelection(
                            baseOffset: 0,
                            extentOffset: _pageController.text.length,
                          );
                        }
                      });
                    },
                    child: Tooltip(
                      message: HelpService.getTooltip('page_input'),
                      child: Text(
                        'Page ${widget.currentPage} of ${widget.totalPages}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.onChapters != null)
                        IconButton(
                          icon: const Icon(Icons.menu_book),
                          onPressed: widget.onChapters,
                          tooltip: HelpService.getTooltip('chapters'),
                        ),
                      IconButton(
                        icon: const Icon(Icons.bookmark_border),
                        onPressed: widget.onBookmarks,
                        tooltip: HelpService.getTooltip('bookmarks'),
                      ),
                      IconButton(
                        icon: const Icon(Icons.help_outline),
                        onPressed: () {
                          context.push('/help');
                        },
                        tooltip: HelpService.getTooltip('help'),
                      ),
                      IconButton(
                        icon: const Icon(Icons.settings),
                        onPressed: widget.onSettings,
                        tooltip: HelpService.getTooltip('settings'),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
