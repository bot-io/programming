package com.dualreader.app.data.parser

import com.dualreader.app.domain.entities.BookChapter
import com.dualreader.app.domain.services.EpubParserService
import com.dualreader.app.domain.services.ExtractedParagraph
import com.dualreader.app.domain.services.ParsedEpub
import io.documentnode.epub4j.domain.Book as EpubBook
import io.documentnode.epub4j.epub.EpubReader
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.jsoup.Jsoup
import java.io.File
import java.io.FileInputStream

import javax.inject.Inject

class EpubParserImpl @Inject constructor() : EpubParserService {

    override suspend fun parseMetadata(filePath: String): ParsedEpub =
        withContext(Dispatchers.IO) {
            val epubBook = readEpub(filePath)
            val metadata = epubBook.metadata

            val title = metadata.titles.firstOrNull() ?: "Unknown"
            val author = metadata.authors.joinToString(", ") { it.toString() }.ifBlank { "Unknown" }
            val language = metadata.language
            val publisher = metadata.publishers.firstOrNull()
            val description = metadata.descriptions.firstOrNull()

            val coverImageBytes = try { epubBook.coverImage?.data } catch (_: Exception) { null }

            val chapters = buildChapterList(epubBook)

            ParsedEpub(
                title = title,
                author = author,
                language = language,
                publisher = publisher,
                description = description,
                chapters = chapters,
                coverImageBytes = coverImageBytes,
            )
        }

    override suspend fun extractChapterText(filePath: String, chapterIndex: Int): String =
        withContext(Dispatchers.IO) {
            val epubBook = readEpub(filePath)
            val contents = epubBook.contents
            if (chapterIndex < 0 || chapterIndex >= contents.size) return@withContext ""
            val resource = contents[chapterIndex]
            val html = resource.data?.let { String(it, Charsets.UTF_8) } ?: return@withContext ""
            Jsoup.parse(html).text()
        }

    override suspend fun extractCoverImage(filePath: String): ByteArray? =
        withContext(Dispatchers.IO) {
            try { readEpub(filePath).coverImage?.data } catch (_: Exception) { null }
        }

    override suspend fun extractFullText(filePath: String): String =
        withContext(Dispatchers.IO) {
            extractParagraphs(filePath).joinToString("\n\n") { it.text }
        }

    override suspend fun extractParagraphs(filePath: String): List<ExtractedParagraph> =
        withContext(Dispatchers.IO) {
            val epubBook = readEpub(filePath)
            val paragraphs = mutableListOf<ExtractedParagraph>()

            epubBook.contents.forEachIndexed { spineIndex, resource ->
                try {
                    val html = resource.data?.let { String(it, Charsets.UTF_8) } ?: return@forEachIndexed
                    val doc = Jsoup.parse(html)

                    // Select paragraph-like block elements
                    val elements = doc.select("p, h1, h2, h3, h4, h5, h6, li, blockquote")

                    if (elements.isNotEmpty()) {
                        for (el in elements) {
                            // Handle <br> tags: el.text() flattens <br> into spaces,
                            // losing paragraph boundaries within a single <p> tag.
                            val innerHtml = el.html()
                            val hasBr = innerHtml.contains(Regex("(?i)<br"))

                            val segments: List<String> = if (hasBr) {
                                innerHtml
                                    .replace(Regex("(?i)<br\\s*/?>"), " __BR__ ")
                                    .replace(Regex("<[^>]+>"), "")
                                    .replace("&amp;", "&").replace("&lt;", "<")
                                    .replace("&gt;", ">").replace("&quot;", "\"")
                                    .replace("&#39;", "'").replace("&nbsp;", " ")
                                    .split("__BR__")
                                    .map { it.trim() }
                                    .filter { it.isNotBlank() }
                            } else {
                                val text = el.text().trim()
                                if (text.isNotBlank()) listOf(text) else emptyList()
                            }

                            for (seg in segments) {
                                // Filter out EPUB metadata that leaks into content
                                if (isMetadataParagraph(seg)) continue

                                // Split long paragraphs at sentence boundaries for better
                                // readability and translation. Target ~200-300 chars per chunk.
                                val subChunks = splitLongParagraph(seg)
                                for (chunk in subChunks) {
                                    paragraphs.add(ExtractedParagraph(chunk, spineIndex))
                                }
                            }
                        }
                    } else {
                        val text = doc.text().trim()
                        if (text.isNotEmpty()) {
                            for (chunk in splitLongParagraph(text)) {
                                paragraphs.add(ExtractedParagraph(chunk, spineIndex))
                            }
                        }
                    }
                } catch (_: Exception) { }
            }

            paragraphs
        }

    companion object {
        /**
         * Minimum chars for a sentence to stand alone as a paragraph.
         * Shorter sentences (e.g. "Yes.", "He nodded.") get merged with
         * the next sentence to avoid tiny fragmented paragraphs.
         */
        private const val MIN_SENTENCE_LENGTH = 40

        /**
         * Split a paragraph into sentence-based chunks for consistent,
         * readable paragraphs.
         *
         * Each sentence becomes its own paragraph unless it's very short
         * (< [MIN_SENTENCE_LENGTH] chars), in which case it's merged with
         * the next sentence. This produces consistent 1-2 sentence paragraphs
         * instead of the previous behavior where paragraphs under 300 chars
         * were never split.
         *
         * Handles abbreviations (Dr., Mr., etc.) and single-letter initials.
         */
        fun splitLongParagraph(text: String): List<String> {
            val trimmed = text.trim()
            if (trimmed.isEmpty()) return emptyList()

            // Find all sentence boundaries
            val boundaryRegex = Regex("""[.!?…]["'"»'')\]]{0,3}\s+""")
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

            if (sentences.size <= 1) return listOf(trimmed)

            // Merge short sentences with the next one
            val merged = mutableListOf<String>()
            val current = StringBuilder()

            for (sentence in sentences) {
                if (current.isNotEmpty()) {
                    // If current is still short, keep accumulating
                    if (current.length < MIN_SENTENCE_LENGTH) {
                        current.append(' ').append(sentence)
                        continue
                    }
                    // Current is long enough — flush it
                    merged.add(current.toString().trim())
                    current.clear()
                }

                if (sentence.length < MIN_SENTENCE_LENGTH) {
                    current.append(sentence)
                } else {
                    merged.add(sentence)
                }
            }

            if (current.isNotEmpty()) {
                merged.add(current.toString().trim())
            }

            return merged.ifEmpty { listOf(trimmed) }
        }

        /** Known abbreviations whose trailing dot is NOT a sentence boundary. */
        private val ABBREVIATIONS = setOf(
            "dr", "mr", "mrs", "ms", "prof", "st", "jr", "sr", "vs", "no",
            "gen", "sgt", "lt", "col", "capt", "pvt", "rep", "sen", "rev",
            "hon", "pres", "gov", "inc", "ltd", "corp", "co", "etc", "ed",
            "al", "vol", "min", "max", "fig", "approx", "apt", "dept", "est",
        )

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

    /**
     * Detect EPUB metadata that leaked into the content HTML.
     * Common patterns: "Language: English", "Title: ...", "Author: ...",
     * "Publisher: ...", "ISBN: ...", etc.
     */
    private fun isMetadataParagraph(text: String): Boolean {
        val trimmed = text.trim()
        if (trimmed.length > 100) return false // Real content can be long
        // Match "Word: value" patterns typical of metadata
        val metadataPattern = Regex(
            """^(Language|Title|Author|Publisher|ISBN|Subject|Description|Date|Copyright|Source|Format|Identifier|Creator|Contributor|Relation|Coverage|Rights|Version)\s*:\s*.+""",
            RegexOption.IGNORE_CASE
        )
        return metadataPattern.matches(trimmed)
    }

    private fun readEpub(filePath: String): EpubBook {
        require(filePath.isNotBlank()) { "filePath must not be blank" }
        val file = File(filePath)
        require(file.exists()) { "EPUB file does not exist: $filePath" }
        return FileInputStream(file).use { EpubReader().readEpub(it) }
    }

    private fun buildChapterList(epubBook: EpubBook): List<BookChapter> {
        val tocTitles = mutableMapOf<String, String>()
        collectTocTitles(epubBook.tableOfContents.tocReferences, tocTitles)

        return epubBook.contents.mapIndexed { index, resource ->
            val title = tocTitles[resource.id]
                ?: resource.title
                ?: "Chapter ${index + 1}"
            BookChapter(
                index = index,
                title = title,
            )
        }
    }

    private fun collectTocTitles(
        references: List<io.documentnode.epub4j.domain.TOCReference>,
        map: MutableMap<String, String>,
        level: Int = 0,
    ) {
        for (ref in references) {
            ref.resourceId?.let { id -> ref.title?.let { t -> map[id] = t } }
            if (ref.children.isNotEmpty()) {
                collectTocTitles(ref.children, map, level + 1)
            }
        }
    }
}
