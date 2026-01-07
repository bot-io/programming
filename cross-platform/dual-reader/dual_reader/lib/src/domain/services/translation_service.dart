abstract class TranslationService {
  Future<String> translate({
    required String text,
    required String targetLanguage,
    String? sourceLanguage,
  });

  Future<String> detectLanguage(String text);

  /// Check if a language model is downloaded and ready (for client-side translation)
  /// Returns false for API-based translation services
  Future<bool> isLanguageModelReady(String languageCode) async => false;

  /// Download and prepare a language model (for client-side translation)
  /// Returns false for API-based translation services
  Future<bool> downloadLanguageModel(String languageCode, {void Function(String)? onProgress}) async => false;
}

