import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dual_reader/src/domain/entities/settings_entity.dart';
import 'package:dual_reader/src/domain/usecases/get_settings_usecase.dart';
import 'package:dual_reader/src/domain/usecases/update_settings_usecase.dart';
import 'package:dual_reader/src/core/di/injection_container.dart';

class SettingsNotifier extends StateNotifier<SettingsEntity> {
  final GetSettingsUseCase _getSettingsUseCase;
  final UpdateSettingsUseCase _updateSettingsUseCase;

  SettingsNotifier(this._getSettingsUseCase, this._updateSettingsUseCase)
      : super(const SettingsEntity()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    debugPrint('[SettingsNotifier] Loading settings...');
    final loadedSettings = await _getSettingsUseCase();
    debugPrint('[SettingsNotifier] Loaded settings: themeMode=${loadedSettings.themeMode}, targetLang=${loadedSettings.targetTranslationLanguageCode}, fontSize=${loadedSettings.fontSize}');
    state = loadedSettings;
  }

  Future<void> updateSettings(SettingsEntity settings) async {
    debugPrint('[SettingsNotifier] Updating settings: themeMode=${settings.themeMode}, targetLang=${settings.targetTranslationLanguageCode}, fontSize=${settings.fontSize}');
    await _updateSettingsUseCase(settings);
    debugPrint('[SettingsNotifier] Settings saved to repository');
    state = settings;
    debugPrint('[SettingsNotifier] State updated, new state: targetLang=${state.targetTranslationLanguageCode}');
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsEntity>((ref) {
  return SettingsNotifier(sl<GetSettingsUseCase>(), sl<UpdateSettingsUseCase>());
});
