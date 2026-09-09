package com.dualreader.app.data.parser

/**
 * Utility for splitting text into sentences, handling abbreviations correctly.
 */
object SentenceSplitter {

    /** Minimum sentence length before we consider splitting */
    private const val MIN_SENTENCE_LENGTH = 20

    /** Known abbreviations whose trailing dot is NOT a sentence boundary. */
    private val ABBREVIATIONS = setOf(
        "dr", "mr", "mrs", "ms", "prof", "st", "jr", "sr", "vs", "no",
        "gen", "sgt", "lt", "col", "capt", "pvt", "rep", "sen", "rev",
        "hon", "pres", "gov", "inc", "ltd", "corp", "co", "etc", "ed",
        "al", "vol", "min", "max", "fig", "approx", "apt", "dept", "est",
    )

    /**
     * Split a text block into sentences.
     *
     * This function:
     * 1. Finds all sentence boundaries (period, exclamation, question mark, ellipsis)
     * 2. Filters out boundaries that follow abbreviations
     *
     * Matches the behavior of ReaderScreen.splitSentences() - no merging of short sentences.
     *
     * @param text The text to split
     * @return A list of sentences (may be empty if input is blank)
     */
    fun splitSentences(text: String): List<String> {
        val trimmed = text.trim()
        if (trimmed.isEmpty()) return emptyList()
        if (trimmed.length <= 1) return listOf(trimmed)

        // Find all sentence boundaries - using the same pattern as EpubParserImpl
        val boundaryRegex = Regex("""[.!?…]["'»)')\]]{0,3}\s+""")
        val sentences = mutableListOf<String>()
        var last = 0

        for (m in boundaryRegex.findAll(trimmed)) {
            // Check if this is a real sentence end or an abbreviation
            val punctPos = m.range.first
            if (isAbbreviation(trimmed, punctPos)) continue

            val boundary = m.range.last + 1
            val sentence = trimmed.substring(last, boundary).trim()
            if (sentence.isNotEmpty()) sentences.add(sentence)
            last = boundary
        }

        // Add the tail (last sentence without trailing space)
        val tail = trimmed.substring(last).trim()
        if (tail.isNotEmpty()) sentences.add(tail)

        // Return the split result without merging - matches ReaderScreen.splitSentences()
        return if (sentences.isEmpty() && trimmed.isNotBlank()) listOf(trimmed) else sentences
    }

    /**
     * Check whether the punctuation at [punctPos] in [text] follows an
     * abbreviation or single-letter initial.
     */
    private fun isAbbreviation(text: String, punctPos: Int): Boolean {
        if (punctPos <= 0) return false
        var i = punctPos - 1
        // Skip trailing quotes/brackets before the punctuation
        while (i >= 0 && text[i] in "\"'»\u201C\u201D\u2018\u2019)]}\u00AB") i--
        val wordEnd = i + 1
        // Collect the preceding word (letters only)
        while (i >= 0 && text[i].isLetter()) i--
        val word = text.substring(i + 1, wordEnd)
        if (word.isEmpty()) return false
        // Single uppercase Latin or Cyrillic letter = initial (A., И.)
        if (word.length == 1 && (word[0] in 'A'..'Z' || word[0] in '\u0410'..'\u042F')) return true
        return word.lowercase() in ABBREVIATIONS
    }
}