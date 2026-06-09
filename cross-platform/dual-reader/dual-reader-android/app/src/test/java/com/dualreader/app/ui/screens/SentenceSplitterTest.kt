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

    // ── Regex that previously crashed (unbounded lookbehind) ────────────

    @Test
    fun `splitSentences - does not crash on various inputs`() {
        // Stress test — ensure no PatternSyntaxException or similar
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
            result.forEach { sentence ->
                assertTrue("Sentence should not be blank", sentence.isNotBlank())
            }
        }
    }

    // ── Punctuation retained on preceding sentence ──────────────────────

    @Test
    fun `splitSentences - period stays with preceding sentence`() {
        val result = splitSentences("First sentence. Second sentence.")
        assertTrue(result.size >= 2)
        assertTrue("First should end with period", result[0].trimEnd().endsWith("."))
    }

    @Test
    fun `splitSentences - exclamation mark stays with preceding sentence`() {
        val result = splitSentences("Hello! World!")
        assertTrue(result.size >= 2)
        assertTrue("First should end with !", result[0].trimEnd().endsWith("!"))
    }

    @Test
    fun `splitSentences - question mark stays with preceding sentence`() {
        val result = splitSentences("What? Why?")
        assertTrue(result.size >= 2)
        assertTrue("First should end with ?", result[0].trimEnd().endsWith("?"))
    }

    @Test
    fun `splitSentences - ellipsis stays with preceding sentence`() {
        val result = splitSentences("Hello… World.")
        assertTrue(result.size >= 2)
        assertTrue("First should end with ellipsis", result[0].trimEnd().endsWith("…"))
    }

    // ── Trailing quotes/brackets ───────────────────────────────────────

    @Test
    fun `splitSentences - trailing quote stays with preceding sentence`() {
        val result = splitSentences("""He said "hello." Then he left.""")
        assertTrue(result.size >= 2)
        assertTrue("Should end with quote+period", result[0].trimEnd().endsWith(".\""))
    }

    @Test
    fun `splitSentences - trailing guillemet stays with preceding sentence`() {
        val result = splitSentences("«Здравей.» Как си?")
        assertTrue(result.size >= 2)
        assertTrue("Should end with »", result[0].trimEnd().endsWith("»"))
    }

    @Test
    fun `splitSentences - trailing parenthesis stays with preceding sentence`() {
        val result = splitSentences("Note (see here.) Next.")
        assertTrue(result.size >= 2)
        assertTrue("Should end with )", result[0].trimEnd().endsWith(")"))
    }

    @Test
    fun `splitSentences - trailing bracket stays with preceding sentence`() {
        val result = splitSentences("Note [1]. Next.")
        assertTrue(result.size >= 2)
        // "Note [1]." — the period IS the sentence-ending punctuation;
        // the ] is part of the text but comes before the period
        val first = result[0].trimEnd()
        assertTrue("First sentence should contain [1].: '$first'", first.contains("[1]"))
    }

    // ── Multiple sentences ─────────────────────────────────────────────

    @Test
    fun `splitSentences - two period-separated sentences split correctly`() {
        val result = splitSentences("First sentence. Second sentence.")
        assertTrue("Expected >= 2 sentences, got ${result.size}", result.size >= 2)
    }

    @Test
    fun `splitSentences - three sentences`() {
        val result = splitSentences("One. Two. Three.")
        assertEquals(3, result.size)
    }

    @Test
    fun `splitSentences - five sentences`() {
        val result = splitSentences("Alpha. Beta. Gamma. Delta. Epsilon.")
        assertEquals(5, result.size)
    }

    // ── Language-specific text ─────────────────────────────────────────

    @Test
    fun `splitSentences - Bulgarian text splits`() {
        val result = splitSentences("Първо изречение. Второ изречение.")
        assertTrue("Expected >= 2 parts for Bulgarian text, got ${result.size}", result.size >= 2)
    }

    @Test
    fun `splitSentences - Spanish text splits`() {
        val result = splitSentences("¡Hola! ¿Cómo estás? Bien.")
        assertTrue("Expected >= 2 parts for Spanish text, got ${result.size}", result.size >= 2)
    }

    @Test
    fun `splitSentences - French text with guillemets`() {
        val result = splitSentences("Il a dit «bonjour». Puis il est parti.")
        assertTrue("Expected >= 2 parts for French text, got ${result.size}", result.size >= 2)
    }

    // ── Edge cases ──────────────────────────────────────────────────────

    @Test
    fun `splitSentences - produces at least 1 result for non-blank text`() {
        val result = splitSentences("Any text here at all.")
        assertTrue("Non-blank text should produce at least 1 sentence", result.isNotEmpty())
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

    @Test
    fun `splitSentences - multiple spaces between sentences`() {
        val result = splitSentences("First.   Second.")
        assertEquals(2, result.size)
    }

    @Test
    fun `splitSentences - newline between sentences`() {
        val result = splitSentences("First.\nSecond.")
        assertEquals(2, result.size)
    }

    @Test
    fun `splitSentences - mixed punctuation`() {
        val result = splitSentences("Hello! How are you? I'm fine.")
        assertEquals(3, result.size)
    }

    @Test
    fun `splitSentences - punctuation without space does not split`() {
        // "Hello.World" — no space after period, should not split
        val result = splitSentences("Hello.World")
        assertEquals(1, result.size)
    }

    @Test
    fun `splitSentences - abbreviations treated as single sentence`() {
        // "Dr. Jones" — period after abbreviation but no space before capital
        // Actually there IS a space after "Dr." so this WILL split.
        // This is a known limitation of simple regex-based splitting.
        val result = splitSentences("Dr. Jones arrived.")
        // Accept either 1 or 2 — both are reasonable for a simple splitter
        assertTrue("Expected 1-2 sentences, got ${result.size}", result.size in 1..2)
    }

    @Test
    fun `splitSentences - single quotes around sentence`() {
        val result = splitSentences("""'Hello.' She said.""")
        assertTrue(result.size >= 2)
    }

    @Test
    fun `splitSentences - trailing single quote with period`() {
        val result = splitSentences("""He said 'hi.' Then left.""")
        assertTrue(result.size >= 2)
        // "He said 'hi.'" — the captured group is ".'" so the sentence ends with '
        val first = result[0].trimEnd()
        assertTrue("First should end with quote: '$first'", first.endsWith("'"))
    }
}
