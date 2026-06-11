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
