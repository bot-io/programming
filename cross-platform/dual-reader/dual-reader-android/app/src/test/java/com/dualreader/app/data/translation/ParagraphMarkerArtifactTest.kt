package com.dualreader.app.data.translation

import org.junit.Test
import org.junit.Assert.*

/**
 * DR-092: Regression tests for ⟦N⟧ marker artifacts leaking into translated text.
 *
 * Root cause: When batch-translating multiple pages, [ParagraphAligner.injectMarkers]
 * prepends `⟦N⟧` markers to each paragraph for LLM context. After translation,
 * [ParagraphAligner.extractByMarkers] should split them out. But several paths
 * could leak markers into the final text:
 *
 * 1. Fallback alignment path: markers not stripped before [align]
 * 2. extractByMarkers segments: residual markers not stripped from content
 * 3. Cached results: old cache entries may contain markers
 * 4. Batch endpoint results: markers in translatePages output
 *
 * Fix: stripMarkers() applied at every result checkpoint.
 */
class ParagraphMarkerArtifactTest {

    // ═══════════════════════════════════════════════════════════════════════════
    // stripMarkers — basic behavior
    // ═══════════════════════════════════════════════════════════════════════════

    @Test
    fun `stripMarkers - removes single marker at start`() {
        val input = "\u27E61\u27E7 Hello world"
        val result = ParagraphAligner.stripMarkers(input)
        assertEquals("Hello world", result)
    }

    @Test
    fun `stripMarkers - removes multiple markers`() {
        val input = "\u27E61\u27E7 First paragraph\n\n\u27E62\u27E7 Second paragraph"
        val result = ParagraphAligner.stripMarkers(input)
        assertEquals("First paragraph\n\nSecond paragraph", result)
    }

    @Test
    fun `stripMarkers - removes marker from middle of text`() {
        val input = "Some text \u27E63\u27E7 more text"
        val result = ParagraphAligner.stripMarkers(input)
        assertEquals("Some text more text", result)
    }

    @Test
    fun `stripMarkers - preserves text without markers`() {
        val input = "Clean translated text without any markers"
        val result = ParagraphAligner.stripMarkers(input)
        assertEquals("Clean translated text without any markers", result)
    }

    @Test
    fun `stripMarkers - handles double-digit markers`() {
        val input = "\u27E614\u27E7 Hello"
        val result = ParagraphAligner.stripMarkers(input)
        assertEquals("Hello", result)
    }

    @Test
    fun `stripMarkers - handles empty string`() {
        assertEquals("", ParagraphAligner.stripMarkers(""))
    }

    @Test
    fun `stripMarkers - handles string with only markers`() {
        val input = "\u27E61\u27E7 \u27E62\u27E7"
        val result = ParagraphAligner.stripMarkers(input)
        assertEquals("", result)
    }

    @Test
    fun `stripMarkers - does NOT remove regular square brackets`() {
        val input = "[1] Regular bracket text"
        val result = ParagraphAligner.stripMarkers(input)
        assertEquals("[1] Regular bracket text", result)
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // extractByMarkers — no residual markers in segments
    // ═══════════════════════════════════════════════════════════════════════════

    @Test
    fun `extractByMarkers - segments do not contain markers`() {
        val input = "\u27E61\u27E7 First\n\n\u27E62\u27E7 Second\n\n\u27E63\u27E7 Third"
        val result = ParagraphAligner.extractByMarkers(input, 3)
        assertNotNull(result)
        assertEquals(3, result!!.size)
        result.forEach { segment ->
            assertFalse(
                "Segment '$segment' should not contain markers",
                ParagraphAligner.hasMarkers(segment)
            )
        }
    }

    @Test
    fun `extractByMarkers - strips duplicated markers inside content`() {
        // LLM sometimes duplicates markers: ⟦1⟧ ⟦1⟧ Hello
        val input = "\u27E61\u27E7 \u27E61\u27E7 Hello\n\n\u27E62\u27E7 World"
        val result = ParagraphAligner.extractByMarkers(input, 2)
        assertNotNull(result)
        assertEquals("Hello", result!![0])
        assertEquals("World", result[1])
    }

    @Test
    fun `extractByMarkers - strips markers from last segment with trailing marker`() {
        val input = "\u27E61\u27E7 Hello\n\n\u27E62\u27E7 World \u27E63\u27E7"
        val result = ParagraphAligner.extractByMarkers(input, 2)
        assertNotNull(result)
        assertEquals("Hello", result!![0])
        assertEquals("World", result[1])
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // align — markers stripped before proportional alignment
    // ═══════════════════════════════════════════════════════════════════════════

    @Test
    fun `align - translated text with markers is cleaned in aligned pairs`() {
        val original = "Paragraph one\n\nParagraph two\n\nParagraph three"
        val translated = "\u27E61\u27E7 Parrafo uno\n\n\u27E62\u27E7 Parrafo dos\n\n\u27E63\u27E7 Parrafo tres"
        // Strip markers first (as TranslatePageUseCase now does)
        val cleaned = ParagraphAligner.stripMarkers(translated)
        val aligned = ParagraphAligner.align(original, cleaned)

        assertEquals(3, aligned.size)
        aligned.forEach { (_, translatedPara) ->
            assertFalse(
                "Aligned segment should not contain markers: '$translatedPara'",
                ParagraphAligner.hasMarkers(translatedPara)
            )
        }
    }

    @Test
    fun `align - proportional fallback with markers produces clean output`() {
        // Original has 5 paragraphs, translated has 3 (proportional alignment)
        val original = (1..5).joinToString("\n\n") { "Para $it" }
        val translated = "\u27E61\u27E7 One two\n\n\u27E62\u27E7 Three four\n\n\u27E63\u27E7 Five"
        val cleaned = ParagraphAligner.stripMarkers(translated)
        val aligned = ParagraphAligner.align(original, cleaned)

        assertEquals(5, aligned.size)
        aligned.forEach { (_, translatedPara) ->
            assertFalse(
                "Proportionally aligned segment should not contain markers: '$translatedPara'",
                ParagraphAligner.hasMarkers(translatedPara)
            )
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // inject + extract round-trip — no markers survive
    // ═══════════════════════════════════════════════════════════════════════════

    @Test
    fun `inject then extract round-trip - no markers in final output`() {
        val paragraphs = listOf("Hello world", "Goodbye world", "Third paragraph")
        val marked = ParagraphAligner.injectMarkers(paragraphs)
        // Simulate LLM preserving markers perfectly
        val extracted = ParagraphAligner.extractByMarkers(marked, 3)

        assertNotNull(extracted)
        assertEquals(3, extracted!!.size)
        // Content should match originals (without markers)
        assertEquals("Hello world", extracted[0])
        assertEquals("Goodbye world", extracted[1])
        assertEquals("Third paragraph", extracted[2])
    }

    @Test
    fun `inject then extract round-trip - LLM translates content but keeps markers`() {
        val paragraphs = listOf("Hello", "World")
        val marked = ParagraphAligner.injectMarkers(paragraphs)
        // LLM translates: ⟦1⟧ Hola\n\n⟦2⟧ Mundo
        val translated = marked
            .replace("Hello", "Hola")
            .replace("World", "Mundo")
        val extracted = ParagraphAligner.extractByMarkers(translated, 2)

        assertNotNull(extracted)
        assertEquals("Hola", extracted!![0])
        assertEquals("Mundo", extracted[1])
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // Edge cases
    // ═══════════════════════════════════════════════════════════════════════════

    @Test
    fun `hasMarkers - detects markers in text`() {
        assertTrue(ParagraphAligner.hasMarkers("\u27E61\u27E7 text"))
        assertTrue(ParagraphAligner.hasMarkers("text \u27E699\u27E7 more"))
    }

    @Test
    fun `hasMarkers - returns false for clean text`() {
        assertFalse(ParagraphAligner.hasMarkers("Clean text"))
        assertFalse(ParagraphAligner.hasMarkers("[1] Regular brackets"))
    }

    @Test
    fun `stripMarkers - idempotent`() {
        val input = "\u27E61\u27E7 Hello"
        val once = ParagraphAligner.stripMarkers(input)
        val twice = ParagraphAligner.stripMarkers(once)
        assertEquals(once, twice)
    }

    @Test
    fun `full pipeline - inject, translate with partial marker loss, strip, align produces clean output`() {
        // Simulate: LLM keeps markers on some paragraphs but not all
        val originals = listOf("One", "Two", "Three", "Four")
        // LLM output: markers preserved on 1 and 3, lost on 2 and 4
        val llmOutput = "\u27E61\u27E7 Uno\n\nDos\n\n\u27E63\u27E7 Tres\n\nCuatro"

        // extractByMarkers should return null (only 2 markers, expected 4)
        val extracted = ParagraphAligner.extractByMarkers(llmOutput, 4)
        assertNull(extracted) // Should trigger fallback

        // Fallback: strip markers then align
        val cleaned = ParagraphAligner.stripMarkers(llmOutput)
        assertFalse("Cleaned text should have no markers", ParagraphAligner.hasMarkers(cleaned))

        val origJoined = originals.joinToString("\n\n")
        val aligned = ParagraphAligner.align(origJoined, cleaned)
        aligned.forEach { (_, text) ->
            assertFalse(
                "No markers should survive the full pipeline: '$text'",
                ParagraphAligner.hasMarkers(text)
            )
        }
    }
}
