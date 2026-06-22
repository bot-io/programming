package com.dualreader.app.ui.screens

import androidx.compose.ui.graphics.Color
import com.dualreader.app.domain.entities.ReaderTheme
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Tests for reader color definitions — validates that each theme provides
 * correct colors and that the Night theme meets OLED / WCAG requirements.
 *
 * IMPORTANT: these tests call the *real* [readerColors] production function
 * (no longer a hand-maintained mirror copy). `readerColors` is intentionally a
 * pure, non-@Composable function so it can be invoked directly from a JVM test.
 * If a color value changes in production, these assertions will fail — that is
 * exactly the regression safety the previous mirror-copy approach lacked.
 */
class ReaderColorsTest {

    // ── Exact color values per theme (regression guard) ─────────────
    // Asserting the actual ARGB values returned by the production function.

    @Test
    fun `DARK theme returns expected colors`() {
        val c = readerColors(ReaderTheme.DARK)
        assertEquals(Color(0xFF1A1A2E), c.background)
        assertEquals(Color(0xFFE0E0E0), c.text)
        assertEquals(Color(0xFFB0B0B0), c.textSecondary)
        assertEquals(Color(0xFF333355), c.divider)
        assertEquals(Color(0xFF6C63FF), c.accent)
    }

    @Test
    fun `LIGHT theme returns expected colors`() {
        val c = readerColors(ReaderTheme.LIGHT)
        assertEquals(Color(0xFFFFFBF5), c.background)
        assertEquals(Color(0xFF2D2D2D), c.text)
        assertEquals(Color(0xFF666666), c.textSecondary)
        assertEquals(Color(0xFFE0D8CF), c.divider)
        assertEquals(Color(0xFF6C63FF), c.accent)
    }

    @Test
    fun `SEPIA theme returns expected colors`() {
        val c = readerColors(ReaderTheme.SEPIA)
        assertEquals(Color(0xFFF4ECD8), c.background)
        assertEquals(Color(0xFF5B4636), c.text)
        assertEquals(Color(0xFF8B7355), c.textSecondary)
        assertEquals(Color(0xFFD4C5A9), c.divider)
        assertEquals(Color(0xFF8B6914), c.accent)
    }

    @Test
    fun `OCEAN theme returns expected colors`() {
        val c = readerColors(ReaderTheme.OCEAN)
        assertEquals(Color(0xFF0D1B2A), c.background)
        assertEquals(Color(0xFFE0FBFC), c.text)
        assertEquals(Color(0xFF98C1D9), c.textSecondary)
        assertEquals(Color(0xFF1B3A4B), c.divider)
        assertEquals(Color(0xFF3D5A80), c.accent)
    }

    @Test
    fun `FOREST theme returns expected colors`() {
        val c = readerColors(ReaderTheme.FOREST)
        assertEquals(Color(0xFF1B2D1B), c.background)
        assertEquals(Color(0xFFD4E7C5), c.text)
        assertEquals(Color(0xFF99B88F), c.textSecondary)
        assertEquals(Color(0xFF2D4A2D), c.divider)
        assertEquals(Color(0xFF6B8F6B), c.accent)
    }

    @Test
    fun `MIDNIGHT theme returns expected colors`() {
        val c = readerColors(ReaderTheme.MIDNIGHT)
        assertEquals(Color(0xFF0A0A1A), c.background)
        assertEquals(Color(0xFFD0D0E0), c.text)
        assertEquals(Color(0xFF8080A0), c.textSecondary)
        assertEquals(Color(0xFF1A1A3A), c.divider)
        assertEquals(Color(0xFF5858B0), c.accent)
    }

    @Test
    fun `NIGHT theme returns expected colors`() {
        val c = readerColors(ReaderTheme.NIGHT)
        assertEquals(Color(0xFF000000), c.background)
        assertEquals(Color(0xFFE0E0E0), c.text)
        assertEquals(Color(0xFFB0B0B0), c.textSecondary)
        assertEquals(Color(0xFF1A1A1A), c.divider)
        assertEquals(Color(0xFF6C63FF), c.accent)
    }

    @Test
    fun `every theme is covered by an explicit test`() {
        // Ensure a future addition to ReaderTheme is not silently untested.
        val tested = setOf(
            ReaderTheme.DARK, ReaderTheme.LIGHT, ReaderTheme.SEPIA,
            ReaderTheme.OCEAN, ReaderTheme.FOREST, ReaderTheme.MIDNIGHT,
            ReaderTheme.NIGHT,
        )
        assertEquals(
            "New ReaderTheme entry added — add an explicit color-value test for it",
            ReaderTheme.entries.toSet(),
            tested,
        )
    }

    // ── Night theme OLED validation ──────────────────────────────────

    @Test
    fun `night theme has true black background`() {
        assertEquals(Color(0xFF000000), readerColors(ReaderTheme.NIGHT).background)
    }

    @Test
    fun `night theme text has sufficient contrast on background`() {
        val c = readerColors(ReaderTheme.NIGHT)
        val contrast = contrastRatio(luminance(c.text), luminance(c.background))
        assertTrue(
            "Night text contrast $contrast:1 must be >= 7:1 (WCAG AAA)",
            contrast >= 7.0,
        )
    }

    @Test
    fun `night theme secondary text has sufficient contrast on background`() {
        val c = readerColors(ReaderTheme.NIGHT)
        val contrast = contrastRatio(luminance(c.textSecondary), luminance(c.background))
        assertTrue(
            "Night secondary text contrast $contrast:1 must be >= 4.5:1 (WCAG AA)",
            contrast >= 4.5,
        )
    }

    // ── All themes are distinct ──────────────────────────────────────

    @Test
    fun `all themes have different backgrounds`() {
        val backgrounds = ReaderTheme.entries.associateWith { readerColors(it).background }
        val unique = backgrounds.values.toSet()
        assertEquals(
            "Each theme should have a unique background",
            ReaderTheme.entries.size,
            unique.size,
        )
    }

    @Test
    fun `night background is the darkest of all themes`() {
        val nightLum = luminance(readerColors(ReaderTheme.NIGHT).background)
        for (theme in ReaderTheme.entries) {
            val themeLum = luminance(readerColors(theme).background)
            assertTrue(
                "Night background should be darkest, but $theme has luminance $themeLum < $nightLum",
                nightLum <= themeLum,
            )
        }
    }

    @Test
    fun `dark themes have darker backgrounds than light themes`() {
        // Sanity: dark/night/midnight/ocean/forest should all be darker than light/sepia.
        val lightBg = luminance(readerColors(ReaderTheme.LIGHT).background)
        for (dark in listOf(
            ReaderTheme.DARK, ReaderTheme.NIGHT, ReaderTheme.MIDNIGHT,
            ReaderTheme.OCEAN, ReaderTheme.FOREST,
        )) {
            assertTrue(
                "$dark background should be darker than LIGHT",
                luminance(readerColors(dark).background) < lightBg,
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
