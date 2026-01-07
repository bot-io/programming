import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:dual_reader/src/domain/entities/settings_entity.dart';
import 'package:dual_reader/src/domain/repositories/settings_repository.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  static const String _boxName = 'settings';
  static const String _settingsKey = 'userSettings';

  Future<Box<SettingsEntity>> _openBox() async {
    if (!Hive.isBoxOpen(_boxName)) {
      debugPrint('[SettingsRepository] Opening box $_boxName');
      return await Hive.openBox<SettingsEntity>(_boxName);
    } else {
      return Hive.box<SettingsEntity>(_boxName);
    }
  }

  @override
  Future<SettingsEntity> getSettings() async {
    final box = await _openBox();
    final settings = box.get(_settingsKey) ?? const SettingsEntity();
    debugPrint('[SettingsRepository] getSettings: targetLang=${settings.targetTranslationLanguageCode}');
    return settings; // Return default settings if none found
  }

  @override
  Future<void> saveSettings(SettingsEntity settings) async {
    debugPrint('[SettingsRepository] saveSettings: targetLang=${settings.targetTranslationLanguageCode}');
    final box = await _openBox();
    await box.put(_settingsKey, settings);
    debugPrint('[SettingsRepository] saveSettings completed');
  }
}

