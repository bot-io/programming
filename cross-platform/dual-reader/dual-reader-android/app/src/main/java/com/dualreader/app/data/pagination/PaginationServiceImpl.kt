package com.dualreader.app.data.pagination

import android.os.Build
import android.text.Layout
import android.text.StaticLayout
import android.text.TextPaint
import android.util.TypedValue
import com.dualreader.app.domain.services.PaginationService
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Paginates text using Android's [StaticLayout] for pixel-accurate page breaks.
 *
 * Converts dp/sp to px using a display metrics density supplied at construction time.
 * The density is injected from the application context.
 */
@Singleton
class PaginationServiceImpl @Inject constructor() : PaginationService {

    companion object {
        /** Density of the display. Set once from Application context. */
        var displayDensity: Float = 2.625f // default xxhdpi; overridden at startup
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

        // Split text into paragraphs first
        val paragraphs = text.split(Regex("\\n\\s*\\n"))
            .filter { it.isNotBlank() }

        val pages = mutableListOf<String>()
        val currentPageParagraphs = mutableListOf<String>()
        var currentPageHeight = 0f

        for (paragraph in paragraphs) {
            val layout = createStaticLayout(paragraph.trim(), paint, effectiveWidth, lineHeight)
            val paragraphHeight = layout.height.toFloat()

            if (currentPageHeight + paragraphHeight > availableHeight && currentPageParagraphs.isNotEmpty()) {
                // Current page is full, save it
                pages.add(currentPageParagraphs.joinToString("\n\n"))
                currentPageParagraphs.clear()
                currentPageHeight = 0f
            }

            // If a single paragraph is taller than a full page, split it
            if (paragraphHeight > availableHeight && currentPageHeight == 0f) {
                splitLongParagraph(paragraph.trim(), paint, effectiveWidth, availableHeight, lineHeight)
                    .forEach { pages.add(it) }
            } else {
                currentPageParagraphs.add(paragraph.trim())
                currentPageHeight += paragraphHeight + (lineHeight * fontSizePx) // paragraph spacing
            }
        }

        // Don't forget the last page
        if (currentPageParagraphs.isNotEmpty()) {
            pages.add(currentPageParagraphs.joinToString("\n\n"))
        }

        return pages
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

    /**
     * Splits a single paragraph that's taller than a full page into multiple
     * page-sized chunks by breaking at line boundaries.
     */
    private fun splitLongParagraph(
        text: String,
        paint: TextPaint,
        width: Int,
        maxHeight: Int,
        lineHeight: Float,
    ): List<String> {
        val layout = createStaticLayout(text, paint, width, lineHeight)
        val totalLines = layout.lineCount
        val pages = mutableListOf<String>()
        var startLine = 0

        while (startLine < totalLines) {
            var endLine = startLine
            var height = 0

            while (endLine < totalLines) {
                val lineHeightPx = layout.getLineBottom(endLine) - layout.getLineTop(endLine)
                if (height + lineHeightPx > maxHeight && endLine > startLine) break
                height += lineHeightPx
                endLine++
            }

            val startChar = layout.getLineStart(startLine)
            val endChar = layout.getLineEnd(endLine - 1)
            pages.add(text.substring(startChar, endChar).trim())
            startLine = endLine
        }

        return pages
    }
}
