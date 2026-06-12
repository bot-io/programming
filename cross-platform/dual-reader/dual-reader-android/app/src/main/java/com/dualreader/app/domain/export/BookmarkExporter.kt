package com.dualreader.app.domain.export

import org.json.JSONArray
import org.json.JSONObject
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter

/**
 * Formats a list of [ExportableBookmark] into various export formats.
 *
 * Pure Kotlin — no Android framework dependencies, fully testable.
 */
class BookmarkExporter {

    private val dateFormatter = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm")

    /**
     * Export bookmarks in the given [format].
     * Returns the formatted string ready to be written to a file.
     */
    fun export(bookmarks: List<ExportableBookmark>, format: ExportFormat): String {
        if (bookmarks.isEmpty()) return emptyExport(format)
        return when (format) {
            ExportFormat.PLAIN_TEXT -> exportPlainText(bookmarks)
            ExportFormat.MARKDOWN -> exportMarkdown(bookmarks)
            ExportFormat.JSON -> exportJson(bookmarks)
        }
    }

    /**
     * Returns the file extension for a given format.
     */
    fun fileExtension(format: ExportFormat): String = when (format) {
        ExportFormat.PLAIN_TEXT -> "txt"
        ExportFormat.MARKDOWN -> "md"
        ExportFormat.JSON -> "json"
    }

    /**
     * Returns a MIME type for the format.
     */
    fun mimeType(format: ExportFormat): String = when (format) {
        ExportFormat.PLAIN_TEXT -> "text/plain"
        ExportFormat.MARKDOWN -> "text/markdown"
        ExportFormat.JSON -> "application/json"
    }

    // ─── Plain Text ─────────────────────────────────────────────────────────

    private fun exportPlainText(bookmarks: List<ExportableBookmark>): String {
        val sb = StringBuilder()
        val book = bookmarks.first()
        sb.appendLine("Book: ${book.bookTitle}")
        sb.appendLine("Author: ${book.bookAuthor}")
        sb.appendLine("Exported: ${formatTimestamp(LocalDateTime.now())}")
        sb.appendLine()
        sb.appendLine("Annotations (${bookmarks.size})")
        sb.appendLine("─".repeat(40))

        bookmarks.forEachIndexed { i, bm ->
            sb.appendLine()
            sb.appendLine("${i + 1}. Page ${bm.pageIndex + 1}")
            if (bm.textSnippet.isNotBlank()) {
                sb.appendLine("   Text: ${bm.textSnippet}")
            }
            if (bm.note.isNotBlank()) {
                sb.appendLine("   Note: ${bm.note}")
            }
            sb.appendLine("   Date: ${formatTimestamp(bm.createdAt)}")
        }

        return sb.toString().trimEnd()
    }

    // ─── Markdown ───────────────────────────────────────────────────────────

    private fun exportMarkdown(bookmarks: List<ExportableBookmark>): String {
        val sb = StringBuilder()
        val book = bookmarks.first()

        sb.appendLine("# Annotations: ${book.bookTitle}")
        if (book.bookAuthor.isNotBlank()) {
            sb.appendLine("**Author:** ${book.bookAuthor}  ")
        }
        sb.appendLine("**Exported:** ${formatTimestamp(LocalDateTime.now())}  ")
        sb.appendLine("**Total:** ${bookmarks.size} annotation(s)")
        sb.appendLine()

        bookmarks.forEachIndexed { i, bm ->
            sb.appendLine("## ${i + 1}. Page ${bm.pageIndex + 1}")
            sb.appendLine()
            sb.appendLine("- **Date:** ${formatTimestamp(bm.createdAt)}")
            if (bm.textSnippet.isNotBlank()) {
                sb.appendLine("- **Highlighted text:**")
                sb.appendLine()
                sb.appendLine("> ${bm.textSnippet}")
                sb.appendLine()
            }
            if (bm.note.isNotBlank()) {
                sb.appendLine("- **Note:** ${bm.note}")
            }
            sb.appendLine()
            sb.appendLine("---")
            sb.appendLine()
        }

        return sb.toString().trimEnd()
    }

    // ─── JSON ───────────────────────────────────────────────────────────────

    private fun exportJson(bookmarks: List<ExportableBookmark>): String {
        val root = JSONObject()
        val book = bookmarks.first()

        root.put("bookTitle", book.bookTitle)
        root.put("bookAuthor", book.bookAuthor)
        root.put("exportedAt", formatTimestamp(LocalDateTime.now()))
        root.put("totalAnnotations", bookmarks.size)

        val annotationsArray = JSONArray()
        bookmarks.forEach { bm ->
            val obj = JSONObject().apply {
                put("pageIndex", bm.pageIndex)
                put("page", bm.pageIndex + 1) // 1-based for human readability
                put("chapterIndex", bm.chapterIndex)
                put("textSnippet", bm.textSnippet)
                put("note", bm.note)
                put("createdAt", formatTimestamp(bm.createdAt))
            }
            annotationsArray.put(obj)
        }
        root.put("annotations", annotationsArray)

        return root.toString(2)
    }

    // ─── Helpers ────────────────────────────────────────────────────────────

    private fun emptyExport(format: ExportFormat): String = when (format) {
        ExportFormat.PLAIN_TEXT -> "No annotations to export."
        ExportFormat.MARKDOWN -> "# No annotations to export"
        ExportFormat.JSON -> """{"annotations":[],"totalAnnotations":0}"""
    }

    private fun formatTimestamp(dateTime: LocalDateTime): String =
        dateTime.format(dateFormatter)
}
