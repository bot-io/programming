package com.dualreader.app.domain.services

/**
 * Pagination service — splits book text into screen-sized pages.
 *
 * Lesson from Flutter: the text sanitizer regex (r' *') inserted spaces
 * between every character. Critical lesson: TEST TEXT PROCESSING WITH
 * REAL EPUBS EARLY, not just unit test fixtures.
 *
 * In the Kotlin version, we use Android's StaticLayout for accurate
 * text measurement instead of Flutter's TextPainter approximation.
 */
interface PaginationService {
    /**
     * Paginate a block of text into pages that fit the given dimensions.
     *
     * @param text Full text to paginate
     * @param availableWidth Available width in pixels
     * @param availableHeight Available height in pixels
     * @param fontSize Font size in sp
     * @param lineHeight Line height multiplier
     * @param margins Horizontal margins in dp
     * @return List of page text strings
     */
    suspend fun paginate(
        text: String,
        availableWidth: Int,
        availableHeight: Int,
        fontSize: Float,
        lineHeight: Float = 1.5f,
        margins: Int = 16,
    ): List<String>
}
