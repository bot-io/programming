import 'package:get_it/get_it.dart';
import 'package:dual_reader/src/domain/services/epub_parser_service.dart';
import 'package:dual_reader/src/data/services/epub_parser_service_impl.dart';
import 'package:dual_reader/src/domain/services/translation_service.dart';
import 'package:dual_reader/src/data/services/libretranslate_service_impl.dart';
import 'package:dual_reader/src/data/services/mymemory_translation_service_impl.dart';
import 'package:dual_reader/src/data/services/google_translate_service_impl.dart';
import 'package:dual_reader/src/data/services/client_side_translation_service.dart';
import 'package:dual_reader/src/data/services/mock_translation_service_impl.dart';
import 'package:dual_reader/src/data/services/translation_cache_service.dart';
import 'package:dual_reader/src/data/services/book_translation_cache_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:dual_reader/src/domain/services/pagination_service.dart';
import 'package:dual_reader/src/data/services/pagination_service_impl.dart';
import 'package:dual_reader/src/domain/entities/book_entity.dart';
import 'package:dual_reader/src/domain/repositories/book_repository.dart';
import 'package:dual_reader/src/data/repositories/book_repository_impl.dart';
import 'package:dual_reader/src/domain/usecases/import_book_usecase.dart';
import 'package:dual_reader/src/domain/usecases/get_all_books_usecase.dart';
import 'package:dual_reader/src/domain/usecases/get_book_by_id_usecase.dart';
import 'package:dual_reader/src/domain/usecases/update_book_progress_usecase.dart';
import 'package:dual_reader/src/domain/usecases/delete_book_usecase.dart';
import 'package:dual_reader/src/domain/usecases/get_settings_usecase.dart';
import 'package:dual_reader/src/domain/usecases/update_settings_usecase.dart';
import 'package:dual_reader/src/domain/entities/settings_entity.dart';
import 'package:dual_reader/src/domain/repositories/settings_repository.dart';
import 'package:dual_reader/src/data/repositories/settings_repository_impl.dart';
import 'package:dual_reader/src/core/adapters/theme_mode_adapter.dart';
import 'package:dual_reader/src/core/adapters/text_align_adapter.dart';
import 'package:flutter/foundation.dart';

final sl = GetIt.instance;

// Set which translation service to use:
// 'client' = Client-side ML (Transformers.js on web, ML Kit on mobile, offline, free)
// 'mock' = Mock translation (for testing, no API needed)
// 'google' = Google Translate API (requires API key, best quality, $20/1M chars)
// 'mymemory' = MyMemory API (free, works on web, has daily limits)
// 'libre' = LibreTranslate (may have CORS issues on web)
const String _translationService = 'client';

// Google Translate API Key - Get yours at: https://cloud.google.com/translate
// You can also set the GOOGLE_TRANSLATE_API_KEY environment variable
const String _googleTranslateApiKey = ''; // TODO: Add your API key here

Future<void> init() async {
  // External
  await Hive.initFlutter(); // Initialize Hive
  Hive.registerAdapter(BookEntityAdapter());
  Hive.registerAdapter(ThemeModeAdapter());
  Hive.registerAdapter(TextAlignAdapter());
  Hive.registerAdapter(SettingsEntityAdapter());

  // Features

  // Core
  sl.registerLazySingleton<EpubParserService>(() => EpubParserServiceImpl());
  final translationCacheService = TranslationCacheService();
  await translationCacheService.init();
  sl.registerLazySingleton<TranslationCacheService>(() => translationCacheService);
  final bookTranslationCacheService = BookTranslationCacheService();
  await bookTranslationCacheService.init();
  sl.registerLazySingleton<BookTranslationCacheService>(() => bookTranslationCacheService);
  sl.registerLazySingleton<http.Client>(() => http.Client());

  // Register translation service based on configuration
  switch (_translationService) {
    case 'client':
      debugPrint('Using CLIENT-SIDE translation service');
      debugPrint('- Web: Transformers.js (runs in browser)');
      debugPrint('- Mobile: Google ML Kit (runs on device)');
      debugPrint('- Benefits: Offline, free, no API key needed');
      sl.registerLazySingleton<TranslationService>(() => ClientSideTranslationService(sl()));
      break;
    case 'mock':
      debugPrint('Using MOCK translation service for testing');
      sl.registerLazySingleton<TranslationService>(() => MockTranslationServiceImpl(sl()));
      break;
    case 'google':
      if (_googleTranslateApiKey.isEmpty) {
        debugPrint('WARNING: Google Translate API key is empty!');
        debugPrint('Falling back to MOCK translation - Add your API key in injection_container.dart');
        debugPrint('Get your API key at: https://cloud.google.com/translate');
        sl.registerLazySingleton<TranslationService>(() => MockTranslationServiceImpl(sl()));
      } else {
        debugPrint('Using Google Translate API');
        sl.registerLazySingleton<TranslationService>(() => GoogleTranslateServiceImpl(sl(), sl(), apiKey: _googleTranslateApiKey));
      }
      break;
    case 'mymemory':
      debugPrint('Using MyMemory translation API (free, web-compatible)');
      sl.registerLazySingleton<TranslationService>(() => MyMemoryTranslationServiceImpl(sl(), sl()));
      break;
    case 'libre':
      debugPrint('Using LibreTranslate service');
      sl.registerLazySingleton<TranslationService>(() => LibreTranslateServiceImpl(sl(), sl()));
      break;
    default:
      debugPrint('Unknown translation service: $_translationService, falling back to Mock');
      sl.registerLazySingleton<TranslationService>(() => MockTranslationServiceImpl(sl()));
  }

  sl.registerLazySingleton<PaginationService>(() => PaginationServiceImpl());
  sl.registerLazySingleton<BookRepository>(() => BookRepositoryImpl());
  sl.registerLazySingleton<SettingsRepository>(() => SettingsRepositoryImpl());

  // Use cases
  sl.registerLazySingleton<ImportBookUseCase>(() => ImportBookUseCase(sl(), sl()));
  sl.registerLazySingleton<GetAllBooksUseCase>(() => GetAllBooksUseCase(sl()));
  sl.registerLazySingleton<GetBookByIdUseCase>(() => GetBookByIdUseCase(sl()));
  sl.registerLazySingleton<UpdateBookProgressUseCase>(() => UpdateBookProgressUseCase(sl()));
  sl.registerLazySingleton<DeleteBookUseCase>(() => DeleteBookUseCase(sl()));
  sl.registerLazySingleton<GetSettingsUseCase>(() => GetSettingsUseCase(sl()));
  sl.registerLazySingleton<UpdateSettingsUseCase>(() => UpdateSettingsUseCase(sl()));

  // External
}

