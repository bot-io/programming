import 'package:dual_reader/src/domain/entities/settings_entity.dart';
import 'package:dual_reader/src/domain/repositories/settings_repository.dart';

class GetSettingsUseCase {
  final SettingsRepository _settingsRepository;

  GetSettingsUseCase(this._settingsRepository);

  Future<SettingsEntity> call() async {
    return await _settingsRepository.getSettings();
  }
}

