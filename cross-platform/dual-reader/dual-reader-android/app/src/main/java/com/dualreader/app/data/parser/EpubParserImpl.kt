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
                            val text = el.text().trim()
                            if (text.isNotEmpty() && text.length > 2) {
                                paragraphs.add(ExtractedParagraph(text, spineIndex))
                            }
                        }
                    } else {
                        // Fallback: no block tags found, treat whole section as one paragraph
                        val text = doc.text().trim()
                        if (text.isNotEmpty()) {
                            paragraphs.add(ExtractedParagraph(text, spineIndex))
                        }
                    }
                } catch (_: Exception) { }
            }

            paragraphs
        }

    private fun readEpub(filePath: String): EpubBook {
        return EpubReader().readEpub(FileInputStream(filePath))
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
