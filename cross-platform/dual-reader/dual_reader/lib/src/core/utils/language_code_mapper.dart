/// Utility class for language code mapping across different platforms.
///
/// Handles conversion between:
/// - BCP 47 language codes (standard format like 'en', 'es', 'zh-CN')
/// - ML Kit TranslateLanguage enum values (mobile)
/// - FLORES-200 codes (Transformers.js NLLB-200 on web)
///
/// References:
/// - BCP 47: https://tools.ietf.org/html/bcp47
/// - FLORES-200: https://github.com/facebookresearch/flores/blob/main/flores200/README.md
/// - ML Kit: https://developers.google.com/ml-kit/language/translation
class LanguageCodeMapper {
  // Private constructor to prevent instantiation
  LanguageCodeMapper._();

  /// FLORES-200 language codes for NLLB-200 model
  /// Maps BCP 47 codes to FLORES-200 codes
  static const Map<String, String> bcp47ToFlores200 = {
    'en': 'eng_Latn',
    'es': 'spa_Latn',
    'fr': 'fra_Latn',
    'de': 'deu_Latn',
    'it': 'ita_Latn',
    'pt': 'por_Latn',
    'zh': 'zho_Hans',
    'zh-cn': 'zho_Hans',
    'zh-tw': 'zho_Hant',
    'ja': 'jpn_Jpan',
    'ko': 'kor_Hang',
    'ru': 'rus_Cyrl',
    'bg': 'bul_Cyrl',
    'ar': 'arb_Arab',
    'hi': 'hin_Deva',
    'th': 'tha_Thai',
    'vi': 'vie_Latn',
    'tr': 'tur_Latn',
    'nl': 'nld_Latn',
    'pl': 'pol_Latn',
    'sv': 'swe_Latn',
    'da': 'dan_Latn',
    'fi': 'fin_Latn',
    'no': 'nob_Latn',
    'uk': 'ukr_Cyrl',
    'cs': 'ces_Latn',
    'el': 'ell_Grek',
    'he': 'heb_Hebr',
    'id': 'ind_Latn',
    'ms': 'zsm_Latn',
    'ro': 'ron_Latn',
    'hu': 'hun_Latn',
    'bn': 'ben_Beng',
    'ca': 'cat_Latn',
    'fa': 'pes_Arab',
    'fil': 'tgl_Latn',
    'tl': 'tgl_Latn',
    'hr': 'hrv_Latn',
    'mt': 'mlt_Latn',
    'sl': 'slv_Latn',
    'af': 'afr_Latn',
    'sq': 'sqi_Latn',
    'be': 'bel_Cyrl',
    'et': 'est_Latn',
    'ga': 'gle_Latn',
    'gl': 'glg_Latn',
    'ka': 'kat_Geor',
    'gu': 'guj_Gujr',
    'ht': 'hat_Latn',
    'is': 'isl_Latn',
    'kn': 'kan_Knda',
    'lv': 'lav_Latn',
    'lt': 'lit_Latn',
    'mk': 'mkd_Cyrl',
    'mr': 'mar_Deva',
    'sw': 'swh_Latn',
    'te': 'tel_Telu',
    'ur': 'urd_Arab',
    'cy': 'cym_Latn',
    // Additional FLORES-200 languages
    'ne': 'nep_Deva',
    'si': 'sin_Sinh',
    'am': 'amh_Ethi',
    'hy': 'hye_Armn',
    'az': 'azj_Latn',
    'eu': 'eus_Latn',
    'kk': 'kaz_Cyrl',
    'km': 'khm_Khmr',
    'lo': 'lao_Laoo',
    'mi': 'mri_Latn',
    'mn': 'khk_Cyrl',
    'my': 'mya_Mymr',
    'pa': 'pan_Guru',
    'sr': 'srp_Cyrl',
    'ta': 'tam_Taml',
    'uz': 'uzn_Latn',
  };

  /// ML Kit TranslateLanguage enum names
  /// Maps BCP 47 codes to ML Kit enum names
  static const Map<String, String> bcp47ToMlKit = {
    'zh': 'chinese',
    'zh-cn': 'chinese',
    'zh-tw': 'chinese',
    'es': 'spanish',
    'fr': 'french',
    'de': 'german',
    'it': 'italian',
    'pt': 'portuguese',
    'ru': 'russian',
    'bg': 'bulgarian',
    'ja': 'japanese',
    'ko': 'korean',
    'ar': 'arabic',
    'hi': 'hindi',
    'th': 'thai',
    'vi': 'vietnamese',
    'tr': 'turkish',
    'nl': 'dutch',
    'pl': 'polish',
    'sv': 'swedish',
    'da': 'danish',
    'fi': 'finnish',
    'no': 'norwegian',
    'uk': 'ukrainian',
    'cs': 'czech',
    'el': 'greek',
    'he': 'hebrew',
    'id': 'indonesian',
    'ms': 'malay',
    'ro': 'romanian',
    'sk': 'slovak',
    'bn': 'bengali',
    'ca': 'catalan',
    'fa': 'persian',
    'fil': 'tagalog',
    'tl': 'tagalog',
    'hr': 'croatian',
    'mt': 'maltese',
    'sl': 'slovenian',
    'en': 'english',
    'af': 'afrikaans',
    'sq': 'albanian',
    'be': 'belarusian',
    'et': 'estonian',
    'ga': 'irish',
    'gl': 'galician',
    'gu': 'gujarati',
    'ht': 'haitian',
    'hu': 'hungarian',
    'is': 'icelandic',
    'kn': 'kannada',
    'lv': 'latvian',
    'lt': 'lithuanian',
    'mk': 'macedonian',
    'mr': 'marathi',
    'sw': 'swahili',
    'ta': 'tamil',
    'te': 'telugu',
    'ur': 'urdu',
    'cy': 'welsh',
  };

  /// Normalize a BCP 47 language code to lowercase
  static String normalizeCode(String code) {
    return code.toLowerCase().trim();
  }

  /// Convert BCP 47 code to FLORES-200 code for web translation
  /// Returns the FLORES-200 code or 'eng_Latn' as default
  static String toFlores200Code(String bcp47Code) {
    final normalized = normalizeCode(bcp47Code);
    return bcp47ToFlores200[normalized] ?? 'eng_Latn';
  }

  /// Convert BCP 47 code to ML Kit enum name for mobile translation
  /// Returns the ML Kit enum name or 'english' as default
  static String toMlKitCode(String bcp47Code) {
    final normalized = normalizeCode(bcp47Code);
    return bcp47ToMlKit[normalized] ?? 'english';
  }

  /// Check if a language code is supported by FLORES-200
  static bool isSupportedByFlores200(String bcp47Code) {
    return bcp47ToFlores200.containsKey(normalizeCode(bcp47Code));
  }

  /// Check if a language code is supported by ML Kit
  static bool isSupportedByMlKit(String bcp47Code) {
    return bcp47ToMlKit.containsKey(normalizeCode(bcp47Code));
  }

  /// Get all supported BCP 47 language codes
  static List<String> getSupportedCodes() {
    final codes = <String>{};
    codes.addAll(bcp47ToFlores200.keys);
    codes.addAll(bcp47ToMlKit.keys);
    return codes.toList()..sort();
  }

  /// Get FLORES-200 code for display purposes
  static String getFlores200DisplayName(String floresCode) {
    // Extract language and script from code (e.g., 'eng_Latn' -> 'English (Latin)')
    final parts = floresCode.split('_');
    if (parts.length >= 2) {
      final lang = parts[0];
      final script = parts[1];
      return '${_capitalize(lang)} ($script)';
    }
    return floresCode;
  }

  static String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}
