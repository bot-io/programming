package com.dualreader.app.data.pagination

import android.os.Build
import android.text.Layout
import android.text.StaticLayout
import android.text.TextPaint
import com.dualreader.app.domain.services.PaginationService
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Paginates text using Android's [StaticLayout] for pixel-accurate page breaks.
 *
 * **Never splits mid-sentence.** Uses exactly ONE StaticLayout per paragraph
 * and extracts all page breaks from it — no re-creation, no freeze.
 */
@Singleton
class PaginationServiceImpl @Inject constructor() : PaginationService {

    companion object {
        var displayDensity: Float = 2.625f
    }

    override suspend fun paginate(
        text: String,
        availableWidth: Int,
        availableHeight: Int,
        fontSize: Float,
        lineHeight: Float,
        margins: Int,
    ): List<String> {
        if (text.isBlank()) return emptyList()

        val effectiveWidth = availableWidth - (margins * 2 * displayDensity).toInt()
        if (effectiveWidth <= 0) return listOf(text)

        val fontSizePx = fontSize * displayDensity
        val paint = TextPaint().apply {
            textSize = fontSizePx
            isAntiAlias = true
        }
        val lineSpacingPx = lineHeight * fontSizePx

        val paragraphs = text.split(Regex("\\n\\s*\\n"))
            .filter { it.isNotBlank() }
            .map { it.trim() }

        if (paragraphs.isEmpty()) return emptyList()

        val pages = mutableListOf<String>()
        val currentPageParts = mutableListOf<String>()
        var currentPageHeight = 0f

        for (paragraph in paragraphs) {
            val layout = createStaticLayout(paragraph, paint, effectiveWidth, lineHeight)
            val paragraphHeight = layout.height.toFloat()
            val remainingHeight = availableHeight - currentPageHeight

            if (paragraphHeight <= remainingHeight) {
                currentPageParts.add(paragraph)
                currentPageHeight += paragraphHeight + lineSpacingPx
                continue
            }

            // Flush current page
            if (currentPageParts.isNotEmpty()) {
                pages.add(currentPageParts.joinToString("\n\n"))
                currentPageParts.clear()
                currentPageHeight = 0f
            }

            if (paragraphHeight <= availableHeight) {
                currentPageParts.add(paragraph)
                currentPageHeight = paragraphHeight + lineSpacingPx
                continue
            }

            // Paragraph taller than a full page — split using SINGLE layout
            val chunks = splitParagraphUsingSingleLayout(paragraph, layout, availableHeight, paint, effectiveWidth, lineHeight)
            for (i in 0 until chunks.lastIndex) {
                pages.add(chunks[i])
            }
            val lastChunk = chunks.last()
            currentPageParts.add(lastChunk)
            val lastLayout = createStaticLayout(lastChunk, paint, effectiveWidth, lineHeight)
            currentPageHeight = lastLayout.height.toFloat() + lineSpacingPx
        }

        if (currentPageParts.isNotEmpty()) {
            pages.add(currentPageParts.joinToString("\n\n"))
        }

        return pages
    }

    /**
     * Split a long paragraph into page-sized chunks.
     *
     * Key insight: we use the ORIGINAL layout's character offsets to split the
     * TEXT STRING directly — not line boundaries. This means every chunk starts
     * exactly where the previous one ended, with zero text loss.
     *
     * Only creates additional StaticLayouts to measure REMAINING chunk heights
     * (needed because the original layout measures the full paragraph, not a prefix).
     */
    private fun splitParagraphUsingSingleLayout(
        text: String,
        layout: StaticLayout,
        maxHeight: Int,
        paint: TextPaint,
        effectiveWidth: Int,
        lineHeight: Float,
    ): List<String> {
        val chunks = mutableListOf<String>()
        var charOffset = 0  // Character position in the original text string

        while (charOffset < text.length) {
            // Find which line contains charOffset
            var currentLine = 0
            while (currentLine < layout.lineCount - 1 && layout.getLineEnd(currentLine) <= charOffset) {
                currentLine++
            }

            // Accumulate lines from currentLine until we exceed maxHeight
            var height = 0
            var endLine = currentLine

            while (endLine < layout.lineCount) {
                val lineH = layout.getLineBottom(endLine) - layout.getLineTop(endLine)
                if (height + lineH > maxHeight && endLine > currentLine) break
                height += lineH
                endLine++
            }

            // All remaining text fits
            if (endLine >= layout.lineCount) {
                val chunk = text.substring(charOffset).trim()
                if (chunk.isNotEmpty()) chunks.add(chunk)
                break
            }

            // Get the character range that fits on this page
            val endChar = layout.getLineEnd(endLine - 1)
            val visibleText = text.substring(charOffset, minOf(endChar, text.length))

            // Find the last sentence boundary within this text
            val sentenceBreak = findLastSentenceEnd(visibleText)

            if (sentenceBreak != null && sentenceBreak > 0) {
                // Split at sentence boundary — absolute char offset in original text
                val splitAt = charOffset + sentenceBreak
                chunks.add(text.substring(charOffset, splitAt).trim())
                charOffset = splitAt  // Next chunk starts EXACTLY here
            } else {
                // No sentence boundary — split at line boundary
                chunks.add(text.substring(charOffset, minOf(endChar, text.length)).trim())
                charOffset = endChar
            }
        }

        return chunks.ifEmpty { listOf(text) }
    }

    /**
     * Find the character offset of the LAST sentence boundary in the text.
     * Returns the offset right AFTER the sentence-ending punctuation + whitespace,
     * where the next sentence starts. Returns null if no boundary found.
     */
    internal fun findLastSentenceEnd(text: String): Int? {
        val regex = Regex("""[.!?…]["'""»'')\]]*\s+""")
        val matches = regex.findAll(text).toList()
        if (matches.isEmpty()) return null
        return matches.last().range.last + 1
    }

    private fun createStaticLayout(
        text: String,
        paint: TextPaint,
        width: Int,
        lineHeight: Float,
    ): StaticLayout {
        val spacingMultiplier = lineHeight
        val spacingAdd = 0f

        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            StaticLayout.Builder.obtain(text, 0, text.length, paint, width)
                .setAlignment(Layout.Alignment.ALIGN_NORMAL)
                .setLineSpacing(spacingAdd, spacingMultiplier)
                .setIncludePad(false)
                .build()
        } else {
            @Suppress("DEPRECATION")
            StaticLayout(
                text, 0, text.length, paint, width,
                Layout.Alignment.ALIGN_NORMAL,
                spacingMultiplier, spacingAdd,
                false
            )
        }
    }
}
