package com.dualreader.app.domain.entities

/**
 * Reading settings — persisted via DataStore.
 *
 * Lesson from Flutter: use simple key-value storage for settings,
 * not Room. Room is for structured relational data.
 */
data class ReadingSettings(
    val fontSize: Float = 16f,
    val fontFamily: String = "Default",
    val lineHeight: Float = 1.5f,
    val margins: Int = 16,
    val theme: ReaderTheme = ReaderTheme.DARK,
    val targetLanguage: String = "es",
    val translationProvider: TranslationProvider = TranslationProvider.GEMINI_FLASH,
    val brightness: Float = -1f, // -1 = system default
    val isImmersiveMode: Boolean = false,
    val screenWakeTimeoutMinutes: Int = 30,
    val sentenceCounterEnabled: Boolean = false,
    val displayMode: DisplayMode = DisplayMode.SPLIT,
    // DR-243: Whether translation appears above or below the original text
    val translationPosition: TranslationPosition = TranslationPosition.TRANSLATION_ABOVE,
    // DR-244: When enabled, TTS also reads the original text after each translation
    val ttsReadOriginal: Boolean = false,
    // DR-245: TTS speech rate (0.5 = slow, 1.0 = normal, 2.0 = fast)
    val ttsSpeechRate: Float = 1.0f,
)

enum class ReaderTheme {
    DARK,
    LIGHT,
    SEPIA,
    OCEAN,
    FOREST,
    MIDNIGHT,
    NIGHT,
}

/**
 * Translation provider priority.
 * The Worker automatically tries Gemini first, then GLM fallback.
 * These options let the user express a preference.
 */
enum class TranslationProvider(
    val displayName: String,
    val requiresNetwork: Boolean,
    val costPerBook: String,
) {
    GEMINI_FLASH("Gemini 3.5 Flash (Best Free)", true, "$0.00"),
    LLM_FREE("GLM-4.7-Flash (Free AI)", true, "$0.00"),
    LLM_CHEAP("GLM-4.7-FlashX (Fast AI)", true, "~$0.07"),
    DEVICE("On-device (ML Kit)", false, "$0.00"),
}

/**
 * How bilingual text is displayed in the reader.
 *
 * - SPLIT: Original and translation in separate panels (side-by-side or top/bottom)
 * - INTERLEAVED: Each original paragraph followed by its translation, alternating
 */
enum class DisplayMode {
    SPLIT,
    INTERLEAVED,
}

/**
 * DR-243: Where the translation appears relative to the original text.
 *
 * - TRANSLATION_ABOVE: Translation shown above the original (default — aids language learning)
 * - TRANSLATION_BELOW: Translation shown below the original (traditional reading flow)
 */
enum class TranslationPosition {
    TRANSLATION_ABOVE,
    TRANSLATION_BELOW,
}
