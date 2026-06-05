import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dual_reader/src/core/di/injection_container.dart' as di;
import 'package:dual_reader/src/core/router/app_router.dart';
import 'package:dual_reader/src/presentation/screens/settings_screen.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:dual_reader/src/presentation/providers/settings_notifier.dart';
import 'package:dual_reader/src/domain/entities/settings_entity.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dual_reader/src/core/utils/logging_service.dart';
import 'package:dual_reader/src/data/services/language_model_downloader.dart';
import 'package:dual_reader/src/data/services/common_phrase_preloader.dart';
import 'package:dual_reader/src/data/services/enhanced_translation_cache_service.dart';
import 'package:dual_reader/src/domain/services/translation_service.dart';
import 'package:dual_reader/src/core/platform/platform_features.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive FIRST before LoggingService (which depends on Hive)
  await Hive.initFlutter();

  // Now initialize logging
  await LoggingService.instance.init();

  await di.init();

  // Initialize router
  initAppRouter();

  // Initialize enhanced translation cache
  final cacheService = EnhancedTranslationCacheService.instance;
  await cacheService.init();

  // Background Spanish model download on platforms that support it
  // This improves UX by pre-loading the most common translation model
  if (platformFeatures.supportsModelDownload) {
    final downloader = LanguageModelDownloader.getInstance(di.sl<TranslationService>());
    // Start download in background without blocking app startup
    downloader.downloadSpanishModelInBackground().catchError((e) {
      LoggingService.warning('Main', 'Failed to start background Spanish model download');
    });
  }

  // Preload common phrases for user's target language
  // This runs in background and caches common translations
  final preloader = CommonPhrasePreloader(cacheService);

  // Get user's target language from settings (default to Spanish)
  // Note: We'll preload after app starts to not block startup
  Future.delayed(const Duration(milliseconds: 500), () async {
    try {
      // For now, preload common phrases for Spanish as default
      // In production, this would use the user's actual target language
      await preloader.preloadForUserLanguage('es');
      LoggingService.info('Main', 'Common phrases preloaded for Spanish');
    } catch (e) {
      LoggingService.warning('Main', 'Failed to preload common phrases');
    }
  });

  // Add global error handler to catch crashes
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    // Log to our logging service
    LoggingService.error('FlutterError', details.exception.toString(), error: details.exception, stackTrace: details.stack);
  };

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  /// Build ThemeData based on settings preset
  ThemeData _buildTheme(SettingsEntity settings, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final preset = settings.preset;

    ColorScheme colorScheme;
    switch (preset) {
      case ThemePreset.sepia:
        colorScheme = isDark
            ? const ColorScheme.dark(
                surface: Color(0xFF2C2417),
                onSurface: Color(0xFFE8D5B7),
                primary: Color(0xFF8B6914),
                onPrimary: Color(0xFFFFFFFF),
                secondary: Color(0xFFA0793C),
                background: Color(0xFF1E1810),
              )
            : const ColorScheme.light(
                surface: Color(0xFFF4E8D1),
                onSurface: Color(0xFF3E2C1C),
                primary: Color(0xFF8B6914),
                onPrimary: Color(0xFFFFFFFF),
                secondary: Color(0xFFA0793C),
                background: Color(0xFFF9F0E0),
              );
        break;
      case ThemePreset.ocean:
        colorScheme = isDark
            ? const ColorScheme.dark(
                surface: Color(0xFF0D1B2A),
                onSurface: Color(0xFFE0E8F0),
                primary: Color(0xFF1B9AAA),
                secondary: Color(0xFF06D6A0),
              )
            : const ColorScheme.light(
                surface: Color(0xFFE8F4F8),
                onSurface: Color(0xFF0D1B2A),
                primary: Color(0xFF1B9AAA),
                secondary: Color(0xFF06D6A0),
              );
        break;
      case ThemePreset.forest:
        colorScheme = isDark
            ? const ColorScheme.dark(
                surface: Color(0xFF1A2E1A),
                onSurface: Color(0xFFD4E8D4),
                primary: Color(0xFF2E7D32),
                secondary: Color(0xFF66BB6A),
              )
            : const ColorScheme.light(
                surface: Color(0xFFF0F5F0),
                onSurface: Color(0xFF1A2E1A),
                primary: Color(0xFF2E7D32),
                secondary: Color(0xFF66BB6A),
              );
        break;
      case ThemePreset.midnight:
        colorScheme = const ColorScheme.dark(
          surface: Color(0xFF0A0A1A),
          onSurface: Color(0xFFD0D0E0),
          primary: Color(0xFF7C4DFF),
          secondary: Color(0xFF536DFE),
        );
        break;
      case ThemePreset.standard:
        colorScheme = isDark
            ? ColorScheme.fromSeed(seedColor: Colors.deepPurple, brightness: brightness)
            : ColorScheme.fromSeed(seedColor: Colors.deepPurple);
        break;
    }

    final baseTextTheme = isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme;

    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      brightness: brightness,
      textTheme: GoogleFonts.getTextTheme(
        settings.fontlFamily,
        baseTextTheme.apply(
          fontSizeFactor: settings.fontSize / 16.0,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    return MaterialApp.router(
      title: 'Dual Reader',
      themeMode: settings.themeMode,
      theme: _buildTheme(settings, Brightness.light),
      darkTheme: _buildTheme(settings, Brightness.dark),
      routerConfig: appRouter.router,
    );
  }
}
