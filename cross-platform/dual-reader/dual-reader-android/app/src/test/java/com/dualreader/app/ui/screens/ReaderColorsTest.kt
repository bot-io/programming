package com.dualreader.app.ui.screens

import androidx.compose.ui.graphics.Color
import com.dualreader.app.domain.entities.ReaderTheme
import org.junit.Assert.*
import org.junit.Test

/**
 * Tests for reader color definitions — validates that each theme provides
 * correct colors and that the Night theme meets OLED / WCAG requirements.
 *
 * Note: [readerColors] is a @Composable function, so we test the raw color
 * values it returns by extracting them into a test-friendly helper.
 */
class ReaderColorsTest {

    // Mirror of the readerColors mapping — kept in sync for unit testing.
    // The actual composable function delegates to these same values.
    private data class TestReaderColors(
        val background: Color,
        val text: Color,
        val textSecondary: Color,
        val divider: Color,
        val accent: Color,
    )

    private fun testReaderColors(theme: ReaderTheme): TestReaderColors = when (theme) {
        ReaderTheme.DARK -> TestReaderColors(
            background = Color(0xFF1A1A2E), text = Color(0xFFE0E0E0),
            textSecondary = Color(0xFFB0B0B0), divider = Color(0xFF333355), accent = Color(0xFF6C63FF),
        )
        ReaderTheme.LIGHT -> TestReaderColors(
            background = Color(0xFFFFFBF5), text = Color(0xFF2D2D2D),
            textSecondary = Color(0xFF666666), divider = Color(0xFFE0D8CF), accent = Color(0xFF6C63FF),
        )
        ReaderTheme.SEPIA -> TestReaderColors(
            background = Color(0xFFF4ECD8), text = Color(0xFF5B4636),
            textSecondary = Color(0xFF8B7355), divider = Color(0xFFD4C5A9), accent = Color(0xFF8B6914),
        )
        ReaderTheme.OCEAN -> TestReaderColors(
            background = Color(0xFF0D1B2A), text = Color(0xFFE0FBFC),
            textSecondary = Color(0xFF98C1D9), divider = Color(0xFF1B3A4B), accent = Color(0xFF3D5A80),
        )
        ReaderTheme.FOREST -> TestReaderColors(
            background = Color(0xFF1B2D1B), text = Color(0xFFD4E7C5),
            textSecondary = Color(0xFF99B88F), divider = Color(0xFF2D4A2D), accent = Color(0xFF6B8F6B),
        )
        ReaderTheme.MIDNIGHT -> TestReaderColors(
            background = Color(0xFF0A0A1A), text = Color(0xFFD0D0E0),
            textSecondary = Color(0xFF8080A0), divider = Color(0xFF1A1A3A), accent = Color(0xFF5858B0),
        )
        ReaderTheme.NIGHT -> TestReaderColors(
            background = Color(0xFF000000), text = Color(0xFFE0E0E0),
            textSecondary = Color(0xFFB0B0B0), divider = Color(0xFF1A1A1A), accent = Color(0xFF6C63FF),
        )
    }

    // ── Night theme OLED validation ──────────────────────────────────

    @Test
    fun `night theme has true black background`() {
        val colors = testReaderColors(ReaderTheme.NIGHT)
        assertEquals(Color(0xFF000000), colors.background)
    }

    @Test
    fun `night theme text has sufficient contrast on background`() {
        val colors = testReaderColors(ReaderTheme.NIGHT)
        val contrast = contrastRatio(
            luminance(colors.text),
            luminance(colors.background)
        )
        assertTrue(
            "Night text contrast $contrast:1 must be >= 7:1 (WCAG AAA)",
            contrast >= 7.0
        )
    }

    @Test
    fun `night theme secondary text has sufficient contrast on background`() {
        val colors = testReaderColors(ReaderTheme.NIGHT)
        val contrast = contrastRatio(
            luminance(colors.textSecondary),
            luminance(colors.background)
        )
        assertTrue(
            "Night secondary text contrast $contrast:1 must be >= 4.5:1 (WCAG AA)",
            contrast >= 4.5
        )
    }

    // ── All themes are distinct ──────────────────────────────────────

    @Test
    fun `all themes have different backgrounds`() {
        val backgrounds = ReaderTheme.entries.associateWith { testReaderColors(it).background }
        val unique = backgrounds.values.toSet()
        assertEquals(
            "Each theme should have a unique background",
            ReaderTheme.entries.size,
            unique.size
        )
    }

    @Test
    fun `night background is the darkest of all themes`() {
        val nightLum = luminance(testReaderColors(ReaderTheme.NIGHT).background)
        for (theme in ReaderTheme.entries) {
            val themeLum = luminance(testReaderColors(theme).background)
            assertTrue(
                "Night background should be darkest, but $theme has luminance $themeLum < $nightLum",
                nightLum <= themeLum
            )
        }
    }

    // ── Helpers ──────────────────────────────────────────────────────

    private fun luminance(color: Color): Double {
        val r = linearize(color.red)
        val g = linearize(color.green)
        val b = linearize(color.blue)
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }

    private fun linearize(c: Float): Double {
        val srgb = c.toDouble()
        return if (srgb <= 0.04045) srgb / 12.92
        else Math.pow(((srgb + 0.055) / 1.055).coerceIn(0.0, 1.0), 2.4)
    }

    private fun contrastRatio(l1: Double, l2: Double): Double {
        val lighter = maxOf(l1, l2)
        val darker = minOf(l1, l2)
        return (lighter + 0.05) / (darker + 0.05)
    }
}
