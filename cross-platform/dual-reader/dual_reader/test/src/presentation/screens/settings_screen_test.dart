import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dual_reader/src/presentation/screens/settings_screen.dart';
import 'package:get_it/get_it.dart';
import 'package:dual_reader/src/domain/usecases/get_settings_usecase.dart';
import 'package:dual_reader/src/domain/usecases/update_settings_usecase.dart';
import 'package:dual_reader/src/domain/entities/settings_entity.dart';

class FakeGetSettingsUseCase implements GetSettingsUseCase {
  @override
  Future<SettingsEntity> call() async => const SettingsEntity();
  @override
  get settingsRepository => throw UnimplementedError();
}

class FakeUpdateSettingsUseCase implements UpdateSettingsUseCase {
  @override
  Future<void> call(SettingsEntity settings) async {}
  @override
  get settingsRepository => throw UnimplementedError();
}

void main() {
  final sl = GetIt.instance;

  setUp(() {
    sl.reset();
    sl.registerLazySingleton<GetSettingsUseCase>(() => FakeGetSettingsUseCase());
    sl.registerLazySingleton<UpdateSettingsUseCase>(() => FakeUpdateSettingsUseCase());
  });

  testWidgets('SettingsScreen renders all settings options', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: SettingsScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Theme Mode'), findsOneWidget);
    expect(find.text('Font Size'), findsOneWidget);
    expect(find.text('Line Height'), findsOneWidget);
    expect(find.text('Margins'), findsOneWidget);
    expect(find.text('Text Alignment'), findsOneWidget);
    expect(find.text('Target Translation Language'), findsOneWidget);
  });
}
