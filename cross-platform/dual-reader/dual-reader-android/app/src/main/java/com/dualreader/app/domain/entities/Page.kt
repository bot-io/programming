package com.dualreader.app.domain.entities

/**
 * A single page of content — the unit of display in the reader.
 *
 * Content is plain text (HTML stripped during parsing).
 * The original HTML is NOT stored — lesson from Flutter where
 * trying to preserve HTML caused bugs with the text sanitizer.
 *
 * [translations] holds the latest translation for each language
 * the page has been translated into, e.g. {"bg": "...", "de": "..."}.
 * Switching target language shows the cached translation instantly.
 */
data class Page(
    val index: Int,
    val bookId: String,
    val chapterIndex: Int,
    val originalText: String,
    val translations: Map<String, String> = emptyMap(),
    val startCharOffset: Int = 0,
    val endCharOffset: Int = 0,
) {
    /**
     * Returns the translation for [targetLang], or null if not translated yet.
     */
    fun effectiveTranslation(targetLang: String): String? = translations[targetLang]

    /**
     * Returns a copy with [text] merged into [translations] for [lang].
     * Other language translations are preserved.
     */
    fun withTranslation(lang: String, text: String): Page =
        copy(translations = translations + (lang to text))

    /**
     * Whether this page already has a translation in [lang].
     */
    fun hasTranslation(lang: String): Boolean = lang in translations
}
