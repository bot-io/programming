import 'package:dual_reader/src/domain/entities/settings_entity.dart';
import 'package:dual_reader/src/domain/repositories/settings_repository.dart';

class UpdateSettingsUseCase {
  final SettingsRepository _settingsRepository;

  UpdateSettingsUseCase(this._settingsRepository);

  Future<void> call(SettingsEntity settings) async {
    await _settingsRepository.saveSettings(settings);
  }
}

