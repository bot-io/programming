package com.dualreader.app.data.pagination

import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Integration tests for PaginationServiceImpl.
 *
 * NOTE: Robolectric's StaticLayout doesn't measure real text, so layout.height
 * returns 0. We can only test:
 * - Empty/blank text handling
 * - Short text that fits on one page
 * - Text preservation across pages
 * - That the method doesn't crash or freeze
 *
 * Sentence boundary quality must be verified with instrumented tests on
 * a real device/emulator, or by visual inspection.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class PaginationIntegrationTest {

    private lateinit var paginator: PaginationServiceImpl

    @Before
    fun setup() {
        paginator = PaginationServiceImpl()
        PaginationServiceImpl.displayDensity = 2.625f
    }

    private suspend fun paginate(
        text: String,
        width: Int = 360,
        height: Int = 600,
        fontSize: Float = 14f,
        lineHeight: Float = 1.4f,
        margins: Int = 16,
    ): List<String> {
        return paginator.paginate(text, width, height, fontSize, lineHeight, margins)
    }

    @Test
    fun `empty text returns empty list`() = kotlinx.coroutines.test.runTest {
        assertTrue(paginate("").isEmpty())
    }

    @Test
    fun `blank text returns empty list`() = kotlinx.coroutines.test.runTest {
        assertTrue(paginate("   \n\n   ").isEmpty())
    }

    @Test
    fun `single short paragraph returns one page`() = kotlinx.coroutines.test.runTest {
        val result = paginate("Hello world.")
        assertEquals(1, result.size)
        assertEquals("Hello world.", result[0])
    }

    @Test
    fun `all text is preserved across pages`() = kotlinx.coroutines.test.runTest {
        val sentences = (1..30).map { "Sentence $it is here." }
        val text = sentences.joinToString(" ")

        val result = paginate(text)

        val rejoined = result.joinToString(" ")
            .replace(Regex("\\s+"), " ").trim()
        val original = text.replace(Regex("\\s+"), " ").trim()
        assertEquals("All text must be preserved", original, rejoined)
    }

    @Test
    fun `all text preserved with paragraph breaks`() = kotlinx.coroutines.test.runTest {
        val paragraphs = (1..10).map { p ->
            (1..3).map { "Sentence $p-$it." }.joinToString(" ")
        }
        val text = paragraphs.joinToString("\n\n")

        val result = paginate(text)

        val rejoined = result.joinToString("\n\n")
            .replace(Regex("\\s+"), " ").trim()
        val original = text.replace(Regex("\\s+"), " ").trim()
        assertEquals(original, rejoined)
    }

    @Test
    fun `no crash with very long text`() = kotlinx.coroutines.test.runTest {
        val text = (1..500).map { i ->
            "Sentence $i with some padding to make it longer for testing."
        }.joinToString(" ")

        val start = System.currentTimeMillis()
        val result = paginate(text)
        val elapsed = System.currentTimeMillis() - start

        assertTrue("Should produce at least one page", result.isNotEmpty())
        assertTrue("Should not freeze — took ${elapsed}ms", elapsed < 5000)
    }

    @Test
    fun `no crash with many paragraphs`() = kotlinx.coroutines.test.runTest {
        val text = (1..200).map { "Paragraph $it text." }.joinToString("\n\n")

        val start = System.currentTimeMillis()
        val result = paginate(text)
        val elapsed = System.currentTimeMillis() - start

        assertTrue(result.isNotEmpty())
        assertTrue("Should not freeze — took ${elapsed}ms", elapsed < 5000)
    }

    @Test
    fun `no crash with unicode and special chars`() = kotlinx.coroutines.test.runTest {
        val text = "Това е български текст. Пробваме кирилица! Работи ли? Да… "
        val result = paginate(text)
        assertTrue(result.isNotEmpty())
        assertEquals(text.trim(), result[0].trim())
    }

    @Test
    fun `page content matches original`() = kotlinx.coroutines.test.runTest {
        val text = "First paragraph.\n\nSecond paragraph.\n\nThird paragraph."
        val result = paginate(text)
        assertEquals(listOf(text), result)
    }
}
