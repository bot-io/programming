package com.dualreader.app.data.translation

import com.dualreader.app.util.AppLogger

/**
 * Aligns paragraphs between original and translated text.
 *
 * ## Two strategies:
 *
 * 1. **Marker-based (preferred for batch translation — DR-013)**
 *    Before sending a batch of paragraphs to the translation service,
 *    [injectMarkers] prepends a numbered marker `⟦N⟧` to each paragraph.
 *    The LLM receives ALL paragraphs as a single text block (full context →
 *    better quality). After translation, [extractByMarkers] splits the
 *    output back into individual paragraphs by parsing the markers.
 *
 *    This is strictly better than translating each paragraph in isolation:
 *    the model sees surrounding context, producing more coherent translations
 *    while paragraph boundaries are preserved exactly.
 *
 * 2. **Split-based (fallback)**
 *    If markers are stripped by the LLM, we split both texts on `\n\n`
 *    and align paragraphs by index ([align]). When counts mismatch, we use
 *    proportional position-based alignment ([alignProportional]).
 *
 * Markers use Unicode mathematical white square brackets (U+27E6 / U+27E7)
 * which are virtually absent from natural prose and are structurally
 * preserved by modern LLMs.
 */
object ParagraphAligner {

    // ── Marker constants ───────────────────────────────────────────────────────

    /** Left bracket of a paragraph marker: ⟦ (U+27E6) */
    private const val MARKER_OPEN = "\u27E6"

    /** Right bracket of a paragraph marker: ⟧ (U+27E7) */
    private const val MARKER_CLOSE = "\u27E7"

    /** Regex matching paragraph markers: ⟦N⟧ where N is a positive integer. */
    private val MARKER_REGEX = Regex("""\u27E6(\d+)\u27E7""")

    // ── Marker injection / extraction ──────────────────────────────────────────

    /**
     * Inject numbered paragraph markers into a list of paragraphs.
     *
     * Each paragraph gets a `⟦N⟧` marker (1-based) prepended, then all
     * paragraphs are joined with `\n\n`. The resulting text is sent as a
     * SINGLE translation request, giving the LLM full paragraph context.
     *
     * @param paragraphs Source paragraphs to mark and join.
     * @return Marked text ready for translation, or `""` if input is empty.
     *
     * @see extractByMarkers
     */
    fun injectMarkers(paragraphs: List<String>): String {
        if (paragraphs.isEmpty()) return ""
        return buildString {
            paragraphs.forEachIndexed { i, para ->
                if (i > 0) append("\n\n")
                append(MARKER_OPEN)
                append(i + 1)
                append(MARKER_CLOSE)
                append(' ')
                append(para.trim())
            }
        }
    }

    /**
     * Extract paragraphs from marker-tagged translated text.
     *
     * Splits the translation at each `⟦N⟧` marker and returns the content
     * between consecutive markers. If the LLM preserved all markers, the
     * result has exactly [expectedCount] entries.
     *
     * @param translatedText The translation returned by the LLM (may contain markers).
     * @param expectedCount How many paragraphs were originally injected.
     * @return List of extracted paragraphs, or `null` if markers are absent
     *         or insufficient (caller should fall back to [align]).
     *
     * @see injectMarkers
     */
    fun extractByMarkers(translatedText: String, expectedCount: Int): List<String>? {
        val matches = MARKER_REGEX.findAll(translatedText).toList()
        if (matches.isEmpty()) return null

        val segments = mutableListOf<String>()
        for (i in matches.indices) {
            val contentStart = matches[i].range.last + 1
            val contentEnd = if (i + 1 < matches.size) matches[i + 1].range.first else translatedText.length
            // DR-092: Strip any residual markers the LLM may have duplicated inside content
            val content = stripMarkers(translatedText.substring(contentStart, contentEnd)).trim()
            segments.add(content)
        }

        // Filter out any empty segments (e.g. two markers with nothing between them)
        val nonEmpty = segments.filter { it.isNotEmpty() }
        if (nonEmpty.isEmpty()) return null

        // If we got more segments than expected (LLM added extras), trim to expected.
        if (nonEmpty.size > expectedCount) return nonEmpty.take(expectedCount)

        // If we got fewer than expected, markers were partially lost — signal fallback.
        if (nonEmpty.size < expectedCount) return null

        return nonEmpty
    }

    /**
     * Check whether [text] contains paragraph markers.
     */
    fun hasMarkers(text: String): Boolean = MARKER_REGEX.containsMatchIn(text)

    /**
     * Strip any paragraph markers from [text], returning clean text.
     * Also removes whitespace immediately following each marker.
     */
    fun stripMarkers(text: String): String {
        return Regex("""\u27E6\d+\u27E7\s*""").replace(text, "").trim()
    }

    // ── Split-based alignment ──────────────────────────────────────────────────

    /**
     * Split text into paragraphs on `\n\n` boundaries.
     * Empty paragraphs are filtered to maintain meaningful alignment.
     */
    fun splitParagraphs(text: String): List<String> {
        return text.split(Regex("\n\n+"))
            .map { it.trim() }
            .filter { it.isNotEmpty() }
    }

    /**
     * Align original and translated paragraphs by splitting on `\n\n`.
     *
     * This is the **fallback** strategy used when markers are absent.
     * For batch translation with full context, prefer the marker pipeline
     * ([injectMarkers] → translate → [extractByMarkers]).
     *
     * @return List of (originalParagraph, translatedParagraph) pairs.
     *         If a translation paragraph is missing, its pair gets an empty string.
     */
    fun align(
        originalText: String,
        translatedText: String,
    ): List<Pair<String, String>> {
        val origParas = splitParagraphs(originalText)
        val transParas = splitParagraphs(translatedText)

        AppLogger.d("[ParagraphAligner] Aligning: ${origParas.size} original → ${transParas.size} translated paragraphs")

        return when {
            // Empty translation: pair every original paragraph with an empty string.
            transParas.isEmpty() -> {
                origParas.map { it to "" }
            }

            // Perfect match: align 1:1 by index
            origParas.size == transParas.size -> {
                origParas.zip(transParas)
            }

            // Translation has fewer paragraphs (LLM merged some)
            transParas.size < origParas.size -> {
                alignProportional(origParas, transParas)
            }

            // Translation has more paragraphs (LLM split some)
            else -> {
                alignProportional(origParas, transParas)
            }
        }
    }

    /**
     * Proportional alignment: distribute translated paragraphs across
     * original paragraphs based on relative position.
     *
     * If original has 5 paras and translation has 3:
     *   orig[0] → trans[0]
     *   orig[1] → trans[0] or trans[1] (whichever is closer proportionally)
     *   orig[2] → trans[1]
     *   etc.
     */
    private fun alignProportional(
        origParas: List<String>,
        transParas: List<String>,
    ): List<Pair<String, String>> {
        val result = mutableListOf<Pair<String, String>>()

        for (i in origParas.indices) {
            val ratio = if (origParas.size <= 1) 0.0 else i.toDouble() / (origParas.size - 1)
            val transIdx = (ratio * (transParas.size - 1)).roundToInt()
                .coerceIn(0, transParas.lastIndex)
            result.add(origParas[i] to transParas[transIdx])
        }

        return result
    }

    private fun Double.roundToInt(): Int = kotlin.math.round(this).toInt()
}
