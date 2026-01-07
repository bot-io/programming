abstract class TranslationService {
  Future<String> translate({
    required String text,
    required String targetLanguage,
    String? sourceLanguage,
  });

  Future<String> detectLanguage(String text);
}

