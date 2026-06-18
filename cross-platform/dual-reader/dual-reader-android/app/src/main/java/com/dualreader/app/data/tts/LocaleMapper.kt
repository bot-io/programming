package com.dualreader.app.data.tts

import java.util.Locale

/**
 * Maps translation language codes to Android Locale objects for TTS.
 *
 * Language codes are the short codes used throughout the app (e.g. "es", "fr", "ja").
 * Some languages need region-specific locales for best TTS results.
 */
object LocaleMapper {

    private val LOCALE_MAP = mapOf(
        // Major languages with specific locales
        "es" to Locale("es", "ES"),
        "fr" to Locale("fr", "FR"),
        "de" to Locale("de", "DE"),
        "it" to Locale("it", "IT"),
        "pt" to Locale("pt", "PT"),
        "ru" to Locale("ru", "RU"),
        "ja" to Locale("ja", "JP"),
        "ko" to Locale("ko", "KR"),
        "zh" to Locale("zh", "CN"),
        "ar" to Locale("ar", "SA"),
        "hi" to Locale("hi", "IN"),
        "tr" to Locale("tr", "TR"),
        "nl" to Locale("nl", "NL"),
        "pl" to Locale("pl", "PL"),
        "sv" to Locale("sv", "SE"),
        "uk" to Locale("uk", "UA"),
        "cs" to Locale("cs", "CZ"),
        "th" to Locale("th", "TH"),
        "vi" to Locale("vi", "VN"),
        "id" to Locale("id", "ID"),
        "el" to Locale("el", "GR"),
        "he" to Locale("he", "IL"),
        "fi" to Locale("fi", "FI"),
        "da" to Locale("da", "DK"),
        "no" to Locale("no", "NO"),
        "ro" to Locale("ro", "RO"),
        "hu" to Locale("hu", "HU"),
        "bg" to Locale("bg", "BG"),
        "hr" to Locale("hr", "HR"),
        "sk" to Locale("sk", "SK"),
        "sl" to Locale("sl", "SI"),
        "lt" to Locale("lt", "LT"),
        "lv" to Locale("lv", "LV"),
        "et" to Locale("et", "EE"),
        "ms" to Locale("ms", "MY"),
        "ta" to Locale("ta", "IN"),
        "te" to Locale("te", "IN"),
        "bn" to Locale("bn", "IN"),
        "ur" to Locale("ur", "PK"),
        "fa" to Locale("fa", "IR"),
        "sw" to Locale("sw", "KE"),
    )

    /** Also try regional variants for common multi-region languages */
    private val LOCALE_FALLBACKS = mapOf(
        "pt" to listOf(Locale("pt", "BR"), Locale("pt", "PT")),
        "zh" to listOf(Locale("zh", "CN"), Locale("zh", "TW"), Locale("zh", "HK")),
        "en" to listOf(Locale.US, Locale.UK, Locale("en", "AU"), Locale("en", "IN")),
    )

    /**
     * Map a language code to the best available Locale.
     * Falls back to the bare Locale if no specific mapping exists.
     */
    fun toLocale(langCode: String): Locale {
        return LOCALE_MAP[langCode] ?: Locale(langCode)
    }

    /**
     * Get a list of candidate locales to try for availability checking.
     * Ordered from most specific to least specific.
     */
    fun toLocaleCandidates(langCode: String): List<Locale> {
        val fallbacks = LOCALE_FALLBACKS[langCode]
        if (fallbacks != null) return fallbacks
        val mapped = LOCALE_MAP[langCode]
        if (mapped != null) return listOf(mapped)
        return listOf(Locale(langCode))
    }
}
