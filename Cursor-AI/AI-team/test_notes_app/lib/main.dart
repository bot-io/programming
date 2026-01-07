import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:simplenotes/providers/category_provider.dart';
import 'package:simplenotes/providers/note_provider.dart';
import 'package:simplenotes/providers/search_provider.dart';
import 'package:simplenotes/providers/theme_provider.dart';
import 'package:simplenotes/screens/category_management_screen.dart';
import 'package:simplenotes/screens/note_detail_screen.dart';
import 'package:simplenotes/screens/note_list_screen.dart';
import 'package:simplenotes/services/category_service.dart';
import 'package:simplenotes/services/hive_storage_service.dart';
import 'package:simplenotes/services/note_service.dart';
import 'package:simplenotes/services/search_service.dart';
import 'package:simplenotes/theme/app_theme.dart';
import 'package:simplenotes/utils/responsive.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set error handling
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
  };
  
  // Run app with error boundary
  runApp(const SimpleNotesApp());
}

/// Main app widget that handles initialization and error states
class SimpleNotesApp extends StatelessWidget {
  const SimpleNotesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppInitializationResult>(
      future: _initializeApp(),
      builder: (context, snapshot) {
        // Show loading screen during initialization
        if (snapshot.connectionState == ConnectionState.waiting) {
          return MaterialApp(
            title: 'SimpleNotes',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            home: const _LoadingScreen(),
            debugShowCheckedModeBanner: false,
          );
        }
        
        // Show error screen if initialization failed
        if (snapshot.hasError || !snapshot.hasData) {
          return MaterialApp(
            title: 'SimpleNotes',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            home: _ErrorScreen(
              error: snapshot.error?.toString() ?? 'Unknown error occurred',
              onRetry: () {
                // Restart app by rebuilding
                (context as Element).markNeedsBuild();
              },
            ),
            debugShowCheckedModeBanner: false,
          );
        }
        
        // App initialized successfully, show main app
        final result = snapshot.data!;
        return _InitializedApp(
          noteProvider: result.noteProvider,
          categoryProvider: result.categoryProvider,
          searchProvider: result.searchProvider,
          themeProvider: result.themeProvider,
        );
      },
    );
  }

  /// Initialize all app services and providers
  Future<AppInitializationResult> _initializeApp() async {
    try {
      // Initialize storage
      final storageService = HiveStorageService();
      await storageService.initialize();
      
      // Initialize services
      final noteService = NoteService(storageService);
      final categoryService = CategoryService(storageService);
      final searchService = SearchService(noteService);
      
      // Initialize providers
      final noteProvider = NoteProvider(noteService);
      final categoryProvider = CategoryProvider(categoryService);
      final searchProvider = SearchProvider(searchService);
      final themeProvider = ThemeProvider();
      await themeProvider.initialize();
      
      return AppInitializationResult(
        noteProvider: noteProvider,
        categoryProvider: categoryProvider,
        searchProvider: searchProvider,
        themeProvider: themeProvider,
      );
    } catch (e, stackTrace) {
      // Log error for debugging
      debugPrint('App initialization error: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }
}

/// Result of app initialization containing all providers
class AppInitializationResult {
  final NoteProvider noteProvider;
  final CategoryProvider categoryProvider;
  final SearchProvider searchProvider;
  final ThemeProvider themeProvider;

  AppInitializationResult({
    required this.noteProvider,
    required this.categoryProvider,
    required this.searchProvider,
    required this.themeProvider,
  });
}

/// Loading screen shown during app initialization
class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: Responsive.getPadding(context),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                strokeWidth: Responsive.isMobile(context) ? 3.0 : 4.0,
              ),
              SizedBox(height: Responsive.getSpacing(context) * 3),
              Text(
                'Initializing SimpleNotes...',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: Theme.of(context).textTheme.titleMedium?.fontSize != null
                      ? Theme.of(context).textTheme.titleMedium!.fontSize! * Responsive.getFontSizeMultiplier(context)
                      : null,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Error screen shown when app initialization fails
class _ErrorScreen extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorScreen({
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: Responsive.getPadding(context),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: Responsive.getMaxContentWidth(context),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: Responsive.getEmptyStateIconSize(context),
                    color: Theme.of(context).colorScheme.error,
                  ),
                  SizedBox(height: Responsive.getSpacing(context) * 3),
                  Text(
                    'Failed to Initialize App',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontSize: Theme.of(context).textTheme.headlineSmall?.fontSize != null
                          ? Theme.of(context).textTheme.headlineSmall!.fontSize! * Responsive.getFontSizeMultiplier(context)
                          : null,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: Responsive.getSpacing(context) * 2),
                  Text(
                    'An error occurred while initializing the app. Please try again.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: Theme.of(context).textTheme.bodyMedium?.fontSize != null
                          ? Theme.of(context).textTheme.bodyMedium!.fontSize! * Responsive.getFontSizeMultiplier(context)
                          : null,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: Responsive.getSpacing(context) * 3),
                  Container(
                    padding: Responsive.getCardPadding(context),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(Responsive.getBorderRadius(context)),
                    ),
                    child: Text(
                      error,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                        fontSize: 12 * Responsive.getFontSizeMultiplier(context),
                      ),
                    ),
                  ),
                  SizedBox(height: Responsive.getSpacing(context) * 4),
                  ElevatedButton.icon(
                    onPressed: onRetry,
                    icon: Icon(Icons.refresh, size: Responsive.getIconSize(context, baseSize: 20)),
                    label: Text(
                      'Retry',
                      style: TextStyle(
                        fontSize: Theme.of(context).textTheme.labelLarge?.fontSize != null
                            ? Theme.of(context).textTheme.labelLarge!.fontSize! * Responsive.getFontSizeMultiplier(context)
                            : null,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: Responsive.getButtonPadding(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Main app widget after successful initialization
class _InitializedApp extends StatelessWidget {
  final NoteProvider noteProvider;
  final CategoryProvider categoryProvider;
  final SearchProvider searchProvider;
  final ThemeProvider themeProvider;

  const _InitializedApp({
    required this.noteProvider,
    required this.categoryProvider,
    required this.searchProvider,
    required this.themeProvider,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: noteProvider),
        ChangeNotifierProvider.value(value: categoryProvider),
        ChangeNotifierProvider.value(value: searchProvider),
        ChangeNotifierProvider.value(value: themeProvider),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return LayoutBuilder(
            builder: (context, constraints) {
              return MaterialApp(
                title: 'SimpleNotes',
                theme: AppTheme.lightTheme,
                darkTheme: AppTheme.darkTheme,
                themeMode: themeProvider.themeMode,
                initialRoute: '/',
            routes: {
              '/': (context) => const NoteListScreen(),
              '/note-detail': (context) {
                final args = ModalRoute.of(context)?.settings.arguments;
                if (args is String) {
                  return NoteDetailScreen(noteId: args);
                }
                return const NoteDetailScreen(noteId: null);
              },
              '/category-management': (context) => const CategoryManagementScreen(),
            },
            onGenerateRoute: (settings) {
              if (settings.name == '/note-detail') {
                final args = settings.arguments;
                if (args is String) {
                  return MaterialPageRoute(
                    builder: (context) => NoteDetailScreen(noteId: args),
                    settings: settings,
                  );
                }
                return MaterialPageRoute(
                  builder: (context) => const NoteDetailScreen(noteId: null),
                  settings: settings,
                );
              }
              if (settings.name == '/category-management') {
                return MaterialPageRoute(
                  builder: (context) => const CategoryManagementScreen(),
                  settings: settings,
                );
              }
              return null;
            },
                builder: (context, child) {
                  // Add responsive layout wrapper for desktop/web
                  Widget wrappedChild = Responsive.isDesktop(context)
                      ? Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: Responsive.getMaxContentWidth(context),
                            ),
                            child: child ?? const SizedBox(),
                          ),
                        )
                      : child ?? const SizedBox();
                  
                  // Add error boundary for runtime errors
                  ErrorWidget.builder = (FlutterErrorDetails details) {
                    return Scaffold(
                      body: Center(
                        child: Padding(
                          padding: Responsive.getPadding(context),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: Responsive.getEmptyStateIconSize(context),
                                color: Colors.red,
                              ),
                              SizedBox(height: Responsive.getSpacing(context) * 2),
                              Text(
                                'An error occurred',
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontSize: Theme.of(context).textTheme.headlineSmall?.fontSize != null
                                      ? Theme.of(context).textTheme.headlineSmall!.fontSize! * Responsive.getFontSizeMultiplier(context)
                                      : null,
                                ),
                              ),
                              SizedBox(height: Responsive.getSpacing(context)),
                              Text(
                                details.exception.toString(),
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontSize: Theme.of(context).textTheme.bodySmall?.fontSize != null
                                      ? Theme.of(context).textTheme.bodySmall!.fontSize! * Responsive.getFontSizeMultiplier(context)
                                      : null,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  };
                  return wrappedChild;
                },
                debugShowCheckedModeBanner: false,
              );
            },
          );
        },
      ),
    );
  }
}
