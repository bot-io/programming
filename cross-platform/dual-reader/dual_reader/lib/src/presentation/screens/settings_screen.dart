import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:universal_io/io.dart';
import 'package:hive/hive.dart';
import 'package:dual_reader/src/presentation/providers/settings_notifier.dart';
import 'package:dual_reader/src/presentation/providers/book_list_notifier.dart';
import 'package:dual_reader/src/domain/entities/settings_entity.dart';
import 'package:dual_reader/src/data/services/book_translation_cache_service.dart';
import 'package:dual_reader/src/domain/services/translation_service.dart';
import 'package:dual_reader/src/core/utils/logging_service.dart';
import 'package:get_it/get_it.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const Map<String, String> _languageNames = {
    'en': '🇬🇧 English',
    'es': '🇪🇸 Spanish',
    'bg': '🇧🇬 Bulgarian',
    'fr': '🇫🇷 French',
    'de': '🇩🇪 German',
    'it': '🇮🇹 Italian',
    'pt': '🇵🇹 Portuguese',
    'zh': '🇨🇳 Chinese',
    'ja': '🇯🇵 Japanese',
    'ko': '🇰🇷 Korean',
    'ru': '🇷🇺 Russian',
    'ar': '🇸🇦 Arabic',
  };

  String _getLanguageName(String code) {
    return _languageNames[code] ?? code.toUpperCase();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    debugPrint('[SettingsScreen] BUILD: targetLang=${settings.targetTranslationLanguageCode}, themeMode=${settings.themeMode}');

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Theme Mode'),
            trailing: DropdownButton<ThemeMode>(
              key: ValueKey('theme_${settings.themeMode.index}'),
              value: settings.themeMode,
              onChanged: (ThemeMode? newValue) {
                debugPrint('[SettingsScreen] ThemeMode dropdown changed: ${settings.themeMode} -> $newValue');
                if (newValue != null) {
                  notifier.updateSettings(settings.copyWith(themeMode: newValue));
                }
              },
              items: ThemeMode.values.map((ThemeMode mode) {
                return DropdownMenuItem<ThemeMode>(
                  value: mode,
                  child: Text(mode.name.toUpperCase()),
                );
              }).toList(),
            ),
          ),
          ListTile(
            title: const Text('Font Size'),
            subtitle: Slider(
              value: settings.fontSize,
              min: 12.0,
              max: 32.0,
              divisions: 10,
              label: settings.fontSize.round().toString(),
              onChanged: (double value) {
                notifier.updateSettings(settings.copyWith(fontSize: value));
              },
            ),
          ),
          ListTile(
            title: const Text('Line Height'),
            subtitle: Slider(
              value: settings.lineHeight,
              min: 1.0,
              max: 2.5,
              divisions: 15,
              label: settings.lineHeight.toStringAsFixed(1),
              onChanged: (double value) {
                notifier.updateSettings(settings.copyWith(lineHeight: value));
              },
            ),
          ),
          ListTile(
            title: const Text('Margins'),
            subtitle: Slider(
              value: settings.margin,
              min: 0.0,
              max: 48.0,
              divisions: 6,
              label: settings.margin.round().toString(),
              onChanged: (double value) {
                notifier.updateSettings(settings.copyWith(margin: value));
              },
            ),
          ),
          ListTile(
            title: const Text('Text Alignment'),
            trailing: DropdownButton<TextAlign>(
              key: ValueKey('align_${settings.textAlign.name}'),
              value: settings.textAlign,
              onChanged: (TextAlign? newValue) {
                debugPrint('[SettingsScreen] TextAlign dropdown changed: ${settings.textAlign} -> $newValue');
                if (newValue != null) {
                  notifier.updateSettings(settings.copyWith(textAlign: newValue));
                }
              },
              items: [
                TextAlign.left,
                TextAlign.center,
                TextAlign.right,
                TextAlign.justify,
              ].map((TextAlign alignment) {
                return DropdownMenuItem<TextAlign>(
                  value: alignment,
                  child: Text(alignment.name.toUpperCase()),
                );
              }).toList(),
            ),
          ),
          ListTile(
            title: const Text('Target Translation Language'),
            subtitle: Text('Current: ${_getLanguageName(settings.targetTranslationLanguageCode)}'),
            trailing: DropdownButton<String>(
              key: ValueKey('lang_${settings.targetTranslationLanguageCode}'),
              value: settings.targetTranslationLanguageCode,
              onChanged: (String? newValue) async {
                if (newValue != null && newValue != settings.targetTranslationLanguageCode) {
                  await _handleLanguageChange(context, newValue, settings, notifier);
                }
              },
              items: _languageNames.entries.map((MapEntry<String, String> entry) {
                return DropdownMenuItem<String>(
                  value: entry.key,
                  child: Text(entry.value),
                );
              }).toList(),
            ),
          ),
          const Divider(),
          ListTile(
            title: const Text('View Logs'),
            subtitle: const Text('View last 1000 log entries'),
            trailing: const Icon(Icons.list_alt, color: Colors.blue),
            onTap: () => _exportLogs(context),
          ),
          const Divider(),
          ListTile(
            title: const Text('Clear Translation Cache'),
            subtitle: const Text('Remove all cached translations'),
            trailing: const Icon(Icons.delete_sweep, color: Colors.red),
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Clear Translation Cache'),
                  content: const Text('Are you sure you want to clear all cached translations? This will make translations slower until they are cached again.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text('Clear'),
                    ),
                  ],
                ),
              );

              if (confirmed == true) {
                try {
                  final cache = GetIt.I<BookTranslationCacheService>();
                  // Initialize the cache to ensure the box is open before clearing
                  await cache.init();
                  await cache.clearAll();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Translation cache cleared successfully'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to clear cache: $e'),
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                }
              }
            },
          ),
          const Divider(),
          ListTile(
            title: const Text('Factory Reset'),
            subtitle: const Text('Delete all books, settings, and data'),
            trailing: const Icon(Icons.warning_amber_rounded, color: Colors.red),
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Factory Reset'),
                  content: const Text('⚠️ WARNING: This will delete ALL data including:\n\n• Imported books\n• Reading progress\n• Translation cache\n• Settings\n• Logs\n\nThis action cannot be undone!'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                        backgroundColor: Colors.red.withOpacity(0.1),
                      ),
                      child: const Text('Delete Everything'),
                    ),
                  ],
                ),
              );

              if (confirmed == true) {
                await _performFactoryReset(context, ref);
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _handleLanguageChange(
    BuildContext context,
    String newLanguage,
    SettingsEntity currentSettings,
    SettingsNotifier notifier,
  ) async {
    debugPrint('[SettingsScreen] Language change requested: ${currentSettings.targetTranslationLanguageCode} -> $newLanguage');

    final translationService = GetIt.I<TranslationService>();

    // Check if model is already downloaded
    final isModelReady = await translationService.isLanguageModelReady(newLanguage);

    if (isModelReady) {
      // Model already downloaded, just switch
      debugPrint('[SettingsScreen] Model already downloaded, switching language');
      await notifier.updateSettings(currentSettings.copyWith(targetTranslationLanguageCode: newLanguage));

      if (context.mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      return;
    }

    // Model needs to be downloaded, show progress dialog
    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _LanguageDownloadDialog(
        languageCode: newLanguage,
        languageName: _getLanguageName(newLanguage),
        translationService: translationService,
        onDownloadComplete: (success) async {
          Navigator.of(dialogContext).pop();

          if (success) {
            // Download successful, update settings
            await notifier.updateSettings(currentSettings.copyWith(targetTranslationLanguageCode: newLanguage));

            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Language changed to ${_getLanguageName(newLanguage)}'),
                  duration: const Duration(seconds: 2),
                ),
              );
            }

            // Only pop if we're being pushed from another screen
            if (context.mounted && Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          } else {
            // Download failed, show error and keep old language
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Language model download failed. Please check your internet connection and try again.'),
                  duration: Duration(seconds: 4),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
      ),
    );
  }

  Future<void> _exportLogs(BuildContext context) async {
    // Show log viewer dialog
    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (dialogContext) => _LogViewerDialog(),
    );
  }

  Future<void> _performFactoryReset(BuildContext context, WidgetRef ref) async {
    debugPrint('[SettingsScreen] Performing factory reset');

    // Show loading dialog
    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => const AlertDialog(
        title: Text('Factory Reset'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Deleting all data...'),
          ],
        ),
      ),
    );

    try {
      // 1. Clear all Hive boxes
      await Hive.deleteBoxFromDisk('books');
      await Hive.deleteBoxFromDisk('book_bytes'); // Book file storage
      await Hive.deleteBoxFromDisk('app_logs');
      await Hive.deleteBoxFromDisk('settings');
      await Hive.deleteBoxFromDisk('translation_cache');

      debugPrint('[SettingsScreen] Hive boxes cleared');

      // 2. Delete book files from documents directory
      final appDocDir = await getApplicationDocumentsDirectory();
      final booksDir = Directory('${appDocDir.path}/books');

      if (await booksDir.exists()) {
        await booksDir.delete(recursive: true);
        debugPrint('[SettingsScreen] Book files deleted');
      }

      // 3. Clear any additional Hive data
      await Hive.deleteFromDisk();

      debugPrint('[SettingsScreen] Factory reset complete');

      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // Invalidate all providers to force reload with fresh data
      ref.invalidate(bookListProvider);
      ref.invalidate(settingsProvider);

      // Show success message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All data deleted successfully. Please restart the app.'),
            duration: Duration(seconds: 3),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Navigate back to home screen after a short delay
      await Future.delayed(const Duration(seconds: 1));
      if (context.mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      debugPrint('[SettingsScreen] Factory reset failed: $e');

      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // Show error message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Factory reset failed: $e'),
            duration: const Duration(seconds: 5),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

/// Dialog showing language model download progress
class _LanguageDownloadDialog extends StatefulWidget {
  final String languageCode;
  final String languageName;
  final TranslationService translationService;
  final void Function(bool success) onDownloadComplete;

  const _LanguageDownloadDialog({
    required this.languageCode,
    required this.languageName,
    required this.translationService,
    required this.onDownloadComplete,
  });

  @override
  State<_LanguageDownloadDialog> createState() => _LanguageDownloadDialogState();
}

class _LanguageDownloadDialogState extends State<_LanguageDownloadDialog> {
  String _progressMessage = 'Preparing download...';
  bool _isDownloading = true;

  @override
  void initState() {
    super.initState();
    _startDownload();
  }

  Future<void> _startDownload() async {
    final success = await widget.translationService.downloadLanguageModel(
      widget.languageCode,
      onProgress: (message) {
        if (mounted) {
          setState(() {
            _progressMessage = message;
          });
        }
      },
    );

    if (mounted) {
      setState(() {
        _isDownloading = false;
      });
    }

    widget.onDownloadComplete(success);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Downloading Language Model'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isDownloading) ...[
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('Downloading ${widget.languageName} model...'),
            const SizedBox(height: 8),
            Text(
              _progressMessage,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ] else ...[
            const Icon(Icons.check_circle, color: Colors.green, size: 48),
            const SizedBox(height: 16),
            const Text('Model downloaded successfully!'),
          ],
        ],
      ),
    );
  }
}

/// Log viewer dialog that shows the last 1000 log entries
class _LogViewerDialog extends StatefulWidget {
  const _LogViewerDialog();

  @override
  State<_LogViewerDialog> createState() => _LogViewerDialogState();
}

class _LogViewerDialogState extends State<_LogViewerDialog> {
  static const int _maxLogLines = 1000;
  bool _isLoading = true;
  String _logContent = '';
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    try {
      final loggingService = LoggingService.instance;
      await loggingService.init();

      // Small delay to ensure Hive is ready
      await Future.delayed(const Duration(milliseconds: 100));

      // Get all logs
      final logs = await loggingService.getAllLogsForExport();

      if (logs.isEmpty) {
        setState(() {
          _isLoading = false;
          _logContent = 'No logs available.';
        });
        return;
      }

      // Format logs and limit to last 1000 entries
      final buffer = StringBuffer();
      final startIndex = logs.length > _maxLogLines ? logs.length - _maxLogLines : 0;
      final recentLogs = logs.sublist(startIndex);

      buffer.writeln('=== Dual Reader Logs (showing last ${recentLogs.length} entries) ===');
      buffer.writeln('Total logs: ${logs.length}');
      buffer.writeln('');

      for (final log in recentLogs) {
        final timestamp = log.timestamp.toIso8601String().substring(0, 19);
        final level = log.level.name.toUpperCase().padRight(7);
        final component = log.component.padRight(20);
        buffer.writeln('[$timestamp] [$level] [$component] ${log.message}');

        if (log.error != null && log.error!.isNotEmpty) {
          buffer.writeln('  Error: ${log.error}');
        }
        if (log.stackTrace != null && log.stackTrace!.isNotEmpty) {
          final lines = log.stackTrace!.split('\n');
          for (final line in lines.take(5)) { // Limit stack trace to 5 lines
            buffer.writeln('  $line');
          }
        }
      }

      setState(() {
        _isLoading = false;
        _logContent = buffer.toString();
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load logs: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.list_alt, size: 24),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'App Logs',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _isLoading ? null : () {
                    setState(() {
                      _isLoading = true;
                      _logContent = '';
                      _errorMessage = '';
                    });
                    _loadLogs();
                  },
                  tooltip: 'Refresh',
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Close',
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),

            // Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage.isNotEmpty
                      ? Center(
                          child: Text(
                            _errorMessage,
                            style: const TextStyle(color: Colors.red),
                          ),
                        )
                      : SingleChildScrollView(
                          child: SelectableText(
                            _logContent,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        ),
            ),

            // Footer with clear button
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy'),
                  onPressed: _isLoading ? null : () async {
                    await Clipboard.setData(ClipboardData(text: _logContent));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Logs copied to clipboard'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Clear Logs'),
                  onPressed: _isLoading ? null : () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Clear Logs'),
                        content: const Text('Are you sure you want to clear all logs?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text('Clear', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );

                    if (confirmed == true) {
                      await LoggingService.instance.clearAllLogs();
                      setState(() {
                        _logContent = 'Logs cleared.';
                      });
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
