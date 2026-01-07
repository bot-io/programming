import 'package:dual_reader/src/domain/entities/settings_entity.dart';

abstract class SettingsRepository {
  Future<SettingsEntity> getSettings();
  Future<void> saveSettings(SettingsEntity settings);
}

