package com.dualreader.app.domain.export

import com.google.common.truth.Truth.assertThat
import org.json.JSONObject
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.time.LocalDateTime

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [26])
class BookmarkExporterTest {

    private lateinit var exporter: BookmarkExporter

    @Before
    fun setUp() {
        exporter = BookmarkExporter()
    }

    // ─── Test Data ──────────────────────────────────────────────────────────

    private val sampleBookmark = ExportableBookmark(
        bookTitle = "The Great Gatsby",
        bookAuthor = "F. Scott Fitzgerald",
        pageIndex = 5,
        chapterIndex = 1,
        textSnippet = "So we beat on, boats against the current, borne back ceaselessly into the past.",
        note = "Beautiful closing line",
        createdAt = LocalDateTime.of(2026, 6, 10, 14, 30),
    )

    private val sampleBookmark2 = ExportableBookmark(
        bookTitle = "The Great Gatsby",
        bookAuthor = "F. Scott Fitzgerald",
        pageIndex = 12,
        chapterIndex = 3,
        textSnippet = "He smiled understandingly — much more than understandingly.",
        note = "",
        createdAt = LocalDateTime.of(2026, 6, 11, 9, 15),
    )

    private val emptyNoteBookmark = ExportableBookmark(
        bookTitle = "Test Book",
        bookAuthor = "Test Author",
        pageIndex = 0,
        chapterIndex = 0,
        textSnippet = "Some highlighted text",
        note = "",
        createdAt = LocalDateTime.of(2026, 1, 1, 0, 0),
    )

    private val emptySnippetBookmark = ExportableBookmark(
        bookTitle = "Test Book",
        bookAuthor = "Test Author",
        pageIndex = 3,
        chapterIndex = 0,
        textSnippet = "",
        note = "Just a note without highlighted text",
        createdAt = LocalDateTime.of(2026, 1, 1, 0, 0),
    )

    // ─── Empty Export ───────────────────────────────────────────────────────

    @Test
    fun `export empty list returns plain text message`() {
        val result = exporter.export(emptyList(), ExportFormat.PLAIN_TEXT)
        assertThat(result).isEqualTo("No annotations to export.")
    }

    @Test
    fun `export empty list returns markdown message`() {
        val result = exporter.export(emptyList(), ExportFormat.MARKDOWN)
        assertThat(result).isEqualTo("# No annotations to export")
    }

    @Test
    fun `export empty list returns valid JSON`() {
        val result = exporter.export(emptyList(), ExportFormat.JSON)
        val json = JSONObject(result)
        assertThat(json.getInt("totalAnnotations")).isEqualTo(0)
        assertThat(json.getJSONArray("annotations").length()).isEqualTo(0)
    }

    // ─── Plain Text Format ──────────────────────────────────────────────────

    @Test
    fun `plain text contains book title and author`() {
        val result = exporter.export(listOf(sampleBookmark), ExportFormat.PLAIN_TEXT)
        assertThat(result).contains("Book: The Great Gatsby")
        assertThat(result).contains("Author: F. Scott Fitzgerald")
    }

    @Test
    fun `plain text contains annotation count`() {
        val result = exporter.export(listOf(sampleBookmark, sampleBookmark2), ExportFormat.PLAIN_TEXT)
        assertThat(result).contains("Annotations (2)")
    }

    @Test
    fun `plain text shows 1-based page number`() {
        val result = exporter.export(listOf(sampleBookmark), ExportFormat.PLAIN_TEXT)
        // pageIndex=5 should display as "Page 6"
        assertThat(result).contains("Page 6")
    }

    @Test
    fun `plain text includes text snippet`() {
        val result = exporter.export(listOf(sampleBookmark), ExportFormat.PLAIN_TEXT)
        assertThat(result).contains("boats against the current")
    }

    @Test
    fun `plain text includes note`() {
        val result = exporter.export(listOf(sampleBookmark), ExportFormat.PLAIN_TEXT)
        assertThat(result).contains("Beautiful closing line")
    }

    @Test
    fun `plain text includes date`() {
        val result = exporter.export(listOf(sampleBookmark), ExportFormat.PLAIN_TEXT)
        assertThat(result).contains("2026-06-10")
    }

    @Test
    fun `plain text with multiple bookmarks shows numbered list`() {
        val result = exporter.export(listOf(sampleBookmark, sampleBookmark2), ExportFormat.PLAIN_TEXT)
        assertThat(result).contains("1. Page 6")
        assertThat(result).contains("2. Page 13")
    }

    @Test
    fun `plain text omits Text label when snippet is blank`() {
        val result = exporter.export(listOf(emptySnippetBookmark), ExportFormat.PLAIN_TEXT)
        assertThat(result).doesNotContain("Text:")
    }

    @Test
    fun `plain text omits Note label when note is blank`() {
        val result = exporter.export(listOf(emptyNoteBookmark), ExportFormat.PLAIN_TEXT)
        assertThat(result).doesNotContain("Note:")
    }

    // ─── Markdown Format ────────────────────────────────────────────────────

    @Test
    fun `markdown starts with heading`() {
        val result = exporter.export(listOf(sampleBookmark), ExportFormat.MARKDOWN)
        assertThat(result).startsWith("# Annotations: The Great Gatsby")
    }

    @Test
    fun `markdown includes author`() {
        val result = exporter.export(listOf(sampleBookmark), ExportFormat.MARKDOWN)
        assertThat(result).contains("**Author:** F. Scott Fitzgerald")
    }

    @Test
    fun `markdown includes total count`() {
        val result = exporter.export(listOf(sampleBookmark, sampleBookmark2), ExportFormat.MARKDOWN)
        assertThat(result).contains("**Total:** 2 annotation(s)")
    }

    @Test
    fun `markdown uses blockquote for text snippet`() {
        val result = exporter.export(listOf(sampleBookmark), ExportFormat.MARKDOWN)
        assertThat(result).contains("> So we beat on, boats against the current")
    }

    @Test
    fun `markdown shows page as h2`() {
        val result = exporter.export(listOf(sampleBookmark), ExportFormat.MARKDOWN)
        assertThat(result).contains("## 1. Page 6")
    }

    @Test
    fun `markdown includes note`() {
        val result = exporter.export(listOf(sampleBookmark), ExportFormat.MARKDOWN)
        assertThat(result).contains("**Note:** Beautiful closing line")
    }

    @Test
    fun `markdown uses horizontal rule between entries`() {
        val result = exporter.export(listOf(sampleBookmark, sampleBookmark2), ExportFormat.MARKDOWN)
        assertThat(result).contains("---")
    }

    @Test
    fun `markdown omits Highlighted text section when snippet blank`() {
        val result = exporter.export(listOf(emptySnippetBookmark), ExportFormat.MARKDOWN)
        assertThat(result).doesNotContain("**Highlighted text:**")
    }

    @Test
    fun `markdown omits Note section when note blank`() {
        val result = exporter.export(listOf(emptyNoteBookmark), ExportFormat.MARKDOWN)
        assertThat(result).doesNotContain("**Note:**")
    }

    @Test
    fun `markdown omits author line when blank`() {
        val noAuthor = sampleBookmark.copy(bookAuthor = "")
        val result = exporter.export(listOf(noAuthor), ExportFormat.MARKDOWN)
        assertThat(result).doesNotContain("**Author:**")
    }

    // ─── JSON Format ────────────────────────────────────────────────────────

    @Test
    fun `JSON is valid and parseable`() {
        val result = exporter.export(listOf(sampleBookmark), ExportFormat.JSON)
        val json = JSONObject(result) // Should not throw
        assertThat(json.getString("bookTitle")).isEqualTo("The Great Gatsby")
    }

    @Test
    fun `JSON contains book metadata`() {
        val result = exporter.export(listOf(sampleBookmark), ExportFormat.JSON)
        val json = JSONObject(result)
        assertThat(json.getString("bookTitle")).isEqualTo("The Great Gatsby")
        assertThat(json.getString("bookAuthor")).isEqualTo("F. Scott Fitzgerald")
        assertThat(json.getInt("totalAnnotations")).isEqualTo(1)
    }

    @Test
    fun `JSON contains exportedAt timestamp`() {
        val result = exporter.export(listOf(sampleBookmark), ExportFormat.JSON)
        val json = JSONObject(result)
        assertThat(json.getString("exportedAt")).isNotEmpty()
    }

    @Test
    fun `JSON annotations array has correct size`() {
        val result = exporter.export(listOf(sampleBookmark, sampleBookmark2), ExportFormat.JSON)
        val json = JSONObject(result)
        val annotations = json.getJSONArray("annotations")
        assertThat(annotations.length()).isEqualTo(2)
    }

    @Test
    fun `JSON annotation has all fields`() {
        val result = exporter.export(listOf(sampleBookmark), ExportFormat.JSON)
        val json = JSONObject(result)
        val annotation = json.getJSONArray("annotations").getJSONObject(0)

        assertThat(annotation.getInt("pageIndex")).isEqualTo(5)
        assertThat(annotation.getInt("page")).isEqualTo(6) // 1-based
        assertThat(annotation.getInt("chapterIndex")).isEqualTo(1)
        assertThat(annotation.getString("textSnippet")).contains("boats against the current")
        assertThat(annotation.getString("note")).isEqualTo("Beautiful closing line")
        assertThat(annotation.getString("createdAt")).isEqualTo("2026-06-10 14:30")
    }

    @Test
    fun `JSON with multiple bookmarks preserves order`() {
        val result = exporter.export(listOf(sampleBookmark, sampleBookmark2), ExportFormat.JSON)
        val json = JSONObject(result)
        val annotations = json.getJSONArray("annotations")

        assertThat(annotations.getJSONObject(0).getInt("pageIndex")).isEqualTo(5)
        assertThat(annotations.getJSONObject(1).getInt("pageIndex")).isEqualTo(12)
    }

    // ─── File Extension & MIME Type ─────────────────────────────────────────

    @Test
    fun `fileExtension returns correct extensions`() {
        assertThat(exporter.fileExtension(ExportFormat.PLAIN_TEXT)).isEqualTo("txt")
        assertThat(exporter.fileExtension(ExportFormat.MARKDOWN)).isEqualTo("md")
        assertThat(exporter.fileExtension(ExportFormat.JSON)).isEqualTo("json")
    }

    @Test
    fun `mimeType returns correct types`() {
        assertThat(exporter.mimeType(ExportFormat.PLAIN_TEXT)).isEqualTo("text/plain")
        assertThat(exporter.mimeType(ExportFormat.MARKDOWN)).isEqualTo("text/markdown")
        assertThat(exporter.mimeType(ExportFormat.JSON)).isEqualTo("application/json")
    }

    // ─── Edge Cases ─────────────────────────────────────────────────────────

    @Test
    fun `bookmark with very long text snippet is preserved fully`() {
        val longText = "A".repeat(5000)
        val longBookmark = sampleBookmark.copy(textSnippet = longText)
        val result = exporter.export(listOf(longBookmark), ExportFormat.PLAIN_TEXT)
        assertThat(result).contains(longText)
    }

    @Test
    fun `bookmark with special characters in note is handled correctly`() {
        val specialBookmark = sampleBookmark.copy(note = "Test with \"quotes\" and \nnewlines & <html>")
        val result = exporter.export(listOf(specialBookmark), ExportFormat.JSON)
        val json = JSONObject(result)
        val note = json.getJSONArray("annotations").getJSONObject(0).getString("note")
        assertThat(note).contains("quotes")
        assertThat(note).contains("<html>")
    }

    @Test
    fun `plain text export does not have trailing newline`() {
        val result = exporter.export(listOf(sampleBookmark), ExportFormat.PLAIN_TEXT)
        assertThat(result.endsWith("\n")).isFalse()
    }

    @Test
    fun `markdown export does not have trailing newline`() {
        val result = exporter.export(listOf(sampleBookmark), ExportFormat.MARKDOWN)
        assertThat(result.endsWith("\n")).isFalse()
    }

    @Test
    fun `JSON with single bookmark has totalAnnotations = 1`() {
        val result = exporter.export(listOf(sampleBookmark), ExportFormat.JSON)
        val json = JSONObject(result)
        assertThat(json.getInt("totalAnnotations")).isEqualTo(1)
    }

    @Test
    fun `export with 50 bookmarks completes without error`() {
        val manyBookmarks = (1..50).map { i ->
            sampleBookmark.copy(
                pageIndex = i,
                note = "Note $i",
                textSnippet = "Snippet $i",
            )
        }
        val result = exporter.export(manyBookmarks, ExportFormat.JSON)
        val json = JSONObject(result)
        assertThat(json.getInt("totalAnnotations")).isEqualTo(50)
        assertThat(json.getJSONArray("annotations").length()).isEqualTo(50)
    }
}
