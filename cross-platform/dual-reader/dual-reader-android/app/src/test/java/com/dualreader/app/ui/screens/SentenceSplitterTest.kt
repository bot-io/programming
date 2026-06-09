package com.dualreader.app.ui.screens

import org.junit.Assert.*
import org.junit.Test

class SentenceSplitterTest {

    // ── Basic splitting ─────────────────────────────────────────────────

    @Test
    fun `splitSentences - empty string returns empty list`() {
        assertEquals(emptyList<String>(), splitSentences(""))
    }

    @Test
    fun `splitSentences - blank string returns empty list`() {
        assertEquals(emptyList<String>(), splitSentences("   "))
    }

    @Test
    fun `splitSentences - single sentence`() {
        val result = splitSentences("Hello world.")
        assertEquals(1, result.size)
        assertTrue(result[0].contains("Hello world"))
    }

    @Test
    fun `splitSentences - no ending punctuation produces single result`() {
        val result = splitSentences("No punctuation here")
        assertEquals(1, result.size)
    }

    @Test
    fun `splitSentences - does not crash on various inputs`() {
        // Stress test — ensure no exceptions
        val inputs = listOf(
            "",
            "   ",
            "Hello.",
            "Hello! World!",
            "What? Why?",
            "Dr. Jones arrived.",
            "«Здравей.» Как си?",
            "Note (see here.) Next.",
            "Note [1]. Next.",
            (1..100).joinToString(" ") { "Sentence $it." },
            "Това е първо изречение. Това е второ.",
        )
        for (input in inputs) {
            val result = splitSentences(input)
            assertNotNull("Should not crash on: ${input.take(30)}...", result)
            // All results should be non-blank
            result.forEach { sentence ->
                assertTrue("Sentence should not be blank", sentence.isNotBlank())
            }
        }
    }

    @Test
    fun `splitSentences - produces at least 1 result for non-blank text`() {
        val result = splitSentences("Any text here at all.")
        assertTrue("Non-blank text should produce at least 1 sentence", result.isNotEmpty())
    }

    @Test
    fun `splitSentences - two period-separated sentences split correctly`() {
        val result = splitSentences("First sentence. Second sentence.")
        // Should split into at least 2 parts
        assertTrue("Expected >= 2 sentences, got ${result.size}", result.size >= 2)
    }

    @Test
    fun `splitSentences - Bulgarian text splits`() {
        val result = splitSentences("Първо изречение. Второ изречение.")
        assertTrue("Expected >= 2 parts for Bulgarian text, got ${result.size}", result.size >= 2)
    }

    @Test
    fun `splitSentences - very long text produces many sentences`() {
        val text = (1..50).joinToString(" ") { "Sentence number $it here." }
        val result = splitSentences(text)
        assertTrue("Long text should produce many sentences, got ${result.size}", result.size > 10)
    }

    @Test
    fun `splitSentences - all results are non-blank`() {
        val result = splitSentences("Hello. World. Test.")
        result.forEach { sentence ->
            assertTrue("Sentence should not be blank: '$sentence'", sentence.isNotBlank())
        }
    }
}
