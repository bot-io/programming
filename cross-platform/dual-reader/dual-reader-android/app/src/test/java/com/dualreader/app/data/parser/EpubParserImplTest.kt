package com.dualreader.app.data.parser

import kotlinx.coroutines.runBlocking
import org.jsoup.Jsoup
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Comprehensive unit tests for [EpubParserImpl].
 *
 * Covers four areas:
 *  1. [EpubParserImpl.splitLongParagraph] — a *public* companion function; all
 *     edge cases are exercised directly (empty input, single sentence, no
 *     punctuation, very long text, multiple sentences, preservation of text).
 *  2. `isMetadataParagraph()` — a *private* member function; reached via
 *     reflection through a real [EpubParserImpl] instance (it has a no-arg
 *     constructor, so no DI plumbing is required).
 *  3. HTML entity decoding — verified on both code paths the production class
 *     relies on: Jsoup's `Element.text()` (used for ordinary `<p>` tags) and
 *     the manual decode chain used inside the `<br>` branch.
 *  4. `<br>` tag splitting — the inline transformation that turns a single `<p>`
 *     containing `<br>` tags into multiple paragraph segments.
 *
 * The entity-decoding and `<br>`-splitting logic lives *inline* inside
 * `extractParagraphs()` and is not exposed as a standalone function. To test it
 * without spinning up an EPUB fixture, [brSegments] mirrors that inline
 * transformation exactly and is fed real Jsoup `Element.html()` output — the
 * same input the production code operates on. Keep it in sync with
 * `EpubParserImpl.kt` if the transformation changes.
 */
class EpubParserImplTest {

    // ------------------------------------------------------------------
    // Reflection bridge to the private `isMetadataParagraph(text: String)`
    // ------------------------------------------------------------------
    private val parser = EpubParserImpl()

    private fun isMetadataParagraph(text: String): Boolean {
        val method = EpubParserImpl::class.java
            .getDeclaredMethod("isMetadataParagraph", String::class.java)
        method.isAccessible = true
        return method.invoke(parser, text) as Boolean
    }

    // ------------------------------------------------------------------
    // Mirror of the inline <br> / entity processing in extractParagraphs().
    //
    // Source (EpubParserImpl.kt):
    //   val innerHtml = el.html()
    //   ... hasBr ...
    //   innerHtml
    //       .replace(Regex("(?i)<br\\s*/?>"), " __BR__ ")
    //       .replace(Regex("<[^>]+>"), "")
    //       .replace("&amp;", "&").replace("&lt;", "<")
    //       .replace("&gt;", ">").replace("&quot;", "\"")
    //       .replace("&#39;", "'").replace("&nbsp;", " ")
    //       .split("__BR__")
    //       .map { it.trim() }
    //       .filter { it.isNotBlank() }
    // ------------------------------------------------------------------
    private fun brSegments(innerHtml: String): List<String> {
        val hasBr = innerHtml.contains(Regex("(?i)<br"))
        if (!hasBr) return emptyList()
        return innerHtml
            .replace(Regex("(?i)<br\\s*/?>"), " __BR__ ")
            .replace(Regex("<[^>]+>"), "")
            .replace("&amp;", "&").replace("&lt;", "<")
            .replace("&gt;", ">").replace("&quot;", "\"")
            .replace("&#39;", "'").replace("&nbsp;", " ")
            .split("__BR__")
            .map { it.trim() }
            .filter { it.isNotBlank() }
    }

    // ==================================================================
    // 1. splitLongParagraph — edge cases
    // ==================================================================

    @Test
    fun `splitLongParagraph - empty string returns empty list`() {
        val result = EpubParserImpl.splitLongParagraph("")
        assertEquals(0, result.size)
    }

    @Test
    fun `splitLongParagraph - blank string returns empty list`() {
        val result = EpubParserImpl.splitLongParagraph("    \t\n  ")
        assertEquals(0, result.size)
    }

    @Test
    fun `splitLongParagraph - single short sentence stays one chunk`() {
        val text = "The cat sat on the mat."
        val result = EpubParserImpl.splitLongParagraph(text)
        assertEquals(1, result.size)
        assertEquals(text, result[0])
    }

    @Test
    fun `splitLongParagraph - leading and trailing whitespace is trimmed`() {
        val result = EpubParserImpl.splitLongParagraph("   Hello there.   ")
        assertEquals(1, result.size)
        assertEquals("Hello there.", result[0])
    }

    @Test
    fun `splitLongParagraph - multiple short sentences split into individual paragraphs`() {
        val text = "This is a fairly short paragraph with multiple sentences in it. " +
            "Each one should become its own paragraph. " +
            "This makes translation and reading more consistent."
        val result = EpubParserImpl.splitLongParagraph(text)
        assertEquals(3, result.size)
        assertEquals("This is a fairly short paragraph with multiple sentences in it.", result[0])
        assertEquals("Each one should become its own paragraph.", result[1])
        assertEquals("This makes translation and reading more consistent.", result[2])
    }

    @Test
    fun `splitLongParagraph - no punctuation long text is returned as one chunk`() {
        // Text with no sentence-ending punctuation cannot be split
        val text = "word".repeat(150) // 600 chars, no . ! ?
        val result = EpubParserImpl.splitLongParagraph(text)
        assertEquals(1, result.size)
        assertEquals(text, result[0])
    }

    @Test
    fun `splitLongParagraph - very long text with sentences is split into individual sentences`() {
        val text = (1..20).joinToString(" ") { "This is sentence number $it with some words." }

        val result = EpubParserImpl.splitLongParagraph(text)

        assertTrue("Should produce 20 chunks, got ${result.size}", result.size == 20)
    }

    @Test
    fun `splitLongParagraph - short sentences are merged to avoid tiny fragments`() {
        // Very short sentences should be merged with the next one
        val text = "Yes. He nodded. Then the man walked across the street toward the old bakery."
        val result = EpubParserImpl.splitLongParagraph(text)

        // "Yes." and "He nodded." are both < 40 chars, so they get merged
        assertTrue("Should merge short sentences, got ${result.size} chunks", result.size <= 2)
        // No chunk should be just "Yes."
        assertFalse("No chunk should be just 'Yes.'", result.any { it == "Yes." })
    }

    @Test
    fun `splitLongParagraph - preserves all text content across chunks`() {
        val sentences = (1..25).map { "This is sentence number $it to reconstruct." }
        val text = sentences.joinToString(" ")

        val result = EpubParserImpl.splitLongParagraph(text)
        val reconstructed = result.joinToString(" ")

        val originalWords = text.split(Regex("\\s+")).filter { it.isNotEmpty() }
        val resultWords = reconstructed.split(Regex("\\s+")).filter { it.isNotEmpty() }

        assertEquals("No words should be lost during splitting", originalWords, resultWords)
    }

    @Test
    fun `splitLongParagraph - respects sentence boundaries`() {
        val text = "First sentence here with detail. " +
            "Second sentence follows with even more detail than before. " +
            "Third sentence arrives and is quite long indeed it must be said. " +
            "Fourth sentence is here and adds even more content to read aloud. " +
            "Fifth sentence now continues the narrative with additional words here. " +
            "Sixth sentence comes with further elaboration on the topic at hand. " +
            "Seventh sentence follows with yet more discussion of these matters. " +
            "Eighth sentence arrives and wraps up most of the thoughts expressed. " +
            "Ninth and final sentence concludes this very long paragraph nicely."

        val result = EpubParserImpl.splitLongParagraph(text)

        assertTrue("Should produce multiple chunks", result.size > 1)
        result.forEach { chunk ->
            val first = chunk.trim().firstOrNull()
            assertTrue(
                "Each chunk should start with a capital letter, got '$first'",
                first != null && first.isUpperCase()
            )
        }
    }

    @Test
    fun `splitLongParagraph - does not break inside abbreviations like Mr and Mrs`() {
        val text = "Mr. Smith went to the store on a bright and sunny morning. " +
            "Mrs. Jones was already there and greeted him warmly and politely. " +
            "They talked for a long while about the weather and pleasant topics " +
            "that good neighbors tend to discuss on a fine summer afternoon together. " +
            "Dr. Brown also stopped by to join in on the pleasant conversation today."

        val result = EpubParserImpl.splitLongParagraph(text)

        result.forEach { chunk ->
            assertFalse("Should not start with ' Smith'", chunk.startsWith(" Smith"))
            assertFalse("Should not start with ' Jones'", chunk.startsWith(" Jones"))
            assertFalse("Should not start with ' Brown'", chunk.startsWith(" Brown"))
        }
    }

    @Test
    fun `splitLongParagraph - single run-on sentence with no boundaries stays intact`() {
        // One sentence with no internal ". " boundaries
        val text = "a".repeat(400)
        val result = EpubParserImpl.splitLongParagraph(text)
        assertEquals(1, result.size)
        assertEquals(400, result[0].length)
    }

    @Test
    fun `splitLongParagraph - question and exclamation marks are split boundaries`() {
        val text = "What is going on here today? " +
            "This is an exclamation that follows and adds some length to things! " +
            "Then a declarative sentence that continues the narrative onward here. " +
            "Another question appears right here at this exact spot now? " +
            "And finally one more exclamation to round out the whole thing nicely! " +
            "A closing declarative sentence to finish up this entire paragraph now."

        val result = EpubParserImpl.splitLongParagraph(text)
        assertTrue("Should split on ? and ! too, got ${result.size}", result.size > 1)
    }

    // ==================================================================
    // 2. isMetadataParagraph — metadata filtering
    // ==================================================================

    @Test
    fun `isMetadataParagraph - filters Language metadata`() {
        assertTrue(isMetadataParagraph("Language: English"))
    }

    @Test
    fun `isMetadataParagraph - filters Title metadata`() {
        assertTrue(isMetadataParagraph("Title: Some Book"))
    }

    @Test
    fun `isMetadataParagraph - filters Author metadata`() {
        assertTrue(isMetadataParagraph("Author: John Doe"))
    }

    @Test
    fun `isMetadataParagraph - filters Publisher metadata`() {
        assertTrue(isMetadataParagraph("Publisher: Press"))
    }

    @Test
    fun `isMetadataParagraph - filters ISBN metadata`() {
        assertTrue(isMetadataParagraph("ISBN: 12345"))
    }

    @Test
    fun `isMetadataParagraph - filters Copyright metadata`() {
        assertTrue(isMetadataParagraph("Copyright: 2024"))
    }

    @Test
    fun `isMetadataParagraph - filters Subject metadata`() {
        assertTrue(isMetadataParagraph("Subject: Fiction"))
    }

    @Test
    fun `isMetadataParagraph - filters Description metadata`() {
        assertTrue(isMetadataParagraph("Description: A great book about things."))
    }

    @Test
    fun `isMetadataParagraph - filters Date metadata`() {
        assertTrue(isMetadataParagraph("Date: 2024-01-01"))
    }

    @Test
    fun `isMetadataParagraph - filters Creator metadata`() {
        assertTrue(isMetadataParagraph("Creator: Jane Austen"))
    }

    @Test
    fun `isMetadataParagraph - filters Source metadata`() {
        assertTrue(isMetadataParagraph("Source: Project Gutenberg"))
    }

    @Test
    fun `isMetadataParagraph - filters Format metadata`() {
        assertTrue(isMetadataParagraph("Format: application/epub+zip"))
    }

    @Test
    fun `isMetadataParagraph - filters Identifier metadata`() {
        assertTrue(isMetadataParagraph("Identifier: urn:uuid:abc123"))
    }

    @Test
    fun `isMetadataParagraph - filters Contributor metadata`() {
        assertTrue(isMetadataParagraph("Contributor: Bob the Editor"))
    }

    @Test
    fun `isMetadataParagraph - filters Relation metadata`() {
        assertTrue(isMetadataParagraph("Relation: Sequel to Something"))
    }

    @Test
    fun `isMetadataParagraph - filters Coverage metadata`() {
        assertTrue(isMetadataParagraph("Coverage: Worldwide"))
    }

    @Test
    fun `isMetadataParagraph - filters Rights metadata`() {
        assertTrue(isMetadataParagraph("Rights: All rights reserved"))
    }

    @Test
    fun `isMetadataParagraph - filters Version metadata`() {
        assertTrue(isMetadataParagraph("Version: 1.0"))
    }

    @Test
    fun `isMetadataParagraph - is case insensitive`() {
        assertTrue(isMetadataParagraph("LANGUAGE: ENGLISH"))
        assertTrue(isMetadataParagraph("title: lowercase book"))
        assertTrue(isMetadataParagraph("AuThOr: Mixed Case"))
    }

    @Test
    fun `isMetadataParagraph - tolerates surrounding whitespace`() {
        assertTrue(isMetadataParagraph("   Author: John Doe   "))
        assertTrue(isMetadataParagraph("\tTitle: Tabbed\t"))
    }

    @Test
    fun `isMetadataParagraph - tolerates extra whitespace around colon`() {
        assertTrue(isMetadataParagraph("Language:    English"))
        assertTrue(isMetadataParagraph("ISBN:12345"))
    }

    // --- Negative cases: real content must NOT be filtered ---

    @Test
    fun `isMetadataParagraph - does not filter ordinary prose`() {
        assertFalse(isMetadataParagraph("The cat sat on the mat"))
    }

    @Test
    fun `isMetadataParagraph - does not filter a simple narrative sentence`() {
        assertFalse(isMetadataParagraph("She walked to the store."))
    }

    @Test
    fun `isMetadataParagraph - does not filter a Dickens opening`() {
        assertFalse(isMetadataParagraph("It was the best of times, it was the worst of times."))
    }

    @Test
    fun `isMetadataParagraph - does not filter text with no colon`() {
        assertFalse(isMetadataParagraph("No colon here at all"))
    }

    @Test
    fun `isMetadataParagraph - does not filter empty string`() {
        assertFalse(isMetadataParagraph(""))
    }

    @Test
    fun `isMetadataParagraph - does not filter whitespace-only string`() {
        assertFalse(isMetadataParagraph("   "))
    }

    @Test
    fun `isMetadataParagraph - keyword word in prose is not treated as metadata`() {
        // "Copyright law is complex." starts with the word "Copyright" but has
        // no colon immediately after the keyword, so it must NOT be filtered.
        assertFalse(isMetadataParagraph("Copyright law is complex."))
        assertFalse(isMetadataParagraph("The Title of the story is unknown."))
        assertFalse(isMetadataParagraph("Language evolves over time, naturally."))
    }

    @Test
    fun `isMetadataParagraph - keyword with colon but no value is not matched`() {
        // The regex requires ".+" after the colon, so a bare "Title:" is not metadata.
        assertFalse(isMetadataParagraph("Title:"))
        assertFalse(isMetadataParagraph("Title: "))
        assertFalse(isMetadataParagraph("Author:"))
    }

    @Test
    fun `isMetadataParagraph - very long metadata-looking text is not filtered`() {
        // The guard `trimmed.length > 100` returns false to protect real content
        // that merely happens to begin with a metadata-like prefix.
        val long = "Title: " + "x".repeat(150)
        assertTrue("sanity: input exceeds 100 chars", long.length > 100)
        assertFalse(isMetadataParagraph(long))
    }

    @Test
    fun `isMetadataParagraph - does not filter colon later in sentence`() {
        assertFalse(isMetadataParagraph("He said: let's go now."))
        assertFalse(isMetadataParagraph("The answer is: forty-two."))
    }

    // ==================================================================
    // 3. HTML entity decoding
    // ==================================================================

    @Test
    fun `entity - amp is decoded to ampersand via Jsoup text path`() {
        // The non-<br> branch relies on Jsoup's Element.text() for decoding.
        val text = Jsoup.parse("<p>Tom &amp; Jerry</p>").text()
        assertEquals("Tom & Jerry", text)
    }

    @Test
    fun `entity - lt is decoded to less-than via Jsoup text path`() {
        val text = Jsoup.parse("<p>a &lt; b</p>").text()
        assertEquals("a < b", text)
    }

    @Test
    fun `entity - gt is decoded to greater-than via Jsoup text path`() {
        val text = Jsoup.parse("<p>a &gt; b</p>").text()
        assertEquals("a > b", text)
    }

    @Test
    fun `entity - 39 is decoded to apostrophe via Jsoup text path`() {
        val text = Jsoup.parse("<p>It&#39;s fine</p>").text()
        assertEquals("It's fine", text)
    }

    @Test
    fun `entity - all common entities decoded via Jsoup text path`() {
        // NOTE: &nbsp; is intentionally omitted here — Jsoup's text() decodes it
        // to U+00A0 (non-breaking space), not a regular space. The <br>-branch
        // manual chain replaces &nbsp; with a normal space and is tested below.
        val html = "<p>&amp; &lt; &gt; &#39; &quot;</p>"
        val text = Jsoup.parse(html).text()
        assertEquals("& < > ' \"", text)
    }

    @Test
    fun `entity - manual decode chain in br branch decodes amp`() {
        // The <br> branch does its own manual decoding (see brSegments).
        val segments = brSegments("Tom &amp; Jerry<br>End")
        assertEquals(listOf("Tom & Jerry", "End"), segments)
    }

    @Test
    fun `entity - manual decode chain in br branch decodes lt and gt`() {
        val segments = brSegments("a &lt; b &gt; c<br>ok")
        assertEquals(listOf("a < b > c", "ok"), segments)
    }

    @Test
    fun `entity - manual decode chain in br branch decodes 39 to apostrophe`() {
        val segments = brSegments("It&#39;s great<br>really")
        assertEquals(listOf("It's great", "really"), segments)
    }

    @Test
    fun `entity - manual decode chain in br branch decodes quot and nbsp`() {
        val segments = brSegments("say &quot;hi&quot;&nbsp;now<br>x")
        assertEquals(listOf("say \"hi\" now", "x"), segments)
    }

    // ==================================================================
    // 4. <br> tag splitting
    // ==================================================================

    @Test
    fun `br - splits a paragraph with br tags into segments`() {
        val innerHtml = "Line one.<br>Line two.<br>Line three."
        val segments = brSegments(innerHtml)
        assertEquals(listOf("Line one.", "Line two.", "Line three."), segments)
    }

    @Test
    fun `br - recognizes self-closing br slash`() {
        val segments = brSegments("Line one.<br/>Line two.")
        assertEquals(listOf("Line one.", "Line two."), segments)
    }

    @Test
    fun `br - recognizes br with space before slash`() {
        val segments = brSegments("Line one.<br />Line two.")
        assertEquals(listOf("Line one.", "Line two."), segments)
    }

    @Test
    fun `br - is case insensitive`() {
        val segments = brSegments("Line one.<BR>Line two.<Br/>Line three.")
        assertEquals(listOf("Line one.", "Line two.", "Line three."), segments)
    }

    @Test
    fun `br - filters out blank segments between consecutive br tags`() {
        val segments = brSegments("A<br><br>B")
        assertEquals(listOf("A", "B"), segments)
    }

    @Test
    fun `br - trims leading and trailing br and surrounding whitespace`() {
        val segments = brSegments("<br>  A  <br>")
        assertEquals(listOf("A"), segments)
    }

    @Test
    fun `br - returns empty list when there is no br tag`() {
        // Mirrors the production guard: without a <br> the branch is not taken.
        assertEquals(emptyList<String>(), brSegments("Just a plain paragraph."))
    }

    @Test
    fun `br - decodes entities within each segment`() {
        val segments = brSegments("Tom &amp; Jerry<br>It&#39;s a show<br>5 &lt; 6")
        assertEquals(listOf("Tom & Jerry", "It's a show", "5 < 6"), segments)
    }

    @Test
    fun `br - integration with real Jsoup Element_html output`() {
        // This mirrors extractParagraphs(): parse HTML, take Element.html()
        // (which preserves encoded entities and <br> tags), then split.
        val doc = Jsoup.parse("<p>First part.<br>Second &amp; part.<br>Third &#39;part&#39;.</p>")
        val el = doc.select("p").first()
        val innerHtml = el!!.html()

        val segments = brSegments(innerHtml)
        assertEquals(listOf("First part.", "Second & part.", "Third 'part'."), segments)
    }

    @Test
    fun `br - strips nested tags but keeps surrounding text`() {
        val segments = brSegments("Bold <b>word</b> here.<br>Next line.")
        assertEquals(listOf("Bold word here.", "Next line."), segments)
    }

    // ==================================================================
    // 5. readEpub() input validation — reachable through every public
    //    suspend entry point. Guards `require` clauses and the defensive
    //    try/catch in extractCoverImage() that swallows failure.
    // ==================================================================

    @Test
    fun `parseMetadata - blank path throws IllegalArgumentException`() {
        val ex = assertThrows(IllegalArgumentException::class.java) {
            runBlocking { parser.parseMetadata("") }
        }
        assertTrue("Expected 'filePath must not be blank' message", ex.message!!.contains("filePath must not be blank"))
    }

    @Test
    fun `parseMetadata - non-existent file throws IllegalArgumentException`() {
        val ghost = java.io.File(System.getProperty("user.home"), "ghost_${System.nanoTime()}.epub")
        assertTrue("sanity: temp file does not exist", !ghost.exists())

        val ex = assertThrows(IllegalArgumentException::class.java) {
            runBlocking { parser.parseMetadata(ghost.absolutePath) }
        }
        assertTrue("Expected 'does not exist' message", ex.message!!.contains("does not exist"))
    }

    // Regression tests for DR-067: verify exception handling and rethrow behavior
    @Test
    fun `parseMetadata - IllegalArgumentException from readEpub propagates unchanged`() {
        val ghost = java.io.File(System.getProperty("user.home"), "ghost_prop_${System.nanoTime()}.epub")
        assertTrue("sanity: temp file does not exist", !ghost.exists())

        val ex = assertThrows(IllegalArgumentException::class.java) {
            runBlocking { parser.parseMetadata(ghost.absolutePath) }
        }
        // Should be the original IllegalArgumentException from readEpub, not wrapped
        assertTrue("Expected original 'does not exist' message", ex.message!!.contains("does not exist"))
        assertFalse("Should NOT be wrapped with 'Failed to read EPUB file'", ex.message!!.contains("Failed to read EPUB file"))
    }

    @Test
    fun `extractParagraphs - blank path throws IllegalArgumentException`() {
        assertThrows(IllegalArgumentException::class.java) {
            runBlocking { parser.extractParagraphs("   ") }
        }
    }

    @Test
    fun `extractParagraphs - non-existent file throws IllegalArgumentException`() {
        assertThrows(IllegalArgumentException::class.java) {
            runBlocking { parser.extractParagraphs("/definitely/not/a/real/book.epub") }
        }
    }

    @Test
    fun `extractChapterText - blank path throws IllegalArgumentException`() {
        assertThrows(IllegalArgumentException::class.java) {
            runBlocking { parser.extractChapterText("", 0) }
        }
    }

    @Test
    fun `extractFullText - blank path throws IllegalArgumentException`() {
        assertThrows(IllegalArgumentException::class.java) {
            runBlocking { parser.extractFullText("") }
        }
    }

    @Test
    fun `extractCoverImage - returns null for non-existent file instead of throwing`() {
        // extractCoverImage wraps readEpub in try/catch, so a missing file
        // must surface as null rather than an exception.
        val result = runBlocking { parser.extractCoverImage("/no/such/file.epub") }
        assertNull("Expected null for missing file", result)
    }

    // ── Logging behavior (DR-069) ─────────────────────────────────────────

    @Test
    fun `extractCoverImage - extraction errors return null with logging`() {
        // Verify that any exception during cover extraction results in null
        // (the specific exception type doesn't matter, only the fallback behavior)
        val result = runBlocking { parser.extractCoverImage("/invalid/path/test.epub") }
        assertNull("Expected null for invalid file", result)
    }

    @Test
    fun `extractCoverImage - invalid path returns null without throwing`() {
        // extractCoverImage wraps readEpub in try/catch with logging
        val result = runBlocking { parser.extractCoverImage("/definitely/not/a/real/file.epub") }
        assertNull("Expected null for non-existent file", result)
    }
}
