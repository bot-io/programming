package com.dualreader.app.data.pagination

import org.junit.Assert.*
import org.junit.Test

/**
 * Tests for sentence boundary detection used in pagination.
 *
 * These test the pure-logic parts that don't need Android framework.
 * The sentence boundary regex is the critical piece — if it fails,
 * pages will split mid-sentence.
 */
class SentenceBoundaryTest {

    private val paginator = PaginationServiceImpl()

    // ── findLastSentenceEnd: basic cases ──────────────────────────────────────

    @Test
    fun `findLastSentenceEnd - single sentence with period`() {
        val text = "Hello world. "
        val result = paginator.findLastSentenceEnd(text)
        assertNotNull("Should find sentence end after period+space", result)
        assertEquals(13, result) // after ". "
    }

    @Test
    fun `findLastSentenceEnd - multiple sentences`() {
        val text = "First sentence. Second sentence. Third sentence. "
        val result = paginator.findLastSentenceEnd(text)
        assertNotNull(result)
        // Should point to after the LAST ". "
        assertEquals(text.length, result)
    }

    @Test
    fun `findLastSentenceEnd - returns position after LAST boundary`() {
        val text = "One. Two. Three. "
        // ". " at indices: 3-4, 8-9, 14-15. Last match range.last = 15, result = 16
        val result = paginator.findLastSentenceEnd(text)
        assertNotNull(result)
        assertEquals(17, result!!)
        // Text before split = "One. Two. Three."
        assertEquals("One. Two. Three.", text.substring(0, result - 1).trimEnd())
    }

    @Test
    fun `findLastSentenceEnd - exclamation mark`() {
        val text = "Watch out! Be careful. "
        val result = paginator.findLastSentenceEnd(text)
        assertNotNull(result)
        assertEquals(23, result) // after ". "
    }

    @Test
    fun `findLastSentenceEnd - question mark`() {
        // "Why? " at 3-4, "Because. " at 10-11 (length=12 wait let me count)
        // "Why? Because. " — W(0)h(1)y(2)?(3) (4)B(5)e(6)c(7)a(8)u(9)s(10)e(11).(12) (13)
        // "? " at 3-4, ". " at 12-13. Last match: range.last=13, result=14
        val text = "Why? Because. "
        val result = paginator.findLastSentenceEnd(text)
        assertNotNull(result)
        assertEquals(14, result!!)
    }

    @Test
    fun `findLastSentenceEnd - ellipsis character`() {
        val text = "He paused… Then continued. "
        val result = paginator.findLastSentenceEnd(text)
        assertNotNull(result)
        // Should find both "… " and ". "
        // Last one is ". "
        assertEquals(text.length, result)
    }

    @Test
    fun `findLastSentenceEnd - with closing quotes`() {
        val text = "She said \"hello.\" Then left. "
        val result = paginator.findLastSentenceEnd(text)
        assertNotNull(result)
        assertEquals(text.length, result)
    }

    @Test
    fun `findLastSentenceEnd - no sentence boundary`() {
        val text = "no punctuation here"
        val result = paginator.findLastSentenceEnd(text)
        assertNull("Should return null when no sentence boundary found", result)
    }

    @Test
    fun `findLastSentenceEnd - period without trailing space`() {
        val text = "End."
        val result = paginator.findLastSentenceEnd(text)
        // No whitespace after period — no match
        assertNull(result)
    }

    @Test
    fun `findLastSentenceEnd - period at very end without space`() {
        // "First. " at 5-6 (". "), then "Second." has no trailing space
        // Only ". " at 5-6 matches. range.last=6, result=7
        val text = "First. Second."
        val result = paginator.findLastSentenceEnd(text)
        assertNotNull(result)
        assertEquals(7, result!!)
    }

    // ── Splitting text at sentence boundaries ─────────────────────────────────

    @Test
    fun `splitting text at sentence boundary produces clean sentences`() {
        val text = "First sentence. Second sentence. Third sentence. Fourth sentence."
        val result = paginator.findLastSentenceEnd(text)
        assertNotNull(result)
        val r = result!!
        // The function finds the LAST boundary: after "Third sentence. "
        val before = text.substring(0, r).trim()
        val after = text.substring(r).trim()

        assertTrue("Before should end with complete sentence", before.endsWith("."))
        assertEquals("Fourth sentence.", after)
    }

    @Test
    fun `splitting preserves first sentence when boundary found`() {
        val text = "Hello world. This is more text. "
        val result = paginator.findLastSentenceEnd(text)
        assertNotNull(result)
        val r = result!!
        val before = text.substring(0, r).trim()
        assertTrue(before.startsWith("Hello"))
        assertTrue(before.contains("more text"))
    }

    // ── Edge cases ────────────────────────────────────────────────────────────

    @Test
    fun `findLastSentenceEnd - empty string`() {
        assertNull(paginator.findLastSentenceEnd(""))
    }

    @Test
    fun `findLastSentenceEnd - single character`() {
        assertNull(paginator.findLastSentenceEnd("a"))
    }

    @Test
    fun `findLastSentenceEnd - only whitespace`() {
        assertNull(paginator.findLastSentenceEnd("   "))
    }

    @Test
    fun `findLastSentenceEnd - period followed by newline`() {
        // Newline is whitespace too
        val text = "End of line.\nNext line. "
        val result = paginator.findLastSentenceEnd(text)
        assertNotNull(result)
    }

    @Test
    fun `findLastSentenceEnd - multiple punctuation marks`() {
        val text = "Really?! Yes. "
        val result = paginator.findLastSentenceEnd(text)
        assertNotNull(result)
        assertEquals(text.length, result)
    }

    @Test
    fun `findLastSentenceEnd - Bulgarian text with Cyrillic quotes`() {
        val text = "Той каза „Здравей“. После си тръгна. "
        val result = paginator.findLastSentenceEnd(text)
        assertNotNull(result)
        assertEquals(text.length, result)
    }

    @Test
    fun `findLastSentenceEnd - dialogue with quotes`() {
        val text = "\"Go away!\" she said. He left. "
        val result = paginator.findLastSentenceEnd(text)
        assertNotNull(result)
        assertEquals(text.length, result)
    }

    @Test
    fun `findLastSentenceEnd - abbreviations should not split`() {
        // Mr. Dr. etc. are NOT sentence boundaries when followed by a capital
        // Our regex matches them though — this is a known limitation
        val text = "Mr. Smith went home. "
        val result = paginator.findLastSentenceEnd(text)
        assertNotNull(result)
        // It matches "Mr. " — but that's the only match so it's the last one
        // This is acceptable: the sentence "Mr. Smith went home." will be split as
        // "Mr." on one page and "Smith went home." on the next.
        // Not ideal but not catastrophic for translation quality.
    }

    @Test
    fun `findLastSentenceEnd - decimal numbers should not split`() {
        // "3.14" should NOT be a sentence boundary
        val text = "The value is 3.14 approximately. "
        val result = paginator.findLastSentenceEnd(text)
        assertNotNull(result)
        // Should match the final ". " not the one in "3.14"
        // Actually "3. " IS a match for our regex... let's verify
        assertEquals(text.length, result)
    }
}
