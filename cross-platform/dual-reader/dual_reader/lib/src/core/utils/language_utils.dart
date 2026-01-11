/// Utility class for language-related operations.
///
/// Provides mappings between language codes and display names,
/// and helper methods for language-specific UI text.
class LanguageUtils {
  // Private constructor to prevent instantiation
  LanguageUtils._();

  /// Mapping of ISO 639-1 language codes to display names.
  static const Map<String, String> languageNames = {
    'en': 'English',
    'es': 'Spanish',
    'bg': 'Bulgarian',
    'fr': 'French',
    'de': 'German',
    'it': 'Italian',
    'pt': 'Portuguese',
    'zh': 'Chinese',
    'ja': 'Japanese',
    'ko': 'Korean',
    'ru': 'Russian',
    'ar': 'Arabic',
    'nl': 'Dutch',
    'pl': 'Polish',
    'tr': 'Turkish',
    'sv': 'Swedish',
    'da': 'Danish',
    'no': 'Norwegian',
    'fi': 'Finnish',
    'cs': 'Czech',
    'el': 'Greek',
    'he': 'Hebrew',
    'th': 'Thai',
    'vi': 'Vietnamese',
    'id': 'Indonesian',
    'uk': 'Ukrainian',
    'ro': 'Romanian',
    'hu': 'Hungarian',
  };

  /// Gets the display name for a language code.
  ///
  /// If the language code is not found in the mapping, returns the
  /// uppercase version of the code as a fallback.
  ///
  /// Example:
  /// ```dart
  /// LanguageUtils.getLanguageName('es') // Returns 'Spanish'
  /// LanguageUtils.getLanguageName('xx') // Returns 'XX'
  /// ```
  static String getLanguageName(String code) {
    return languageNames[code] ?? code.toUpperCase();
  }

  /// Checks if a language code is supported.
  ///
  /// Returns true if the language code exists in the [languageNames] mapping.
  static bool isSupportedLanguage(String code) {
    return languageNames.containsKey(code);
  }

  /// Gets all supported language codes.
  ///
  /// Returns a list of all ISO 639-1 language codes that have
  /// display name mappings.
  static List<String> getSupportedLanguageCodes() {
    return languageNames.keys.toList()..sort();
  }

  /// Gets all supported languages as a map of code to display name.
  ///
  /// Returns a sorted map (by code) of all supported languages.
  static Map<String, String> getSupportedLanguages() {
    final sortedKeys = languageNames.keys.toList()..sort();
    return {for (var key in sortedKeys) key: languageNames[key]!};
  }
}
