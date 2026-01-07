import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'services/storage_service.dart';
import 'services/ebook_parser.dart';
import 'services/translation_service.dart';
import 'services/pwa_service.dart';
import 'widgets/pwa_install_banner.dart';
import 'providers/book_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/reader_provider.dart';
import 'utils/theme.dart';
import 'utils/app_router.dart';
import 'models/book.dart';
import 'models/chapter.dart';
import 'models/reading_progress.dart';
import 'models/bookmark.dart';
import 'models/app_settings.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // Initialize PWA service on web platform
    if (kIsWeb) {
      final pwaService = PwaService();
      // Check for service worker updates on startup
      pwaService.checkForUpdates().then((updated) {
        if (updated) {
          debugPrint('[PWA] Service worker update check completed');
        }
      });
      // Listen for install prompt availability
      pwaService.installPromptAvailable.listen((available) {
        if (available) {
          debugPrint('[PWA] Install prompt is now available');
        }
      });
    }
    
    // Initialize Hive
    await Hive.initFlutter();
    
    // Register Hive adapters
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(BookAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(ChapterAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(ReadingProgressAdapter());
    }
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(BookmarkAdapter());
    }
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(AppSettingsAdapter());
    }
    
    // Initialize storage service
    final storageService = StorageService();
    await storageService.init();
    
    // Initialize services
    final ebookParser = EbookParser(storageService);
    final translationService = TranslationService();
    await translationService.initialize();
    
    // Initialize providers
    final settingsProvider = SettingsProvider(storageService);
    
    final bookProvider = BookProvider(storageService, ebookParser);
    final readerProvider = ReaderProvider(
      storageService,
      translationService,
      settingsProvider,
    );
    
    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settingsProvider),
          ChangeNotifierProvider.value(value: bookProvider),
          ChangeNotifierProvider.value(value: readerProvider),
          Provider.value(value: storageService),
        ],
        child: const DualReaderApp(),
      ),
    );
  } catch (e, stackTrace) {
    // Handle initialization errors gracefully
    debugPrint('Error initializing app: $e');
    debugPrint('Stack trace: $stackTrace');
    
    // Run app with error screen
    runApp(
      MaterialApp(
        title: 'Dual Reader 3.1',
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Failed to initialize app',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    'Error: $e',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    // Try to restart
                    main();
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DualReaderApp extends StatelessWidget {
  const DualReaderApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, child) {
        return PwaInstallBanner(
          child: MaterialApp.router(
            title: 'Dual Reader 3.1',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.getTheme(settingsProvider.settings.theme),
            routerConfig: AppRouter.router,
          ),
        );
      },
    );
  }
}
