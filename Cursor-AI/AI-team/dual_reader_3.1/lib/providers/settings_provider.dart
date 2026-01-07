import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import '../models/app_settings.dart';
import '../services/storage_service.dart';

// Platform-specific imports
import 'dart:io' if (dart.library.html) 'dart:html' as html;
import 'package:path_provider/path_provider.dart';

class SettingsProvider with ChangeNotifier {
  final StorageService _storageService;
  
  AppSettings _settings = AppSettings();
  bool _isLoading = false;

  SettingsProvider(this._storageService) {
    _loadSettings();
  }

  AppSettings get settings => _settings;
  bool get isLoading => _isLoading;

  Future<void> _loadSettings() async {
    _isLoading = true;
    notifyListeners();

    try {
      _settings = await _storageService.getSettings();
    } catch (e) {
      // Use default settings if loading fails
      _settings = AppSettings();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateSettings(AppSettings newSettings) async {
    _settings = newSettings;
    await _storageService.saveSettings(newSettings);
    notifyListeners();
  }

  Future<void> updateTheme(String theme) async {
    _settings = _settings.copyWith(theme: theme);
    await _storageService.saveSettings(_settings);
    notifyListeners();
  }

  Future<void> updateFontFamily(String fontFamily) async {
    _settings = _settings.copyWith(fontFamily: fontFamily);
    await _storageService.saveSettings(_settings);
    notifyListeners();
  }

  Future<void> updateFontSize(int fontSize) async {
    _settings = _settings.copyWith(fontSize: fontSize);
    await _storageService.saveSettings(_settings);
    notifyListeners();
  }

  Future<void> updateLineHeight(double lineHeight) async {
    _settings = _settings.copyWith(lineHeight: lineHeight);
    await _storageService.saveSettings(_settings);
    notifyListeners();
  }

  Future<void> updateMarginSize(int marginSize) async {
    _settings = _settings.copyWith(marginSize: marginSize);
    await _storageService.saveSettings(_settings);
    notifyListeners();
  }

  Future<void> updateTextAlignment(String alignment) async {
    _settings = _settings.copyWith(textAlignment: alignment);
    await _storageService.saveSettings(_settings);
    notifyListeners();
  }

  Future<void> updateTranslationLanguage(String language) async {
    _settings = _settings.copyWith(translationLanguage: language);
    await _storageService.saveSettings(_settings);
    notifyListeners();
  }

  Future<void> updateAutoTranslate(bool autoTranslate) async {
    _settings = _settings.copyWith(autoTranslate: autoTranslate);
    await _storageService.saveSettings(_settings);
    notifyListeners();
  }

  Future<void> updatePanelRatio(double ratio) async {
    _settings = _settings.copyWith(panelRatio: ratio);
    await _storageService.saveSettings(_settings);
    notifyListeners();
  }

  Future<void> updateSyncScrolling(bool sync) async {
    _settings = _settings.copyWith(syncScrolling: sync);
    await _storageService.saveSettings(_settings);
    notifyListeners();
  }

  /// Export settings as JSON string
  String exportSettingsJson() {
    final settingsMap = {
      'theme': _settings.theme,
      'fontFamily': _settings.fontFamily,
      'fontSize': _settings.fontSize,
      'lineHeight': _settings.lineHeight,
      'marginSize': _settings.marginSize,
      'textAlignment': _settings.textAlignment,
      'translationLanguage': _settings.translationLanguage,
      'autoTranslate': _settings.autoTranslate,
      'panelRatio': _settings.panelRatio,
      'syncScrolling': _settings.syncScrolling,
      'version': '3.1.0',
    };
    return jsonEncode(settingsMap);
  }

  /// Export settings to a file
  Future<String> exportSettingsToFile() async {
    try {
      final jsonString = exportSettingsJson();
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
      final fileName = 'dual_reader_settings_$timestamp.json';

      if (kIsWeb) {
        // Web: Return JSON string - UI will handle download
        return jsonString;
      } else {
        // Mobile/Desktop: Save to file using file_picker
        String? outputPath = await FilePicker.platform.saveFile(
          dialogTitle: 'Save Settings',
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: ['json'],
        );

        if (outputPath != null) {
          final file = File(outputPath);
          await file.writeAsString(jsonString);
          return 'Settings exported to: $outputPath';
        } else {
          throw Exception('Export cancelled');
        }
      }
    } catch (e) {
      throw Exception('Failed to export settings: $e');
    }
  }

  /// Import settings from a file
  Future<String> importSettingsFromFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        throw Exception('No file selected');
      }

      String jsonString;
      
      // Try to use bytes first (works on all platforms)
      final bytes = result.files.single.bytes;
      if (bytes != null) {
        jsonString = utf8.decode(bytes);
      } else if (!kIsWeb) {
        // Fallback to file path on mobile/desktop
        final filePath = result.files.single.path;
        if (filePath == null) {
          throw Exception('File path is null');
        }
        final file = File(filePath);
        jsonString = await file.readAsString();
      } else {
        throw Exception('Failed to read file - no data available');
      }

      // Import using existing method
      final success = await importSettings(jsonString);
      if (success) {
        return 'Settings imported successfully';
      } else {
        throw Exception('Failed to parse settings file');
      }
    } catch (e) {
      throw Exception('Failed to import settings: $e');
    }
  }

  /// Import settings from JSON string
  Future<bool> importSettings(String jsonString) async {
    try {
      final settingsMap = jsonDecode(jsonString) as Map<String, dynamic>;
      
      // Validate version if present
      if (settingsMap.containsKey('version')) {
        final version = settingsMap['version'] as String;
        if (!version.startsWith('3.')) {
          return false; // Incompatible version
        }
      }

      // Use AppSettings.fromJson for consistency
      final importedSettings = AppSettings.fromJson(settingsMap);

      await updateSettings(importedSettings);
      return true;
    } catch (e) {
      debugPrint('Failed to import settings: $e');
      return false;
    }
  }
}
