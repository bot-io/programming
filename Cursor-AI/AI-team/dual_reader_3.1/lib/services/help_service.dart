import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';

/// Service to load and manage help documentation content
class HelpService {
  static const String _gettingStartedPath = 'docs/getting_started.md';
  static const String _featuresPath = 'docs/features.md';
  static const String _faqPath = 'docs/faq.md';
  static const String _userManualPath = 'docs/user_manual.md';
  
  /// Load quick tips content (generated from tips list)
  static Future<String> loadQuickTips() async {
    final tips = getQuickTips();
    final content = StringBuffer();
    content.writeln('# Quick Tips\n');
    content.writeln('Here are some helpful tips to get the most out of Dual Reader 3.1:\n');
    
    for (int i = 0; i < tips.length; i++) {
      content.writeln('${i + 1}. ${tips[i]}\n');
    }
    
    content.writeln('---\n');
    content.writeln('For more detailed information, check out the other sections:\n');
    content.writeln('- **Getting Started**: Step-by-step guide for new users');
    content.writeln('- **Features**: Complete feature documentation');
    content.writeln('- **FAQ**: Answers to common questions');
    content.writeln('- **User Manual**: Comprehensive guide to all features');
    
    return content.toString();
  }

  /// Load getting started guide content
  static Future<String> loadGettingStarted() async {
    try {
      final content = await rootBundle.loadString(_gettingStartedPath);
      if (content.trim().isEmpty) {
        return _getDefaultGettingStarted();
      }
      return content;
    } catch (e) {
      // If asset loading fails, return default content
      // This ensures the app works even if assets aren't bundled correctly
      debugPrint('Warning: Could not load getting_started.md: $e');
      return _getDefaultGettingStarted();
    }
  }

  /// Load features documentation content
  static Future<String> loadFeatures() async {
    try {
      final content = await rootBundle.loadString(_featuresPath);
      if (content.trim().isEmpty) {
        return _getDefaultFeatures();
      }
      return content;
    } catch (e) {
      // If asset loading fails, return default content
      debugPrint('Warning: Could not load features.md: $e');
      return _getDefaultFeatures();
    }
  }

  /// Load FAQ content
  static Future<String> loadFAQ() async {
    try {
      final content = await rootBundle.loadString(_faqPath);
      if (content.trim().isEmpty) {
        return _getDefaultFAQ();
      }
      return content;
    } catch (e) {
      // If asset loading fails, return default content
      debugPrint('Warning: Could not load faq.md: $e');
      return _getDefaultFAQ();
    }
  }

  /// Load user manual content
  static Future<String> loadUserManual() async {
    try {
      final content = await rootBundle.loadString(_userManualPath);
      if (content.trim().isEmpty) {
        return _getDefaultUserManual();
      }
      return content;
    } catch (e) {
      // If asset loading fails, return default content
      debugPrint('Warning: Could not load user_manual.md: $e');
      return _getDefaultUserManual();
    }
  }
  
  /// Verify that all documentation files can be loaded
  static Future<Map<String, bool>> verifyDocumentation() async {
    final results = <String, bool>{};
    
    try {
      await rootBundle.loadString(_gettingStartedPath);
      results['getting_started'] = true;
    } catch (e) {
      results['getting_started'] = false;
    }
    
    try {
      await rootBundle.loadString(_featuresPath);
      results['features'] = true;
    } catch (e) {
      results['features'] = false;
    }
    
    try {
      await rootBundle.loadString(_faqPath);
      results['faq'] = true;
    } catch (e) {
      results['faq'] = false;
    }
    
    try {
      await rootBundle.loadString(_userManualPath);
      results['user_manual'] = true;
    } catch (e) {
      results['user_manual'] = false;
    }
    
    return results;
  }

  /// Get help tooltip text for a specific feature
  static String getTooltip(String featureKey) {
    const tooltips = {
      // Library & Import
      'import_book': 'Import EPUB or MOBI files. On web, you can also drag and drop files.',
      'library_search': 'Search for books by title or author name.',
      'library_sort': 'Sort books by recent, title, author, or reading progress.',
      'delete_book': 'Remove a book from your library. This action cannot be undone.',
      
      // Translation
      'translation_language': 'Select the language to translate book content into. Supports 50+ languages.',
      'auto_translate': 'Automatically translate pages as you read. Disable to translate manually.',
      'sync_scrolling': 'Keep both panels synchronized when scrolling. Disable for independent scrolling.',
      'translation_indicator': 'Shows when translation is in progress. First translation may take a moment.',
      
      // Appearance
      'theme': 'Change the appearance of the reader. Dark theme is recommended for night reading.',
      'font_family': 'Choose a font style for reading. Different fonts may affect readability and pagination.',
      'font_size': 'Adjust text size (12-24 points). Larger fonts show fewer words per page.',
      'line_height': 'Control spacing between lines (1.0-2.5). Higher values improve readability.',
      'margin_size': 'Adjust margins around text (S to XXL). Larger margins reduce text per page.',
      'text_alignment': 'Change how text is aligned. Left, center, or justify (even edges).',
      'panel_ratio': 'Control width distribution between panels in landscape mode (30%-70%).',
      
      // Navigation & Reading
      'bookmark': 'Save this page for quick access later. Bookmarks are saved per book.',
      'bookmarks': 'View and navigate to all saved bookmarks for this book.',
      'chapters': 'Navigate quickly between chapters if the book includes chapter information.',
      'page_navigation': 'Use arrows, slider, or tap page number to navigate. Swipe left/right on mobile.',
      'page_slider': 'Drag the slider to jump to any page quickly.',
      'page_input': 'Tap the page number to enter a specific page number directly.',
      'previous_page': 'Go to the previous page.',
      'next_page': 'Go to the next page.',
      'back_to_library': 'Return to your library to select another book.',
      
      // Settings
      'settings': 'Customize your reading experience: themes, fonts, layout, and translation options.',
      'export_settings': 'Save your settings to a file for backup or transfer to another device.',
      'import_settings': 'Load settings from a previously exported file to restore your preferences.',
      
      // Reader Interface
      'dual_panel': 'View original and translated text side-by-side (landscape) or stacked (portrait).',
      'toggle_controls': 'Tap anywhere on the reading area to show or hide controls.',
      'reading_progress': 'Your reading progress is automatically saved and displayed in the library.',
      'resume_reading': 'Books automatically open to your last read position.',
      
      // Help & Documentation
      'help': 'Access help documentation, getting started guide, features, FAQ, and user manual.',
      'documentation': 'Complete documentation including guides, tips, and troubleshooting.',
      
      // Additional UI Elements
      'book_card': 'Tap to open and read this book. Long-press for options.',
      'progress_bar': 'Shows your reading progress for this book as a percentage.',
      'cover_image': 'Book cover image. Tap the book card to open.',
      'sort_options': 'Organize your library by recent activity, title, author, or reading progress.',
      
      // Dialog Help
      'bookmark_note': 'Add an optional note to help you remember why you bookmarked this page.',
      'bookmark_delete': 'Remove this bookmark. You can always add it again later.',
      'chapter_navigation': 'Tap a chapter to jump directly to its start page.',
      
      // Additional Help
      'welcome_dialog': 'Welcome to Dual Reader! This dialog appears on first launch to help you get started.',
      'quick_tips_banner': 'Quick tips appear here for first-time users. Dismiss or explore more help.',
      'empty_library': 'Your library is empty. Import EPUB or MOBI files to start reading.',
      
      // Reading Features
      'reading_mode': 'Dual-panel reading mode displays original and translated text simultaneously.',
      'offline_reading': 'Read books and cached translations offline. Initial translations require internet.',
      'progress_tracking': 'Reading progress is automatically saved. Resume from where you left off.',
      
      // Advanced Features
      'settings_export': 'Export your settings to backup or transfer to another device.',
      'settings_import': 'Import previously exported settings to restore your preferences.',
      'language_detection': 'Source language is automatically detected from book content.',
      'translation_cache': 'Translations are cached locally for faster loading and offline access.',
      'no_search_results': 'No books match your search. Try different keywords or clear the search.',
      'delete_confirmation': 'This action cannot be undone. The book will be permanently removed.',
      'translation_error': 'Translation failed. Check your internet connection and try again.',
      'book_loading': 'Loading book content. This may take a moment for large files.',
      'page_calculation': 'Pages are calculated based on your screen size and font settings.',
      'offline_mode': 'Reading offline. Cached translations are available, but new translations require internet.',
      'first_launch': 'Welcome! Import your first book to get started with Dual Reader.',
      
      // Error Messages
      'error_loading_book': 'Failed to load book. Check file format and try again.',
      'error_parsing': 'Error parsing book content. The file may be corrupted.',
      'error_storage': 'Storage error. Check available space and permissions.',
      
      // Platform Specific
      'web_drag_drop': 'On web, you can drag and drop EPUB or MOBI files directly onto the library screen.',
      'mobile_file_picker': 'On mobile, use the file picker to import books from your device storage.',
    };

    return tooltips[featureKey] ?? 'Help information not available for this feature.';
  }
  
  /// Get quick tips for first-time users
  static List<String> getQuickTips() {
    return [
      'Tap anywhere on the reading area to show or hide controls',
      'Rotate your device to switch between portrait and landscape layouts',
      'Bookmarks help you quickly return to important pages',
      'Translations are cached for offline reading after the first translation',
      'Adjust font size and margins to customize how much text fits on each page',
      'Use the page slider to quickly jump to any page in the book',
      'Enable synchronized scrolling to keep both panels aligned while reading',
      'Search your library by title or author to find books quickly',
      'Sort your library by progress to see which books you\'ve read most',
      'Export your settings to transfer them to another device',
      'Dark theme is easier on the eyes for night reading',
      'Tap the page number to enter a specific page directly',
      'Chapters are only available if the book includes chapter information',
      'First translation may take a moment, but subsequent pages load faster',
      'All your data stays on your device - nothing is sent to external servers',
    ];
  }
  
  /// Get a random quick tip
  static String getRandomTip() {
    final tips = getQuickTips();
    return tips[(DateTime.now().millisecondsSinceEpoch % tips.length)];
  }
  
  /// Search documentation content for a query
  static Future<List<String>> searchDocumentation(String query) async {
    if (query.trim().isEmpty) return [];
    
    final results = <String>[];
    final lowerQuery = query.toLowerCase();
    
    // Search in all documentation sections
    final sections = {
      'getting_started': await loadGettingStarted(),
      'features': await loadFeatures(),
      'faq': await loadFAQ(),
      'user_manual': await loadUserManual(),
    };
    
    for (final entry in sections.entries) {
      final content = entry.value.toLowerCase();
      if (content.contains(lowerQuery)) {
        results.add(entry.key);
      }
    }
    
    return results;
  }
  
  /// Get all available tooltip keys
  static List<String> getAllTooltipKeys() {
    return const [
      'import_book', 'library_search', 'library_sort', 'delete_book',
      'translation_language', 'auto_translate', 'sync_scrolling', 'translation_indicator',
      'theme', 'font_family', 'font_size', 'line_height', 'margin_size',
      'text_alignment', 'panel_ratio',
      'bookmark', 'bookmarks', 'chapters', 'page_navigation', 'page_slider',
      'page_input', 'previous_page', 'next_page', 'back_to_library',
      'settings', 'export_settings', 'import_settings',
      'dual_panel', 'toggle_controls', 'reading_progress', 'resume_reading',
      'help', 'documentation',
      'book_card', 'progress_bar', 'cover_image', 'sort_options',
      'bookmark_note', 'bookmark_delete', 'chapter_navigation',
      'reading_mode', 'offline_reading', 'progress_tracking',
      'settings_export', 'settings_import', 'language_detection', 'translation_cache',
      'welcome_dialog', 'quick_tips_banner', 'empty_library',
    ];
  }
  
  /// Get all available documentation sections
  static List<String> getDocumentationSections() {
    return const [
      'quick_tips',
      'getting_started',
      'features',
      'faq',
      'user_manual',
    ];
  }
  
  /// Get section title for a given section key
  static String getSectionTitle(String sectionKey) {
    const titles = {
      'quick_tips': 'Quick Tips',
      'getting_started': 'Getting Started',
      'features': 'Features',
      'faq': 'FAQ',
      'user_manual': 'User Manual',
    };
    return titles[sectionKey] ?? sectionKey;
  }
  
  /// Get section icon for a given section key
  static IconData getSectionIcon(String sectionKey) {
    switch (sectionKey) {
      case 'quick_tips':
        return Icons.lightbulb_outline;
      case 'getting_started':
        return Icons.play_arrow;
      case 'features':
        return Icons.star;
      case 'faq':
        return Icons.help_outline;
      case 'user_manual':
        return Icons.menu_book;
      default:
        return Icons.article;
    }
  }
  
  /// Get help content for a specific feature (combines tooltip with related documentation)
  static Future<String> getFeatureHelp(String featureKey) async {
    final tooltip = getTooltip(featureKey);
    final buffer = StringBuffer();
    buffer.writeln('## $featureKey\n');
    buffer.writeln(tooltip);
    buffer.writeln('\n---\n');
    
    // Try to find related content in documentation
    final query = featureKey.replaceAll('_', ' ');
    final relatedSections = await searchDocumentation(query);
    
    if (relatedSections.isNotEmpty) {
      buffer.writeln('### Related Documentation\n');
      for (final section in relatedSections) {
        buffer.writeln('- See $section section for more details');
      }
    }
    
    return buffer.toString();
  }

  // Default fallback content if files can't be loaded
  static String _getDefaultGettingStarted() {
    return '''# Getting Started with Dual Reader 3.1

Welcome to Dual Reader 3.1! This guide will help you get started with reading ebooks in multiple languages.

## What is Dual Reader?

Dual Reader 3.1 is a cross-platform ebook reader that displays original and translated text side-by-side. It helps you read ebooks in languages you're learning or don't fully understand by showing both the original text and its translation simultaneously.

## First Steps

### 1. Import Your First Book

**On Mobile (Android/iOS):**
- Tap the **"Import Book"** button (floating action button with a plus icon)
- Select an EPUB or MOBI file from your device
- The book will be added to your library automatically

**On Web:**
- Click the **"Import Book"** button
- Or simply drag and drop an EPUB or MOBI file onto the library screen
- The book will be imported and added to your library

### 2. Open a Book

- Tap on any book in your library to start reading
- The app will automatically resume from where you left off (if you've read it before)

### 3. Configure Translation

- Go to **Settings** (gear icon in the top right)
- Select your preferred **Translation Language**
- Enable **Auto-translate** to automatically translate pages as you read

## Understanding the Reader Interface

### Dual-Panel Display

The reader shows two panels:
- **Left/Top Panel**: Original text from the book
- **Right/Bottom Panel**: Translated text

**Portrait Mode**: Panels are stacked vertically (original on top, translation below)
**Landscape Mode**: Panels are side-by-side

### Reader Controls

Tap anywhere on the reading area to show/hide controls:

**Top Bar:**
- **Bookmark Button**: Add or remove bookmarks on the current page
- **Translation Indicator**: Shows when translation is in progress

**Bottom Controls:**
- **Previous/Next Page**: Navigate between pages
- **Page Slider**: Jump to any page quickly
- **Page Number Input**: Type a page number to jump directly
- **Settings**: Customize reading experience
- **Bookmarks**: View and navigate to saved bookmarks
- **Chapters**: Navigate by chapters (if available)
- **Back**: Return to library

## Basic Reading Tips

1. **Swipe or use arrow buttons** to turn pages
2. **Tap the screen** to toggle controls visibility
3. **Use bookmarks** to mark important pages
4. **Adjust settings** to customize your reading experience
5. **Rotate your device** to switch between portrait and landscape layouts

## Next Steps

- Explore **Settings** to customize themes, fonts, and layout
- Learn about **Features** in the Features section
- Check the **FAQ** if you have questions
- Read the **User Manual** for detailed information

Happy reading!''';
  }

  static String _getDefaultFeatures() {
    return '''# Features Guide

Dual Reader 3.1 offers a comprehensive set of features to enhance your reading experience. This guide explains all available features.

## Core Features

### 1. Dual-Panel Display

**What it does:**
Displays original and translated text side-by-side or stacked, depending on device orientation.

**How to use:**
- Open any book to see the dual-panel display
- In portrait mode: Original text appears on top, translation below
- In landscape mode: Original text on left, translation on right
- Both panels scroll together when synchronized scrolling is enabled

**Tips:**
- Rotate your device to switch layouts
- Adjust panel ratio in Settings for landscape mode

### 2. Translation

**What it does:**
Translates book content into your preferred language using free translation services.

**How to use:**
1. Go to Settings → Translation
2. Select your target language from the dropdown
3. Enable "Auto-translate" to translate pages automatically
4. Translations are cached for offline use

**Supported Languages:**
Over 50 languages including Spanish, French, German, Italian, Portuguese, Russian, Chinese, Japanese, Korean, Arabic, and many more.

**Translation Services:**
- LibreTranslate (free, open-source)
- MyMemory Translation API (free tier)

**Tips:**
- Translations are cached locally for offline reading
- First translation may take a moment, subsequent pages load faster
- Translation quality depends on the source language and complexity

### 3. Smart Pagination

**What it does:**
Automatically calculates page breaks based on your screen size, font settings, and margins. Text fits perfectly on each page without scrolling.

**How to use:**
- Pages are calculated automatically when you open a book
- Adjust font size, line height, or margins in Settings to change pagination
- Use page navigation controls to move between pages

**Features:**
- Respects paragraph and sentence boundaries
- Adapts to font size changes
- Recalculates when settings change

### 4. Library Management

**What it does:**
Organize and manage your ebook collection.

**Features:**
- **Import Books**: Add EPUB or MOBI files to your library
- **Search**: Search books by title or author
- **Sort**: Sort by recent, title, author, or reading progress
- **Delete**: Remove books from your library
- **Progress Tracking**: See reading progress for each book

**How to use:**
- Tap "Import Book" to add new books
- Use the search bar to find specific books
- Use sort buttons to organize your library
- Long-press or swipe to delete books (platform dependent)

### 5. Progress Tracking

**What it does:**
Tracks your reading progress for each book automatically.

**How to use:**
- Progress is saved automatically as you read
- Resume reading from where you left off
- View progress percentage in the library
- Progress bar shows completion status

**Features:**
- Automatic saving
- Per-book tracking
- Visual progress indicators

### 6. Bookmarks

**What it does:**
Save important pages for quick access.

**How to use:**
1. Navigate to the page you want to bookmark
2. Tap the bookmark icon in the top bar
3. View all bookmarks via the bookmarks button in controls
4. Tap a bookmark to jump to that page

**Tips:**
- Bookmarks are saved per book
- You can add multiple bookmarks
- Remove bookmarks from the bookmarks dialog

### 7. Chapter Navigation

**What it does:**
Navigate quickly between chapters if the book has a table of contents.

**How to use:**
1. Tap the chapters button in reader controls
2. Select a chapter from the list
3. Reader jumps to the selected chapter

**Note:** Only available if the book includes chapter information.

## Customization Features

### 8. Themes

**What it does:**
Change the appearance of the reader with different color themes.

**Available Themes:**
- **Dark**: Default dark theme, easy on the eyes for night reading
- **Light**: Bright theme for daytime reading
- **Sepia**: Warm sepia tone, reduces eye strain

**How to use:**
Settings → Appearance → Select theme

### 9. Font Customization

**What it does:**
Customize font family, size, and line height for comfortable reading.

**Font Families:**
- Roboto (default)
- Merriweather
- Lora
- Open Sans
- Playfair Display
- Source Serif Pro
- Crimson Text

**Font Sizes:** 12-24 points (adjustable)

**Line Height:** 1.0-2.5 (adjustable)

**How to use:**
Settings → Font → Adjust font family, size, and line height

### 10. Layout Options

**What it does:**
Customize margins, text alignment, and panel ratios.

**Margin Sizes:**
- Small (S)
- Medium (M) - Default
- Large (L)
- Extra Large (XL)
- Extra Extra Large (XXL)

**Text Alignment:**
- Left
- Center
- Justify

**Panel Ratio:** Adjust the width ratio between original and translated panels in landscape mode (30%-70%)

**How to use:**
Settings → Layout → Adjust margins, alignment, and panel ratio

### 11. Synchronized Scrolling

**What it does:**
Keeps both panels synchronized when scrolling.

**How to use:**
Settings → Translation → Enable/disable "Synchronized Scrolling"

**Note:** When enabled, scrolling one panel scrolls the other automatically.

## Advanced Features

### 12. Settings Export/Import

**What it does:**
Save your settings to a file and restore them later or on another device.

**How to use:**
- **Export**: Settings → Settings Management → Export Settings
- **Import**: Settings → Settings Management → Import Settings

**Use Cases:**
- Backup your preferences
- Transfer settings between devices
- Share settings with others

### 13. Offline Support

**What it does:**
Read books and cached translations without an internet connection.

**Features:**
- All books work offline
- Cached translations available offline
- Progress tracking works offline
- Bookmarks work offline

**Note:** Initial translation requires internet connection. Subsequent translations use cached data when available.

## Platform-Specific Features

### Web Features
- **Drag and Drop**: Import books by dragging files onto the library screen
- **PWA Support**: Install as a Progressive Web App
- **Responsive Design**: Adapts to different screen sizes

### Mobile Features
- **Touch Gestures**: Swipe to turn pages, tap to toggle controls
- **Device Rotation**: Automatic layout switching
- **File System Access**: Import from device storage

## Tips for Best Experience

1. **First Time Setup:**
   - Choose your translation language
   - Select a comfortable theme
   - Adjust font size to your preference

2. **Reading:**
   - Use landscape mode for side-by-side comparison
   - Enable synchronized scrolling for easier reading
   - Bookmark important pages

3. **Performance:**
   - Translations are cached, so first read may be slower
   - Large books may take a moment to load initially
   - Adjust font size if pages load slowly

4. **Customization:**
   - Experiment with different themes
   - Find your preferred font and size
   - Adjust margins for comfortable reading''';
  }

  static String _getDefaultFAQ() {
    return '''# FAQ

## Common Questions

**Q: What file formats are supported?**
A: EPUB and MOBI formats.

**Q: Is it free?**
A: Yes, completely free and open-source.

**Q: Does it work offline?**
A: Books work offline. Initial translations require internet.

**Q: Is my data private?**
A: Yes, all data stays on your device.

See the full FAQ for more questions and answers.''';
  }

  static String _getDefaultUserManual() {
    return '''# User Manual

Complete guide to using Dual Reader 3.1.

## Sections

- Installation & Setup
- Library Management
- Reading Interface
- Translation Features
- Customization
- Navigation & Bookmarks
- Settings Reference
- Tips & Tricks
- Troubleshooting

See the full User Manual for detailed information.''';
  }
}
