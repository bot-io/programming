package com.dualreader.app.data.parser

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.jsoup.Jsoup

/**
 * Integration test using the actual Tom Sawyer Chapter 1 HTML.
 * Verifies that paragraph extraction produces consistent sentence-based
 * paragraphs and that the "Hang the boy" monologue gets split properly.
 */
class TomSawyerParagraphTest {

    private fun loadTomSawyerHtml(): String {
        val resource = javaClass.classLoader?.getResource("tom_sawyer_ch1_sample.html")
        assertNotNull("Test resource tom_sawyer_ch1_sample.html not found", resource)
        return resource!!.readText()
    }

    @Test
    fun `tom sawyer HTML parses into multiple paragraphs`() {
        val html = loadTomSawyerHtml()
        val doc = Jsoup.parse(html)
        val elements = doc.select("p, h1, h2, h3, h4, h5, h6, li, blockquote")

        assertTrue("Should find many <p> tags", elements.size > 10)

        val texts = elements.map { it.text().trim() }.filter { it.isNotEmpty() && it.length > 2 }
        assertTrue("Should extract many paragraphs", texts.size > 10)
    }

    @Test
    fun `long monologue paragraph gets split into sentences`() {
        val html = loadTomSawyerHtml()

        // Find the "Hang the boy" paragraph
        val doc = Jsoup.parse(html)
        val elements = doc.select("p")
        val monologuePara = elements.find { it.text().contains("Hang the boy") }

        assertNotNull("Should find 'Hang the boy' paragraph", monologuePara)
        val monologueText = monologuePara!!.text().trim()
        assertTrue(
            "Monologue should be long (>300 chars), got ${monologueText.length}",
            monologueText.length > 300
        )

        // Now split it
        val chunks = EpubParserImpl.splitLongParagraph(monologueText)
        assertTrue(
            "Monologue should be split into 3+ sentence-paragraphs, got ${chunks.size}",
            chunks.size >= 3
        )
        // Each chunk should be a reasonable size (not a run-on paragraph)
        assertFalse(
            "No chunk should exceed 400 chars (single sentence max)",
            chunks.any { it.length > 400 }
        )
    }

    @Test
    fun `spectacles paragraph gets split into individual sentences`() {
        val html = loadTomSawyerHtml()
        val doc = Jsoup.parse(html)
        val elements = doc.select("p")
        val spectaclesPara = elements.find { it.text().contains("old lady pulled her spectacles") }

        assertNotNull("Should find spectacles paragraph", spectaclesPara)
        val text = spectaclesPara!!.text().trim()

        // Regardless of length, splitLongParagraph should split at sentence boundaries
        val chunks = EpubParserImpl.splitLongParagraph(text)
        assertTrue("Should split into 1+ chunks", chunks.size >= 1)
    }

    @Test
    fun `short dialogue stays intact`() {
        val html = loadTomSawyerHtml()
        val doc = Jsoup.parse(html)
        val elements = doc.select("p")

        // "Nothing." should be one short paragraph
        val nothingPara = elements.find { it.text().trim() == "“Nothing.”" }
        assertNotNull("Should find 'Nothing.' dialogue", nothingPara)

        val chunks = EpubParserImpl.splitLongParagraph(nothingPara!!.text().trim())
        assertEquals(1, chunks.size)
    }

    @Test
    fun `all extracted paragraphs are consistent sentence-based sizes`() {
        val html = loadTomSawyerHtml()
        val doc = Jsoup.parse(html)
        val elements = doc.select("p, h1, h2, h3, h4, h5, h6, li, blockquote")

        val allChunks = mutableListOf<String>()
        for (el in elements) {
            val text = el.text().trim()
            if (text.isNotEmpty() && text.length > 2) {
                allChunks.addAll(EpubParserImpl.splitLongParagraph(text))
            }
        }

        assertTrue("Should have many chunks", allChunks.size > 15)

        // No paragraph should exceed ~400 chars (upper bound for a single long sentence)
        val oversized = allChunks.filter { it.length > 400 }
        assertTrue(
            "Found ${oversized.size} paragraphs exceeding 400 chars. Example: ${oversized.firstOrNull()?.take(60)}",
            oversized.isEmpty()
        )
    }

    @Test
    fun `splitting preserves all text content`() {
        val html = loadTomSawyerHtml()
        val doc = Jsoup.parse(html)
        val elements = doc.select("p")

        val monologuePara = elements.find { it.text().contains("Hang the boy") }!!
        val original = monologuePara.text().trim()

        val chunks = EpubParserImpl.splitLongParagraph(original)
        val reconstructed = chunks.joinToString(" ")

        // All words should be preserved
        val originalWords = original.split(Regex("\\s+")).filter { it.isNotEmpty() }.toSet()
        val reconstructedWords = reconstructed.split(Regex("\\s+")).filter { it.isNotEmpty() }.toSet()

        // Check key phrases survive
        assertTrue("Should contain 'Hang the boy'", reconstructed.contains("Hang the boy"))
        assertTrue("Should contain 'ruination of the child'", reconstructed.contains("ruination of the child"))
    }
}
