import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:dual_reader/src/domain/entities/settings_entity.dart';
import 'package:dual_reader/src/domain/repositories/settings_repository.dart';
import 'package:dual_reader/src/domain/usecases/get_settings_usecase.dart';

/// Fake implementation of [SettingsRepository] for testing
class FakeSettingsRepository implements SettingsRepository {
  SettingsEntity? _settings;
  bool _shouldThrow = false;
  String _errorMessage = 'Repository error';

  FakeSettingsRepository({SettingsEntity? settings})
      : _settings = settings;

  void setError(bool shouldThrow, [String message = 'Repository error']) {
    _shouldThrow = shouldThrow;
    _errorMessage = message;
  }

  @override
  Future<SettingsEntity> getSettings() async {
    if (_shouldThrow) {
      throw Exception(_errorMessage);
    }
    return _settings ?? const SettingsEntity();
  }

  @override
  Future<void> saveSettings(SettingsEntity settings) async {
    _settings = settings;
  }
}

void main() {
  group('GetSettingsUseCase', () {
    late FakeSettingsRepository fakeSettingsRepository;
    late GetSettingsUseCase useCase;

    setUp(() {
      fakeSettingsRepository = FakeSettingsRepository();
      useCase = GetSettingsUseCase(fakeSettingsRepository);
    });

    test('should return default settings when no settings are saved', () async {
      // Act
      final result = await useCase();

      // Assert
      expect(result, isA<SettingsEntity>());
      expect(result.fontSize, equals(16.0));
      expect(result.fontlFamily, equals('Roboto'));
      expect(result.lineHeight, equals(1.5));
      expect(result.margin, equals(16.0));
      expect(result.themeMode, equals(ThemeMode.system));
      expect(result.textAlign, equals(TextAlign.justify));
      expect(result.panelWidthRatio, equals(0.5));
      expect(result.targetTranslationLanguageCode, equals('es'));
    });

    test('should return custom settings when they are saved', () async {
      // Arrange
      final customSettings = SettingsEntity(
        themeMode: ThemeMode.dark,
        fontlFamily: 'Arial',
        fontSize: 20.0,
        lineHeight: 1.8,
        margin: 24.0,
        textAlign: TextAlign.left,
        panelWidthRatio: 0.6,
        targetTranslationLanguageCode: 'fr',
      );
      fakeSettingsRepository = FakeSettingsRepository(settings: customSettings);
      useCase = GetSettingsUseCase(fakeSettingsRepository);

      // Act
      final result = await useCase();

      // Assert
      expect(result.themeMode, equals(ThemeMode.dark));
      expect(result.fontlFamily, equals('Arial'));
      expect(result.fontSize, equals(20.0));
      expect(result.lineHeight, equals(1.8));
      expect(result.margin, equals(24.0));
      expect(result.textAlign, equals(TextAlign.left));
      expect(result.panelWidthRatio, equals(0.6));
      expect(result.targetTranslationLanguageCode, equals('fr'));
    });

    test('should propagate exception when repository throws', () async {
      // Arrange
      fakeSettingsRepository.setError(true, 'Failed to load settings');
      useCase = GetSettingsUseCase(fakeSettingsRepository);

      // Act & Assert
      expect(
        () => useCase(),
        throwsA(isA<Exception>()),
      );
    });

    test('should return settings entity that is equal to default when no overrides', () async {
      // Act
      final result = await useCase();
      const defaultSettings = SettingsEntity();

      // Assert
      expect(result, equals(defaultSettings));
    });

    test('should return updated settings after saving', () async {
      // Arrange
      final updatedSettings = const SettingsEntity().copyWith(
        fontSize: 18.0,
        themeMode: ThemeMode.light,
      );
      await fakeSettingsRepository.saveSettings(updatedSettings);
      useCase = GetSettingsUseCase(fakeSettingsRepository);

      // Act
      final result = await useCase();

      // Assert
      expect(result.fontSize, equals(18.0));
      expect(result.themeMode, equals(ThemeMode.light));
      // Other fields remain default
      expect(result.fontlFamily, equals('Roboto'));
    });

    test('should return different instances on successive calls', () async {
      // Act
      final result1 = await useCase();
      final result2 = await useCase();

      // Assert - same values but should be equal (value objects)
      expect(result1, equals(result2));
    });
  });
}
