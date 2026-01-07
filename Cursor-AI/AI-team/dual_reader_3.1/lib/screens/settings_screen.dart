import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/settings_provider.dart';
import '../services/help_service.dart';

// Conditional import for web
import 'dart:html' as html show AnchorElement, Url, Blob if (dart.library.html);

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              context.push('/help');
            },
            tooltip: HelpService.getTooltip('help'),
          ),
        ],
      ),
      body: Consumer<SettingsProvider>(
        builder: (context, settingsProvider, child) {
          final settings = settingsProvider.settings;
          
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Theme
              _buildSectionTitle(context, 'Appearance'),
              Row(
                children: [
                  Expanded(
                    child: _buildThemeSelector(context, settingsProvider, settings.theme),
                  ),
                  IconButton(
                    icon: const Icon(Icons.help_outline),
                    onPressed: () => _showHelpTooltip(context, 'theme'),
                    tooltip: HelpService.getTooltip('theme'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Font
              _buildSectionTitle(context, 'Font'),
              Row(
                children: [
                  Expanded(
                    child: _buildFontFamilySelector(context, settingsProvider, settings.fontFamily),
                  ),
                  IconButton(
                    icon: const Icon(Icons.help_outline),
                    onPressed: () => _showHelpTooltip(context, 'font_family'),
                    tooltip: HelpService.getTooltip('font_family'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildFontSizeSlider(context, settingsProvider, settings.fontSize, 'font_size'),
              const SizedBox(height: 8),
              _buildLineHeightSlider(context, settingsProvider, settings.lineHeight, 'line_height'),
              const SizedBox(height: 16),
              
              // Layout
              _buildSectionTitle(context, 'Layout'),
              Row(
                children: [
                  Expanded(
                    child: _buildMarginSizeSelector(context, settingsProvider, settings.marginSize),
                  ),
                  IconButton(
                    icon: const Icon(Icons.help_outline),
                    onPressed: () => _showHelpTooltip(context, 'margin_size'),
                    tooltip: HelpService.getTooltip('margin_size'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildTextAlignmentSelector(context, settingsProvider, settings.textAlignment),
                  ),
                  IconButton(
                    icon: const Icon(Icons.help_outline),
                    onPressed: () => _showHelpTooltip(context, 'text_alignment'),
                    tooltip: HelpService.getTooltip('text_alignment'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildPanelRatioSlider(context, settingsProvider, settings.panelRatio, 'panel_ratio'),
              const SizedBox(height: 16),
              
              // Translation
              _buildSectionTitle(context, 'Translation'),
              Row(
                children: [
                  Expanded(
                    child: _buildTranslationLanguageSelector(context, settingsProvider, settings.translationLanguage),
                  ),
                  IconButton(
                    icon: const Icon(Icons.help_outline),
                    onPressed: () => _showHelpTooltip(context, 'translation_language'),
                    tooltip: HelpService.getTooltip('translation_language'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                title: const Text('Auto-translate'),
                subtitle: Text('Automatically translate pages when reading\n${HelpService.getTooltip('auto_translate')}'),
                value: settings.autoTranslate,
                onChanged: (value) {
                  settingsProvider.updateAutoTranslate(value);
                },
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                title: const Text('Synchronized Scrolling'),
                subtitle: Text('Sync scroll between original and translated panels\n${HelpService.getTooltip('sync_scrolling')}'),
                value: settings.syncScrolling,
                onChanged: (value) {
                  settingsProvider.updateSyncScrolling(value);
                },
              ),
              const SizedBox(height: 16),
              
              // Export/Import Settings
              _buildSectionTitle(context, 'Settings Management'),
              ListTile(
                leading: const Icon(Icons.upload_file),
                title: const Text('Export Settings'),
                subtitle: Text('Save your settings to a file\n${HelpService.getTooltip('export_settings')}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.help_outline, size: 18),
                      onPressed: () => _showHelpTooltip(context, 'export_settings'),
                      tooltip: HelpService.getTooltip('export_settings'),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
                onTap: () => _exportSettings(context, settingsProvider),
              ),
              ListTile(
                leading: const Icon(Icons.download),
                title: const Text('Import Settings'),
                subtitle: Text('Load settings from a file\n${HelpService.getTooltip('import_settings')}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.help_outline, size: 18),
                      onPressed: () => _showHelpTooltip(context, 'import_settings'),
                      tooltip: HelpService.getTooltip('import_settings'),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
                onTap: () => _importSettings(context, settingsProvider),
              ),
              const SizedBox(height: 16),
              
              // Help
              _buildSectionTitle(context, 'Help'),
              ListTile(
                leading: const Icon(Icons.help_outline),
                title: const Text('Help & Documentation'),
                subtitle: const Text('Getting started, features, FAQ, and user manual'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  context.push('/help');
                },
              ),
              const SizedBox(height: 16),
              
              // About
              _buildSectionTitle(context, 'About'),
              _buildAboutSection(context),
            ],
          );
        },
      ),
    );
  }

  Future<void> _exportSettings(BuildContext context, SettingsProvider provider) async {
    try {
      if (kIsWeb) {
        // Web: Download file via browser
        final jsonString = provider.exportSettingsJson();
        final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
        final fileName = 'dual_reader_settings_$timestamp.json';
        
        // Create blob and download
        final bytes = utf8.encode(jsonString);
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', fileName)
          ..click();
        html.Url.revokeObjectUrl(url);
        
        // Also copy to clipboard for convenience
        await Clipboard.setData(ClipboardData(text: jsonString));
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Settings exported and copied to clipboard'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        // Mobile/Desktop: Use file picker
        final result = await provider.exportSettingsToFile();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export settings: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _importSettings(BuildContext context, SettingsProvider provider) async {
    try {
      final result = await provider.importSettingsFromFile();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to import settings: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Widget _buildAboutSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: const Text('App Version'),
          subtitle: const Text('3.1.0+1'),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.code),
          title: const Text('Credits'),
          subtitle: const Text('Built with Flutter\nOpen source ebook reader'),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.description),
          title: const Text('License'),
          subtitle: const Text('This app is open source and free to use.'),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.library_books),
          title: const Text('Supported Formats'),
          subtitle: const Text('EPUB, MOBI'),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.translate),
          title: const Text('Translation Services'),
          subtitle: const Text('LibreTranslate, MyMemory Translation API'),
        ),
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'Dual Reader 3.1\n\n'
            'This app is designed to help you read ebooks in multiple languages by displaying '
            'the original text alongside its translation. All processing is done locally on your device, '
            'ensuring your privacy.\n\n'
            'Features:\n'
            '• Dual-panel display (original and translated)\n'
            '• Smart pagination\n'
            '• Translation caching for offline use\n'
            '• Customizable themes and fonts\n'
            '• Bookmark and chapter navigation\n'
            '• Progress tracking',
            style: TextStyle(fontSize: 12, height: 1.5),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildThemeSelector(BuildContext context, SettingsProvider provider, String currentTheme) {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(value: 'dark', label: Text('Dark')),
        ButtonSegment(value: 'light', label: Text('Light')),
        ButtonSegment(value: 'sepia', label: Text('Sepia')),
      ],
      selected: {currentTheme},
      onSelectionChanged: (Set<String> selection) {
        provider.updateTheme(selection.first);
      },
    );
  }

  Widget _buildFontFamilySelector(BuildContext context, SettingsProvider provider, String currentFont) {
    final fonts = ['Roboto', 'Merriweather', 'Lora', 'Open Sans', 'Playfair Display', 'Source Serif Pro', 'Crimson Text'];
    
    return DropdownButtonFormField<String>(
      value: currentFont,
      decoration: const InputDecoration(
        labelText: 'Font Family',
        border: OutlineInputBorder(),
      ),
      items: fonts.map((font) => DropdownMenuItem(
        value: font,
        child: Text(font),
      )).toList(),
      onChanged: (value) {
        if (value != null) {
          provider.updateFontFamily(value);
        }
      },
    );
  }

  Widget _buildFontSizeSlider(BuildContext context, SettingsProvider provider, int currentSize, String helpKey) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Font Size: $currentSize'),
            IconButton(
              icon: const Icon(Icons.help_outline, size: 18),
              onPressed: () => _showHelpTooltip(context, helpKey),
              tooltip: HelpService.getTooltip(helpKey),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        Slider(
          value: currentSize.toDouble(),
          min: 12,
          max: 24,
          divisions: 12,
          label: currentSize.toString(),
          onChanged: (value) {
            provider.updateFontSize(value.round());
          },
        ),
      ],
    );
  }

  Widget _buildLineHeightSlider(BuildContext context, SettingsProvider provider, double currentHeight, String helpKey) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Line Height: ${currentHeight.toStringAsFixed(1)}'),
            IconButton(
              icon: const Icon(Icons.help_outline, size: 18),
              onPressed: () => _showHelpTooltip(context, helpKey),
              tooltip: HelpService.getTooltip(helpKey),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        Slider(
          value: currentHeight,
          min: 1.0,
          max: 2.5,
          divisions: 15,
          label: currentHeight.toStringAsFixed(1),
          onChanged: (value) {
            provider.updateLineHeight(value);
          },
        ),
      ],
    );
  }

  Widget _buildMarginSizeSelector(BuildContext context, SettingsProvider provider, int currentMargin) {
    return SegmentedButton<int>(
      segments: const [
        ButtonSegment(value: 0, label: Text('S')),
        ButtonSegment(value: 1, label: Text('M')),
        ButtonSegment(value: 2, label: Text('L')),
        ButtonSegment(value: 3, label: Text('XL')),
        ButtonSegment(value: 4, label: Text('XXL')),
      ],
      selected: {currentMargin},
      onSelectionChanged: (Set<int> selection) {
        provider.updateMarginSize(selection.first);
      },
    );
  }

  Widget _buildTextAlignmentSelector(BuildContext context, SettingsProvider provider, String currentAlignment) {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(value: 'left', icon: Icon(Icons.format_align_left)),
        ButtonSegment(value: 'center', icon: Icon(Icons.format_align_center)),
        ButtonSegment(value: 'justify', icon: Icon(Icons.format_align_justify)),
      ],
      selected: {currentAlignment},
      onSelectionChanged: (Set<String> selection) {
        provider.updateTextAlignment(selection.first);
      },
    );
  }

  Widget _buildPanelRatioSlider(BuildContext context, SettingsProvider provider, double currentRatio, String helpKey) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Panel Ratio: ${(currentRatio * 100).toStringAsFixed(0)}%'),
            IconButton(
              icon: const Icon(Icons.help_outline, size: 18),
              onPressed: () => _showHelpTooltip(context, helpKey),
              tooltip: HelpService.getTooltip(helpKey),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        Slider(
          value: currentRatio,
          min: 0.3,
          max: 0.7,
          divisions: 40,
          label: '${(currentRatio * 100).toStringAsFixed(0)}%',
          onChanged: (value) {
            provider.updatePanelRatio(value);
          },
        ),
      ],
    );
  }

  Widget _buildTranslationLanguageSelector(BuildContext context, SettingsProvider provider, String currentLanguage) {
    final languages = {
      'es': 'Spanish',
      'fr': 'French',
      'de': 'German',
      'it': 'Italian',
      'pt': 'Portuguese',
      'ru': 'Russian',
      'zh': 'Chinese',
      'ja': 'Japanese',
      'ko': 'Korean',
      'ar': 'Arabic',
      'hi': 'Hindi',
      'tr': 'Turkish',
      'pl': 'Polish',
      'nl': 'Dutch',
      'sv': 'Swedish',
      'no': 'Norwegian',
      'da': 'Danish',
      'fi': 'Finnish',
      'cs': 'Czech',
      'ro': 'Romanian',
      'hu': 'Hungarian',
      'el': 'Greek',
      'he': 'Hebrew',
      'th': 'Thai',
      'vi': 'Vietnamese',
      'id': 'Indonesian',
      'ms': 'Malay',
      'uk': 'Ukrainian',
      'bg': 'Bulgarian',
      'hr': 'Croatian',
      'sk': 'Slovak',
      'sl': 'Slovenian',
      'et': 'Estonian',
      'lv': 'Latvian',
      'lt': 'Lithuanian',
      'ga': 'Irish',
      'mt': 'Maltese',
      'cy': 'Welsh',
      'is': 'Icelandic',
      'mk': 'Macedonian',
      'sq': 'Albanian',
      'sr': 'Serbian',
      'bs': 'Bosnian',
      'ca': 'Catalan',
      'eu': 'Basque',
      'gl': 'Galician',
      'fa': 'Persian',
      'ur': 'Urdu',
      'bn': 'Bengali',
      'ta': 'Tamil',
      'te': 'Telugu',
      'ml': 'Malayalam',
      'kn': 'Kannada',
      'gu': 'Gujarati',
      'pa': 'Punjabi',
      'ne': 'Nepali',
      'si': 'Sinhala',
      'my': 'Myanmar',
      'km': 'Khmer',
      'lo': 'Lao',
      'ka': 'Georgian',
      'hy': 'Armenian',
      'az': 'Azerbaijani',
      'kk': 'Kazakh',
      'ky': 'Kyrgyz',
      'uz': 'Uzbek',
      'mn': 'Mongolian',
      'be': 'Belarusian',
      'af': 'Afrikaans',
      'sw': 'Swahili',
      'zu': 'Zulu',
      'xh': 'Xhosa',
      'am': 'Amharic',
      'yo': 'Yoruba',
      'ig': 'Igbo',
      'ha': 'Hausa',
    };
    
    return DropdownButtonFormField<String>(
      value: currentLanguage,
      decoration: const InputDecoration(
        labelText: 'Translation Language',
        border: OutlineInputBorder(),
      ),
      items: languages.entries.map((entry) => DropdownMenuItem(
        value: entry.key,
        child: Text(entry.value),
      )).toList(),
      onChanged: (value) {
        if (value != null) {
          provider.updateTranslationLanguage(value);
        }
      },
    );
  }

  void _showHelpTooltip(BuildContext context, String featureKey) {
    final tooltip = HelpService.getTooltip(featureKey);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.help_outline),
            SizedBox(width: 8),
            Text('Help'),
          ],
        ),
        content: Text(tooltip),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.push('/help');
            },
            child: const Text('More Help'),
          ),
        ],
      ),
    );
  }
}
