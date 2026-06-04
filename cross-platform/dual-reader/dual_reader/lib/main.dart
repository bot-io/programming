import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dual_reader/src/core/di/injection_container.dart' as di;
import 'package:dual_reader/src/core/router/app_router.dart';
import 'package:dual_reader/src/presentation/screens/settings_screen.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:dual_reader/src/presentation/providers/settings_notifier.dart';
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    return MaterialApp.router(
      title: 'Dual Reader',
      themeMode: settings.themeMode,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
        textTheme: GoogleFonts.getTextTheme(
          settings.fontlFamily,
          Theme.of(context).textTheme.apply(
            fontSizeFactor: settings.fontSize / 16.0,
          ),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple, brightness: Brightness.dark),
        useMaterial3: true,
        textTheme: GoogleFonts.getTextTheme(
          settings.fontlFamily,
          ThemeData.dark().textTheme.apply(
            fontSizeFactor: settings.fontSize / 16.0,
          ),
        ),
      ),
      routerConfig: appRouter.router,
    );
  }
}
