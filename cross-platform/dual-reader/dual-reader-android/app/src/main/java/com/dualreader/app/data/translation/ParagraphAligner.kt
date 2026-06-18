package com.dualreader.app.data.translation

import com.dualreader.app.util.AppLogger

/**
 * Aligns paragraphs between original and translated text.
 *
 * Strategy: Gemini (and most LLMs) preserve \n\n paragraph breaks through
 * translation (reinforced by the prompt rule "Maintain paragraph breaks
 * exactly as the source"). This means we can split both texts on \n\n
 * and align paragraphs by index.
 *
 * Fallback: If paragraph counts mismatch (LLM occasionally merges or splits
 * paragraphs), we use proportional position-based alignment.
 *
 * This approach avoids injecting markers into the text, which Gemini
 * strips during translation anyway.
 */
object ParagraphAligner {

    /**
     * Split text into paragraphs on \n\n boundaries.
     * Empty paragraphs are preserved to maintain alignment.
     */
    fun splitParagraphs(text: String): List<String> {
        return text.split(Regex("\n\n+"))
            .map { it.trim() }
            .filter { it.isNotEmpty() }
    }

    /**
     * Align original and translated paragraphs.
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
