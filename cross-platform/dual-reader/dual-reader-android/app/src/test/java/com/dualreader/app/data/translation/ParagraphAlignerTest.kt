package com.dualreader.app.data.translation

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class ParagraphAlignerTest {

    @Test
    fun `splitParagraphs splits on double newline`() {
        val text = "First paragraph.\n\nSecond paragraph.\n\nThird paragraph."
        val paras = ParagraphAligner.splitParagraphs(text)
        assertEquals(3, paras.size)
        assertEquals("First paragraph.", paras[0])
        assertEquals("Second paragraph.", paras[1])
        assertEquals("Third paragraph.", paras[2])
    }

    @Test
    fun `splitParagraphs handles multiple consecutive newlines`() {
        val text = "Para one.\n\n\n\nPara two."
        val paras = ParagraphAligner.splitParagraphs(text)
        assertEquals(2, paras.size)
    }

    @Test
    fun `splitParagraphs filters blank paragraphs`() {
        val text = "Real content.\n\n   \n\nAlso real."
        val paras = ParagraphAligner.splitParagraphs(text)
        assertEquals(2, paras.size)
    }

    @Test
    fun `splitParagraphs handles single paragraph`() {
        val text = "Just one paragraph with no breaks."
        val paras = ParagraphAligner.splitParagraphs(text)
        assertEquals(1, paras.size)
    }

    @Test
    fun `splitParagraphs handles empty string`() {
        val paras = ParagraphAligner.splitParagraphs("")
        assertEquals(0, paras.size)
    }

    @Test
    fun `align perfect 1-to-1 match`() {
        val original = "Hello world.\n\nGoodbye world.\n\nThird paragraph."
        val translated = "Hola mundo.\n\nAdiós mundo.\n\nTercer párrafo."
        val pairs = ParagraphAligner.align(original, translated)
        assertEquals(3, pairs.size)
        assertEquals("Hello world.", pairs[0].first)
        assertEquals("Hola mundo.", pairs[0].second)
        assertEquals("Goodbye world.", pairs[1].first)
        assertEquals("Adiós mundo.", pairs[1].second)
    }

    @Test
    fun `align handles translation with fewer paragraphs (merged by LLM)`() {
        val original = "First original.\n\nSecond original.\n\nThird original."
        val translated = "First and second combined.\n\nThird translated."
        val pairs = ParagraphAligner.align(original, translated)
        assertEquals(3, pairs.size)
        // Proportional: orig[0]→trans[0], orig[1]→trans[0], orig[2]→trans[1]
        assertEquals("First translated.", pairs[0].second)
    }

    @Test
    fun `align handles translation with more paragraphs (split by LLM)`() {
        val original = "First original paragraph.\n\nSecond original paragraph."
        val translated = "First part A.\n\nFirst part B.\n\nSecond translated."
        val pairs = ParagraphAligner.align(original, translated)
        assertEquals(2, pairs.size)
        // orig[0] → trans[0] (proportional), orig[1] → trans[2]
        assertTrue(pairs[0].second.isNotBlank())
        assertTrue(pairs[1].second.isNotBlank())
    }

    @Test
    fun `align with empty translation returns pairs with empty translations`() {
        val original = "Some text.\n\nMore text."
        val translated = ""
        val pairs = ParagraphAligner.align(original, translated)
        assertEquals(2, pairs.size)
        assertEquals("", pairs[0].second)
        assertEquals("", pairs[1].second)
    }

    @Test
    fun `align with single paragraph on both sides`() {
        val original = "Single paragraph."
        val translated = "Single traducción."
        val pairs = ParagraphAligner.align(original, translated)
        assertEquals(1, pairs.size)
        assertEquals("Single paragraph.", pairs[0].first)
        assertEquals("Single traducción.", pairs[0].second)
    }

    @Test
    fun `align preserves long text with many paragraphs`() {
        val origParas = (1..10).joinToString("\n\n") { "Paragraph $it of original." }
        val transParas = (1..10).joinToString("\n\n") { "Párrafo $it de traducción." }
        val pairs = ParagraphAligner.align(origParas, transParas)
        assertEquals(10, pairs.size)
        assertEquals("Paragraph 1 of original.", pairs[0].first)
        assertEquals("Párrafo 1 de traducción.", pairs[0].second)
        assertEquals("Paragraph 10 of original.", pairs[9].first)
        assertEquals("Párrafo 10 de traducción.", pairs[9].second)
    }

    @Test
    fun `align handles paragraphs with trailing whitespace`() {
        val original = "Paragraph one.  \n\n  Paragraph two."
        val translated = "Párrafo uno.\n\nPárrafo dos."
        val pairs = ParagraphAligner.align(original, translated)
        assertEquals(2, pairs.size)
        assertEquals("Paragraph one.", pairs[0].first)
        assertEquals("Párrafo uno.", pairs[0].second)
    }
}
