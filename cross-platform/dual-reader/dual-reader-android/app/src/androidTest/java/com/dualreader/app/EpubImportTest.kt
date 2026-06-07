package com.dualreader.app

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.dualreader.app.data.parser.EpubParserImpl
import com.dualreader.app.data.pagination.PaginationServiceImpl
import kotlinx.coroutines.runBlocking
import org.junit.Assert.*
import org.junit.FixMethodOrder
import org.junit.Test
import org.junit.runner.RunWith
import org.junit.runners.MethodSorters
import java.io.File

@RunWith(AndroidJUnit4::class)
@FixMethodOrder(MethodSorters.NAME_ASCENDING)
class EpubImportTest {

    private suspend fun copyTestEpub(): File {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val testEpub = File(context.cacheDir, "test_book.epub")
        context.assets.open("test_book.epub").use { input ->
            testEpub.outputStream().use { output ->
                input.copyTo(output)
            }
        }
        return testEpub
    }

    @Test
    fun test1_EpubFileExists() {
        val testEpub = runBlocking { copyTestEpub() }
        assertTrue("EPUB should exist", testEpub.exists())
        assertTrue("EPUB should have content", testEpub.length() > 0)
        println("✅ EPUB file: ${testEpub.length()} bytes")
    }

    @Test
    fun test2_ParseMetadata() = runBlocking {
        val testEpub = copyTestEpub()
        val parser = EpubParserImpl()
        val parsed = parser.parseMetadata(testEpub.absolutePath)

        println("Title: '${parsed.title}'")
        println("Author: '${parsed.author}'")
        println("Language: '${parsed.language}'")
        println("Chapters: ${parsed.chapters.size}")
        parsed.chapters.forEachIndexed { i, ch ->
            println("  Ch $i: ${ch.title}")
        }

        assertNotNull("Title should not be null", parsed.title)
        assertTrue("Should have at least 1 chapter", parsed.chapters.isNotEmpty())
        println("✅ Metadata parsed: ${parsed.chapters.size} chapters")
    }

    @Test
    fun test3_ExtractFullText() = runBlocking {
        val testEpub = copyTestEpub()
        val parser = EpubParserImpl()
        val fullText = parser.extractFullText(testEpub.absolutePath)

        println("Full text: ${fullText.length} chars")
        println("Preview: ${fullText.take(200)}")

        assertTrue("Should have text content", fullText.isNotBlank())
        println("✅ Full text extracted: ${fullText.length} chars")
    }

    @Test
    fun test4_Paginate() = runBlocking {
        val testEpub = copyTestEpub()
        val parser = EpubParserImpl()
        val fullText = parser.extractFullText(testEpub.absolutePath)

        val paginationService = PaginationServiceImpl()
        val pages = paginationService.paginate(
            text = fullText,
            availableWidth = 480,
            availableHeight = 1000,
            fontSize = 16f,
            lineHeight = 1.5f,
            margins = 16
        )

        println("Pages: ${pages.size}")
        pages.forEachIndexed { i, pageText ->
            println("  Page $i (${pageText.length} chars): ${pageText.take(60)}...")
        }

        assertTrue("Should produce at least 1 page", pages.isNotEmpty())
        println("✅ Pagination: ${pages.size} pages")
    }

    @Test
    fun test5_FullPipeline() = runBlocking {
        val testEpub = copyTestEpub()
        val parser = EpubParserImpl()
        val paginationService = PaginationServiceImpl()

        // Parse
        val parsed = parser.parseMetadata(testEpub.absolutePath)
        println("📖 Book: ${parsed.title} by ${parsed.author}")
        println("   ${parsed.chapters.size} chapters")

        // Extract
        val fullText = parser.extractFullText(testEpub.absolutePath)
        println("   ${fullText.length} chars total")

        // Paginate
        val pages = paginationService.paginate(
            text = fullText,
            availableWidth = 480,
            availableHeight = 1000,
            fontSize = 16f,
            lineHeight = 1.5f,
            margins = 16
        )
        println("   ${pages.size} pages")

        assertTrue("Should have content", fullText.isNotBlank())
        assertTrue("Should produce pages", pages.isNotEmpty())
        println("\n🎉 Full pipeline PASSED")
    }
}
