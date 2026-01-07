import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../services/help_service.dart';

class HelpScreen extends StatefulWidget {
  const HelpScreen({Key? key}) : super(key: key);

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> with SingleTickerProviderStateMixin {
  String _selectedSection = 'quick_tips';
  String _content = '';
  String _filteredContent = '';
  bool _isLoading = true;
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final Map<String, String> _allContent = {};
  final ScrollController _scrollController = ScrollController();

  final Map<String, String> _sections = {
    'quick_tips': 'Quick Tips',
    'getting_started': 'Getting Started',
    'features': 'Features',
    'faq': 'FAQ',
    'user_manual': 'User Manual',
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: _sections.length,
      vsync: this,
      initialIndex: _sections.keys.toList().indexOf(_selectedSection),
    );
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        final newSection = _sections.keys.elementAt(_tabController.index);
        if (newSection != _selectedSection) {
          _selectedSection = newSection;
          _loadContent(newSection);
        }
      }
    });
    _searchController.addListener(_onSearchChanged);
    _loadContent(_selectedSection);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
      _filterContent();
    });
  }

  void _filterContent() {
    if (_searchQuery.isEmpty) {
      _filteredContent = _content;
    } else {
      // Enhanced search: find matching lines with context
      final lines = _content.split('\n');
      final lowerQuery = _searchQuery.toLowerCase();
      final matchingLines = <int>[];
      
      // Find lines that match
      for (int i = 0; i < lines.length; i++) {
        if (lines[i].toLowerCase().contains(lowerQuery)) {
          matchingLines.add(i);
        }
      }
      
      if (matchingLines.isEmpty) {
        // No matches found
        _filteredContent = '## No results found for "$_searchQuery"\n\n'
            'Try searching with different keywords or check the other sections:\n\n'
            '- Quick Tips\n'
            '- Getting Started\n'
            '- Features\n'
            '- FAQ\n'
            '- User Manual\n\n'
            '---\n\n'
            '**Full content:**\n\n$_content';
      } else {
        // Show matching lines with context (2 lines before and after)
        final resultLines = <String>[];
        final includedIndices = <int>{};
        
        for (final index in matchingLines) {
          // Add context lines
          for (int i = (index - 2).clamp(0, lines.length - 1); 
               i <= (index + 2).clamp(0, lines.length - 1); 
               i++) {
            if (!includedIndices.contains(i)) {
              includedIndices.add(i);
              resultLines.add(lines[i]);
            }
          }
        }
        
        _filteredContent = '## Search Results for "$_searchQuery"\n\n'
            'Found ${matchingLines.length} matching ${matchingLines.length == 1 ? 'line' : 'lines'}:\n\n'
            '---\n\n'
            '${resultLines.join('\n')}\n\n'
            '---\n\n'
            '**Tip:** Clear the search to view the full content.';
      }
    }
  }

  Future<void> _loadContent(String section) async {
    setState(() {
      _isLoading = true;
    });

    try {
      String content;
      switch (section) {
        case 'quick_tips':
          content = await HelpService.loadQuickTips();
          break;
        case 'getting_started':
          content = await HelpService.loadGettingStarted();
          break;
        case 'features':
          content = await HelpService.loadFeatures();
          break;
        case 'faq':
          content = await HelpService.loadFAQ();
          break;
        case 'user_manual':
          content = await HelpService.loadUserManual();
          break;
        default:
          content = 'Content not available for section: $section';
      }

      setState(() {
        _content = content;
        _allContent[_selectedSection] = content;
        _filterContent();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _content = 'Error loading content: $e\n\nPlease try again or check your connection.';
        _filterContent();
        _isLoading = false;
      });
    }
  }

  void _onSectionChanged(String? section) {
    if (section != null && section != _selectedSection) {
      final index = _sections.keys.toList().indexOf(section);
      if (_tabController.index != index && !_tabController.indexIsChanging) {
        _tabController.animateTo(index);
      }
      setState(() {
        _selectedSection = section;
      });
      _loadContent(section);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & Documentation'),
        actions: [
          if (_searchQuery.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _searchController.clear();
              },
              tooltip: 'Clear search',
            ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _showSearchDialog,
            tooltip: 'Search documentation',
          ),
        ],
        bottom: _searchQuery.isNotEmpty
            ? PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.search, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Searching for: "$_searchQuery"',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : null,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Use NavigationRail for wider screens, Drawer for mobile
          if (constraints.maxWidth > 600) {
            return Row(
              children: [
                // Sidebar navigation
                NavigationRail(
                  selectedIndex: _sections.keys.toList().indexOf(_selectedSection),
                  onDestinationSelected: (index) {
                    _onSectionChanged(_sections.keys.elementAt(index));
                  },
                  labelType: NavigationRailLabelType.all,
                  destinations: _sections.values.map((title) {
                    IconData icon;
                    switch (title) {
                      case 'Quick Tips':
                        icon = Icons.lightbulb_outline;
                        break;
                      case 'Getting Started':
                        icon = Icons.play_arrow;
                        break;
                      case 'Features':
                        icon = Icons.star;
                        break;
                      case 'FAQ':
                        icon = Icons.help_outline;
                        break;
                      case 'User Manual':
                        icon = Icons.menu_book;
                        break;
                      default:
                        icon = Icons.article;
                    }
                    return NavigationRailDestination(
                      icon: Icon(icon),
                      label: Text(title),
                    );
                  }).toList(),
                ),
                const VerticalDivider(thickness: 1, width: 1),
                // Content area
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _buildContent(context),
                ),
              ],
            );
          } else {
            // Mobile layout with bottom navigation or tabs
            return Column(
              children: [
                // Tab bar for mobile
                Container(
                  color: Theme.of(context).colorScheme.surface,
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabs: _sections.values.map((title) {
                      IconData icon;
                      switch (title) {
                        case 'Quick Tips':
                          icon = Icons.lightbulb_outline;
                          break;
                        case 'Getting Started':
                          icon = Icons.play_arrow;
                          break;
                        case 'Features':
                          icon = Icons.star;
                          break;
                        case 'FAQ':
                          icon = Icons.help_outline;
                          break;
                        case 'User Manual':
                          icon = Icons.menu_book;
                          break;
                        default:
                          icon = Icons.article;
                      }
                      return Tab(
                        icon: Icon(icon),
                        text: title.length > 12 ? title.substring(0, 12) + '...' : title,
                      );
                    }).toList(),
                  ),
                ),
                // Content area
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _buildContent(context),
                ),
              ],
            );
          }
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final contentToShow = _searchQuery.isNotEmpty ? _filteredContent : _content;
    
    return Column(
      children: [
        if (_searchQuery.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
            child: Row(
              children: [
                Icon(
                  Icons.search,
                  size: 20,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Searching: "$_searchQuery"',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    _searchController.clear();
                  },
                  child: Text(
                    'Clear',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: Markdown(
            controller: _scrollController,
            data: contentToShow,
            padding: const EdgeInsets.all(16),
            styleSheet: MarkdownStyleSheet(
              h1: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              h2: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              h3: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              p: Theme.of(context).textTheme.bodyMedium,
              listBullet: Theme.of(context).textTheme.bodyMedium,
              blockquote: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontStyle: FontStyle.italic,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              code: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontFamily: 'monospace',
                backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
              ),
              codeblockDecoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            onTapLink: (text, href, title) {
              // Handle link taps if needed
              if (href != null) {
                // Could open external links or navigate to sections
              }
            },
          ),
        ),
      ],
    );
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search Documentation'),
        content: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search for topics...',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) {
            Navigator.pop(context);
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              _searchController.clear();
              Navigator.pop(context);
            },
            child: const Text('Clear'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
