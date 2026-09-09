package com.dualreader.app.domain.export

import com.google.common.truth.Truth.assertThat
import org.junit.Before
import org.junit.Test
import java.time.LocalDateTime

/**
 * DR-205 regression tests: Verify BookmarkExporter private methods handle empty lists safely.
 * Pure Kotlin test - no Robolectric needed (BookmarkExporter has no Android dependencies).
 */
class BookmarkExporterDR205Test {

    private lateinit var exporter: BookmarkExporter

    @Before
    fun setUp() {
        exporter = BookmarkExporter()
    }

    // ─── DR-205 Regression: Empty List Safety ───────────────────────────────

    @Test
    fun `exportPlainText with empty list returns fallback message without crashing`() {
        val result = exporter.export(emptyList(), ExportFormat.PLAIN_TEXT)
        assertThat(result).isEqualTo("No annotations to export.")
    }

    @Test
    fun `exportMarkdown with empty list returns fallback message without crashing`() {
        val result = exporter.export(emptyList(), ExportFormat.MARKDOWN)
        assertThat(result).isEqualTo("# No annotations to export")
    }

    @Test
    fun `exportJson with empty list returns empty JSON array without crashing`() {
        val result = exporter.export(emptyList(), ExportFormat.JSON)
        assertThat(result).isEqualTo("""{"annotations":[],"totalAnnotations":0}""")
    }

    @Test
    fun `export with single bookmark works correctly`() {
        val bookmark = ExportableBookmark(
            bookTitle = "Test Book",
            bookAuthor = "Test Author",
            pageIndex = 0,
            chapterIndex = 0,
            textSnippet = "Test text",
            note = "Test note",
            createdAt = LocalDateTime.of(2026, 1, 1, 0, 0),
        )
        val result = exporter.export(listOf(bookmark), ExportFormat.PLAIN_TEXT)
        assertThat(result).contains("Test Book")
        assertThat(result).contains("Test text")
    }

    @Test
    fun `export with multiple bookmarks preserves all entries`() {
        val bookmarks = listOf(
            ExportableBookmark(
                bookTitle = "Test Book",
                bookAuthor = "Test Author",
                pageIndex = 0,
                chapterIndex = 0,
                textSnippet = "First",
                note = "",
                createdAt = LocalDateTime.of(2026, 1, 1, 0, 0),
            ),
            ExportableBookmark(
                bookTitle = "Test Book",
                bookAuthor = "Test Author",
                pageIndex = 1,
                chapterIndex = 0,
                textSnippet = "Second",
                note = "",
                createdAt = LocalDateTime.of(2026, 1, 1, 0, 0),
            ),
            ExportableBookmark(
                bookTitle = "Test Book",
                bookAuthor = "Test Author",
                pageIndex = 2,
                chapterIndex = 0,
                textSnippet = "Third",
                note = "",
                createdAt = LocalDateTime.of(2026, 1, 1, 0, 0),
            ),
        )
        val result = exporter.export(bookmarks, ExportFormat.PLAIN_TEXT)
        assertThat(result).contains("First")
        assertThat(result).contains("Second")
        assertThat(result).contains("Third")
        assertThat(result).contains("Annotations (3)")
    }
}