import 'package:flutter/foundation.dart';
import 'package:dual_reader/src/data/services/enhanced_translation_cache_service.dart';

/// Service for preloading common translations on app startup.
///
/// Preloads common UI phrases and frequently used translations
/// to improve offline experience and reduce initial translation time.
class CommonPhrasePreloader {
  static const String _componentName = 'CommonPhrasePreloader';

  final EnhancedTranslationCacheService _cacheService;

  CommonPhrasePreloader(this._cacheService);

  /// Preload common phrases for a list of target languages.
  Future<void> preloadForLanguages(List<String> targetLanguages) async {
    _componentName.logInfo('Preloading common phrases for ${targetLanguages.length} languages');

    for (final lang in targetLanguages) {
      await _cacheService.preloadCommonPhrases(lang);
    }

    _componentName.logInfo('Preloading complete');
  }

  /// Preload common phrases based on user's target language.
  Future<void> preloadForUserLanguage(String userTargetLanguage) async {
    _componentName.logInfo('Preloading common phrases for user language: $userTargetLanguage');

    await _cacheService.preloadCommonPhrases(userTargetLanguage);

    _componentName.logInfo('User language preloading complete');
  }

  /// Get list of common UI phrases to preload.
  static Map<String, String> getCommonPhrases(String targetLanguage) {
    // Common UI phrases that should be pre-translated
    return {
      // Navigation
      'Settings': _translateWord('Settings', targetLanguage),
      'Library': _translateWord('Library', targetLanguage),
      'Books': _translateWord('Books', targetLanguage),
      'Search': _translateWord('Search', targetLanguage),
      'Filter': _translateWord('Filter', targetLanguage),
      'Sort': _translateWord('Sort', targetLanguage),
      'Back': _translateWord('Back', targetLanguage),
      'Next': _translateWord('Next', targetLanguage),
      'Previous': _translateWord('Previous', targetLanguage),
      'Close': _translateWord('Close', targetLanguage),
      'Open': _translateWord('Open', targetLanguage),

      // Actions
      'Save': _translateWord('Save', targetLanguage),
      'Cancel': _translateWord('Cancel', targetLanguage),
      'Delete': _translateWord('Delete', targetLanguage),
      'Edit': _translateWord('Edit', targetLanguage),
      'Copy': _translateWord('Copy', targetLanguage),
      'Share': _translateWord('Share', targetLanguage),
      'Export': _translateWord('Export', targetLanguage),
      'Import': _translateWord('Import', targetLanguage),
      'Refresh': _translateWord('Refresh', targetLanguage),
      'Clear': _translateWord('Clear', targetLanguage),

      // Reading
      'Chapter': _translateWord('Chapter', targetLanguage),
      'Page': _translateWord('Page', targetLanguage),
      'Loading': _translateWord('Loading', targetLanguage),
      'Loading...': _translateWord('Loading...', targetLanguage),
      'Please wait': _translateWord('Please wait', targetLanguage),
      'Progress': _translateWord('Progress', targetLanguage),
      'Completed': _translateWord('Completed', targetLanguage),

      // Status
      'Success': _translateWord('Success', targetLanguage),
      'Error': _translateWord('Error', targetLanguage),
      'Warning': _translateWord('Warning', targetLanguage),
      'Info': _translateWord('Info', targetLanguage),
      'Failed': _translateWord('Failed', targetLanguage),

      // Common phrases
      'Hello': _translateWord('Hello', targetLanguage),
      'Thank you': _translateWord('Thank you', targetLanguage),
      'Yes': _translateWord('Yes', targetLanguage),
      'No': _translateWord('No', targetLanguage),
      'OK': _translateWord('OK', targetLanguage),

      // Time-based
      'Today': _translateWord('Today', targetLanguage),
      'Yesterday': _translateWord('Yesterday', targetLanguage),
      'Tomorrow': _translateWord('Tomorrow', targetLanguage),

      // Numbers (frequently used)
      'One': _translateWord('One', targetLanguage),
      'Two': _translateWord('Two', targetLanguage),
      'Three': _translateWord('Three', targetLanguage),
      'First': _translateWord('First', targetLanguage),
      'Second': _translateWord('Second', targetLanguage),
      'Third': _translateWord('Third', targetLanguage),
      'Last': _translateWord('Last', targetLanguage),
    };
  }

  /// Simple word translation helper for preloading.
  /// This provides approximate translations that will be cached.
  /// Real translations will use the actual translation service.
  static String _translateWord(String word, String targetLanguage) {
    const translations = <String, Map<String, String>>{
      'Settings': {
        'es': 'Configuración',
        'fr': 'Paramètres',
        'de': 'Einstellungen',
        'it': 'Impostazioni',
        'pt': 'Configurações',
        'zh': '设置',
        'ja': '設定',
        'ko': '설정',
        'ru': 'Настройки',
        'ar': 'الإعدادات',
        'bg': 'Настройки',
      },
      'Library': {
        'es': 'Biblioteca',
        'fr': 'Bibliothèque',
        'de': 'Bibliothek',
        'it': 'Biblioteca',
        'pt': 'Biblioteca',
        'zh': '图书馆',
        'ja': 'ライブラリ',
        'ko': '도서관',
        'ru': 'Библиотека',
        'ar': 'المكتبة',
        'bg': 'Библиотека',
      },
      'Books': {
        'es': 'Libros',
        'fr': 'Livres',
        'de': 'Bücher',
        'it': 'Libri',
        'pt': 'Livros',
        'zh': '书',
        'ja': '本',
        'ko': '책',
        'ru': 'Книги',
        'ar': 'الكتب',
        'bg': 'Книги',
      },
      'Search': {
        'es': 'Buscar',
        'fr': 'Rechercher',
        'de': 'Suchen',
        'it': 'Cercare',
        'pt': 'Pesquisar',
        'zh': '搜索',
        'ja': '検索',
        'ko': '검색',
        'ru': 'Поиск',
        'ar': 'بحث',
        'bg': 'Търсене',
      },
      'Save': {
        'es': 'Guardar',
        'fr': 'Enregistrer',
        'de': 'Speichern',
        'it': 'Salva',
        'pt': 'Salvar',
        'zh': '保存',
        'ja': '保存',
        'ko': '저장',
        'ru': 'Сохранить',
        'ar': 'حفظ',
        'bg': 'Запазване',
      },
      'Cancel': {
        'es': 'Cancelar',
        'fr': 'Annuler',
        'de': 'Abbrechen',
        'it': 'Annulla',
        'pt': 'Cancelar',
        'zh': '取消',
        'ja': 'キャンセル',
        'ko': '취소',
        'ru': 'Отмена',
        'ar': 'إلغاء',
        'bg': 'Отказ',
      },
      'Delete': {
        'es': 'Eliminar',
        'fr': 'Supprimer',
        'de': 'Löschen',
        'it': 'Elimina',
        'pt': 'Excluir',
        'zh': '删除',
        'ja': '削除',
        'ko': '삭제',
        'ru': 'Удалить',
        'ar': 'حذف',
        'bg': 'Изтриване',
      },
      'Chapter': {
        'es': 'Capítulo',
        'fr': 'Chapitre',
        'de': 'Kapitel',
        'it': 'Capitolo',
        'pt': 'Capítulo',
        'zh': '章',
        'ja': '章',
        'ko': '장',
        'ru': 'Глава',
        'ar': 'فصل',
        'bg': 'Глава',
      },
      'Page': {
        'es': 'Página',
        'fr': 'Page',
        'de': 'Seite',
        'it': 'Pagina',
        'pt': 'Página',
        'zh': '页',
        'ja': 'ページ',
        'ko': '페이지',
        'ru': 'Страница',
        'ar': 'صفحة',
        'bg': 'Страница',
      },
      'Loading...': {
        'es': 'Cargando...',
        'fr': 'Chargement...',
        'de': 'Laden...',
        'it': 'Caricamento...',
        'pt': 'Carregando...',
        'zh': '加载中...',
        'ja': '読み込み中...',
        'ko': '로딩 중...',
        'ru': 'Загрузка...',
        'ar': 'جاري التحميل...',
        'bg': 'Зареждане...',
      },
      'Success': {
        'es': 'Éxito',
        'fr': 'Succès',
        'de': 'Erfolg',
        'it': 'Successo',
        'pt': 'Sucesso',
        'zh': '成功',
        'ja': '成功',
        'ko': '성공',
        'ru': 'Успех',
        'ar': 'نجح',
        'bg': 'Успех',
      },
      'Error': {
        'es': 'Error',
        'fr': 'Erreur',
        'de': 'Fehler',
        'it': 'Errore',
        'pt': 'Erro',
        'zh': '错误',
        'ja': 'エラー',
        'ko': '오류',
        'ru': 'Ошибка',
        'ar': 'خطأ',
        'bg': 'Грешка',
      },
      'Hello': {
        'es': 'Hola',
        'fr': 'Bonjour',
        'de': 'Hallo',
        'it': 'Ciao',
        'pt': 'Olá',
        'zh': '你好',
        'ja': 'こんにちは',
        'ko': '안녕하세요',
        'ru': 'Привет',
        'ar': 'مرحبا',
        'bg': 'Здравей',
      },
      'Thank you': {
        'es': 'Gracias',
        'fr': 'Merci',
        'de': 'Danke',
        'it': 'Grazie',
        'pt': 'Obrigado',
        'zh': '谢谢',
        'ja': 'ありがとう',
        'ko': '감사합니다',
        'ru': 'Спасибо',
        'ar': 'شكرا',
        'bg': 'Благодаря',
      },
      'Yes': {
        'es': 'Sí',
        'fr': 'Oui',
        'de': 'Ja',
        'it': 'Sì',
        'pt': 'Sim',
        'zh': '是',
        'ja': 'はい',
        'ko': '예',
        'ru': 'Да',
        'ar': 'نعم',
        'bg': 'Да',
      },
      'No': {
        'es': 'No',
        'fr': 'Non',
        'de': 'Nein',
        'it': 'No',
        'pt': 'Não',
        'zh': '不',
        'ja': 'いいえ',
        'ko': '아니오',
        'ru': 'Нет',
        'ar': 'لا',
        'bg': 'Не',
      },
      'OK': {
        'es': 'Aceptar',
        'fr': 'OK',
        'de': 'OK',
        'it': 'OK',
        'pt': 'OK',
        'zh': '确定',
        'ja': 'OK',
        'ko': '확인',
        'ru': 'ОК',
        'ar': 'موافق',
        'bg': 'OK',
      },
    };

    return translations[word]?[targetLanguage.toLowerCase()] ?? word;
  }
}
