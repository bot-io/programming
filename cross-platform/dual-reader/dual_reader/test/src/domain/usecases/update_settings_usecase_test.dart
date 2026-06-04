import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:dual_reader/src/domain/entities/settings_entity.dart';
import 'package:dual_reader/src/domain/repositories/settings_repository.dart';
import 'package:dual_reader/src/domain/usecases/update_settings_usecase.dart';

/// Fake implementation of [SettingsRepository] for testing
class FakeSettingsRepository implements SettingsRepository {
  SettingsEntity? _savedSettings;
  bool _shouldThrow = false;
  String _errorMessage = 'Repository error';
  int _saveCallCount = 0;

  FakeSettingsRepository();

  void setError(bool shouldThrow, [String message = 'Repository error']) {
    _shouldThrow = shouldThrow;
    _errorMessage = message;
  }

  SettingsEntity? get savedSettings => _savedSettings;
  int get saveCallCount => _saveCallCount;

  @override
  Future<SettingsEntity> getSettings() async {
    return _savedSettings ?? const SettingsEntity();
  }

  @override
  Future<void> saveSettings(SettingsEntity settings) async {
    _saveCallCount++;
    if (_shouldThrow) {
      throw Exception(_errorMessage);
    }
    _savedSettings = settings;
  }
}

void main() {
  group('UpdateSettingsUseCase', () {
    late FakeSettingsRepository fakeSettingsRepository;
    late UpdateSettingsUseCase useCase;

    setUp(() {
      fakeSettingsRepository = FakeSettingsRepository();
      useCase = UpdateSettingsUseCase(fakeSettingsRepository);
    });

    test('should save settings to the repository', () async {
      // Arrange
      const settings = SettingsEntity(
        themeMode: ThemeMode.dark,
        fontSize: 20.0,
      );

      // Act
      await useCase(settings);

      // Assert
      expect(fakeSettingsRepository.saveCallCount, equals(1));
      expect(fakeSettingsRepository.savedSettings, isNotNull);
      expect(fakeSettingsRepository.savedSettings!.themeMode, equals(ThemeMode.dark));
      expect(fakeSettingsRepository.savedSettings!.fontSize, equals(20.0));
    });

    test('should save default settings', () async {
      // Arrange
      const settings = SettingsEntity();

      // Act
      await useCase(settings);

      // Assert
      expect(fakeSettingsRepository.savedSettings, equals(const SettingsEntity()));
    });

    test('should save settings with all custom properties', () async {
      // Arrange
      const settings = SettingsEntity(
        themeMode: ThemeMode.light,
        fontlFamily: 'Georgia',
        fontSize: 22.0,
        lineHeight: 2.0,
        margin: 32.0,
        textAlign: TextAlign.center,
        panelWidthRatio: 0.7,
        targetTranslationLanguageCode: 'de',
      );

      // Act
      await useCase(settings);

      // Assert
      final saved = fakeSettingsRepository.savedSettings!;
      expect(saved.themeMode, equals(ThemeMode.light));
      expect(saved.fontlFamily, equals('Georgia'));
      expect(saved.fontSize, equals(22.0));
      expect(saved.lineHeight, equals(2.0));
      expect(saved.margin, equals(32.0));
      expect(saved.textAlign, equals(TextAlign.center));
      expect(saved.panelWidthRatio, equals(0.7));
      expect(saved.targetTranslationLanguageCode, equals('de'));
    });

    test('should overwrite previous settings when called again', () async {
      // Arrange
      const firstSettings = SettingsEntity(fontSize: 14.0);
      const secondSettings = SettingsEntity(fontSize: 18.0);

      // Act
      await useCase(firstSettings);
      await useCase(secondSettings);

      // Assert
      expect(fakeSettingsRepository.saveCallCount, equals(2));
      expect(fakeSettingsRepository.savedSettings!.fontSize, equals(18.0));
    });

    test('should propagate exception when repository throws', () async {
      // Arrange
      fakeSettingsRepository.setError(true, 'Save failed');
      const settings = SettingsEntity();

      // Act & Assert
      expect(
        () => useCase(settings),
        throwsA(isA<Exception>()),
      );
    });

    test('should not update saved settings when repository throws', () async {
      // Arrange
      const firstSettings = SettingsEntity(fontSize: 14.0);
      await useCase(firstSettings);
      expect(fakeSettingsRepository.savedSettings!.fontSize, equals(14.0));

      fakeSettingsRepository.setError(true);
      const secondSettings = SettingsEntity(fontSize: 24.0);

      // Act
      try {
        await useCase(secondSettings);
      } catch (_) {
        // Expected exception
      }

      // Assert - original settings should still be there
      expect(fakeSettingsRepository.savedSettings!.fontSize, equals(14.0));
    });

    test('should save settings with copyWith modifications', () async {
      // Arrange
      const baseSettings = SettingsEntity();
      final modifiedSettings = baseSettings.copyWith(
        fontSize: 24.0,
        lineHeight: 2.0,
        targetTranslationLanguageCode: 'ja',
      );

      // Act
      await useCase(modifiedSettings);

      // Assert
      final saved = fakeSettingsRepository.savedSettings!;
      expect(saved.fontSize, equals(24.0));
      expect(saved.lineHeight, equals(2.0));
      expect(saved.targetTranslationLanguageCode, equals('ja'));
      // Unchanged fields keep defaults
      expect(saved.fontlFamily, equals('Roboto'));
      expect(saved.margin, equals(16.0));
    });
  });
}
