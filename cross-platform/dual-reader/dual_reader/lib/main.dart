import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dual_reader/src/core/di/injection_container.dart' as di;
import 'package:dual_reader/src/presentation/screens/dual_reader_screen.dart';
import 'package:dual_reader/src/presentation/screens/library_screen.dart';
import 'package:dual_reader/src/presentation/screens/settings_screen.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:dual_reader/src/presentation/providers/settings_notifier.dart';
import 'package:google_fonts/google_fonts.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await di.init();
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
      routerConfig: _router,
    );
  }
}

final _router = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const LibraryScreen(),
      routes: [
        GoRoute(
          path: 'read/:bookId',
          builder: (context, state) => DualReaderScreen(
            bookId: state.pathParameters['bookId']!,
          ),
        ),
        GoRoute(
          path: 'settings',
          builder: (context, state) => const SettingsScreen(),
        ),
      ],
    ),
  ],
);
