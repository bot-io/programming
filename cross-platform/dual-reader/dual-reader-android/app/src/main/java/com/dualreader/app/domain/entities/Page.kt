package com.dualreader.app.domain.entities

/**
 * A single page of content — the unit of display in the reader.
 *
 * Content is plain text (HTML stripped during parsing).
 * The original HTML is NOT stored — lesson from Flutter where
 * trying to preserve HTML caused bugs with the text sanitizer.
 */
data class Page(
    val index: Int,
    val bookId: String,
    val chapterIndex: Int,
    val originalText: String,
    val translatedText: String? = null,
    val translatedLang: String? = null,
    val startCharOffset: Int = 0,
    val endCharOffset: Int = 0,
) {
    /**
     * Returns the translated text only if it matches the requested target language.
     * Returns null if no translation exists or if the translation is in a different language.
     */
    fun effectiveTranslation(targetLang: String): String? {
        return if (translatedLang == targetLang) translatedText else null
    }
}
