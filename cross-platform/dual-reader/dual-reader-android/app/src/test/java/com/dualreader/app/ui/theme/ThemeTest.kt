package com.dualreader.app.ui.theme

import com.dualreader.app.domain.entities.ReaderTheme
import org.junit.Assert.*
import org.junit.Test

class ThemeTest {

    // ── Night theme color scheme ──────────────────────────────────────

    @Test
    fun `night color scheme has true black background`() {
        val scheme = NightColorScheme
        // #000000 = true black for OLED
        assertEquals(0xFF000000UL, scheme.background.value.toULong().shr(32))
    }

    @Test
    fun `night color scheme has readable text on black background`() {
        val scheme = NightColorScheme
        // onBackground should be bright enough for WCAG AA on black
        // #E0E0E0 luminance ≈ 0.59 → contrast ratio ≈ 12.4:1 with #000000
        val onBgLuminance = luminance(scheme.onBackground)
        val bgLuminance = luminance(scheme.background)
        val contrast = contrastRatio(onBgLuminance, bgLuminance)
        assertTrue(
            "Night theme onBackground contrast ratio $contrast:1 should be >= 7:1 (WCAG AAA)",
            contrast >= 7.0
        )
    }

    @Test
    fun `night color scheme onSurface has sufficient contrast`() {
        val scheme = NightColorScheme
        val onSurfaceLuminance = luminance(scheme.onSurface)
        val surfaceLuminance = luminance(scheme.surface)
        val contrast = contrastRatio(onSurfaceLuminance, surfaceLuminance)
        assertTrue(
            "Night theme onSurface contrast ratio $contrast:1 should be >= 4.5:1 (WCAG AA)",
            contrast >= 4.5
        )
    }

    @Test
    fun `night color scheme onSurfaceVariant has sufficient contrast`() {
        val scheme = NightColorScheme
        val onVariantLuminance = luminance(scheme.onSurfaceVariant)
        val variantLuminance = luminance(scheme.surfaceVariant)
        val contrast = contrastRatio(onVariantLuminance, variantLuminance)
        assertTrue(
            "Night theme onSurfaceVariant contrast ratio $contrast:1 should be >= 4.5:1 (WCAG AA)",
            contrast >= 4.5
        )
    }

    // ── colorSchemeForTheme mapping ──────────────────────────────────

    @Test
    fun `colorSchemeForTheme returns NightColorScheme for NIGHT`() {
        val scheme = colorSchemeForTheme(ReaderTheme.NIGHT)
        assertSame(NightColorScheme, scheme)
    }

    @Test
    fun `colorSchemeForTheme returns DarkColorScheme for DARK`() {
        val scheme = colorSchemeForTheme(ReaderTheme.DARK)
        assertSame(DarkColorScheme, scheme)
    }

    @Test
    fun `colorSchemeForTheme returns LightColorScheme for LIGHT`() {
        val scheme = colorSchemeForTheme(ReaderTheme.LIGHT)
        assertSame(LightColorScheme, scheme)
    }

    @Test
    fun `colorSchemeForTheme returns SepiaColorScheme for SEPIA`() {
        val scheme = colorSchemeForTheme(ReaderTheme.SEPIA)
        assertSame(SepiaColorScheme, scheme)
    }

    @Test
    fun `colorSchemeForTheme returns OceanColorScheme for OCEAN`() {
        val scheme = colorSchemeForTheme(ReaderTheme.OCEAN)
        assertSame(OceanColorScheme, scheme)
    }

    @Test
    fun `colorSchemeForTheme returns ForestColorScheme for FOREST`() {
        val scheme = colorSchemeForTheme(ReaderTheme.FOREST)
        assertSame(ForestColorScheme, scheme)
    }

    @Test
    fun `colorSchemeForTheme returns MidnightColorScheme for MIDNIGHT`() {
        val scheme = colorSchemeForTheme(ReaderTheme.MIDNIGHT)
        assertSame(MidnightColorScheme, scheme)
    }

    @Test
    fun `colorSchemeForTheme covers all ReaderTheme values`() {
        // Ensure every enum value has a mapping (no crash)
        for (theme in ReaderTheme.entries) {
            val scheme = colorSchemeForTheme(theme)
            assertNotNull("colorSchemeForTheme($theme) should not be null", scheme)
        }
    }

    // ── All themes have distinct color schemes ───────────────────────

    @Test
    fun `each theme maps to a distinct color scheme`() {
        val schemes = ReaderTheme.entries.associateWith { colorSchemeForTheme(it) }
        val uniqueSchemes = schemes.values.toSet()
        assertEquals(
            "Each theme should have its own color scheme",
            ReaderTheme.entries.size,
            uniqueSchemes.size
        )
    }

    // ── Night theme distinct from Midnight and Dark ──────────────────

    @Test
    fun `night theme background is darker than midnight`() {
        val nightBg = NightColorScheme.background
        val midnightBg = MidnightColorScheme.background
        // Night should be pure black (darker than midnight's #0A0A1A)
        assertTrue(
            "Night background ($nightBg) should be darker than Midnight ($midnightBg)",
            nightBg.red + nightBg.green + nightBg.blue <= midnightBg.red + midnightBg.green + midnightBg.blue
        )
    }

    @Test
    fun `night theme background is darker than dark`() {
        val nightBg = NightColorScheme.background
        val darkBg = DarkColorScheme.background
        assertTrue(
            "Night background should be darker than Dark background",
            nightBg.red + nightBg.green + nightBg.blue <= darkBg.red + darkBg.green + darkBg.blue
        )
    }

    // ── Helper: relative luminance (sRGB) ────────────────────────────

    private fun luminance(color: androidx.compose.ui.graphics.Color): Double {
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
