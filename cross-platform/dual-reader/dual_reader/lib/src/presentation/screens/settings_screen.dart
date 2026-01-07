import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dual_reader/src/presentation/providers/settings_notifier.dart';
import 'package:dual_reader/src/domain/entities/settings_entity.dart';
import 'package:dual_reader/src/data/services/book_translation_cache_service.dart';
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
                debugPrint('[SettingsScreen] Language dropdown onChanged: ${settings.targetTranslationLanguageCode} -> $newValue');
                if (newValue != null && newValue != settings.targetTranslationLanguageCode) {
                  debugPrint('[SettingsScreen] Calling updateSettings with new language: $newValue');
                  await notifier.updateSettings(settings.copyWith(targetTranslationLanguageCode: newValue));
                  debugPrint('[SettingsScreen] updateSettings completed, language is now ${notifier.state.targetTranslationLanguageCode}');

                  // Only pop if we're being pushed from another screen (not the main settings)
                  if (Navigator.of(context).canPop()) {
                    debugPrint('[SettingsScreen] Popping settings screen to refresh reading view');
                    Navigator.of(context).pop();
                  }
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
        ],
      ),
    );
  }
}
