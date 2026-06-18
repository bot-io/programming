package com.dualreader.app.domain.model

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Tests for EntitlementTier — entitlement tier properties and parsing.
 *
 * Verifies:
 * - Each tier has correct translation limits and library caps
 * - isPaid flag distinguishes free from paid tiers
 * - fromName parsing handles valid names, null, and invalid strings
 */
class EntitlementTierTest {

    // --- Daily translation limits ---

    @Test
    fun `FREE has 10 page daily limit`() {
        assertEquals(10, EntitlementTier.FREE.dailyTranslationLimit)
    }

    @Test
    fun `PRO has 50 page daily limit`() {
        assertEquals(50, EntitlementTier.PRO.dailyTranslationLimit)
    }

    @Test
    fun `PREMIUM has unlimited daily translation`() {
        assertEquals(Int.MAX_VALUE, EntitlementTier.PREMIUM.dailyTranslationLimit)
    }

    // --- Library book caps ---

    @Test
    fun `FREE can have only 1 book in library`() {
        assertEquals(1, EntitlementTier.FREE.maxLibraryBooks)
    }

    @Test
    fun `PRO has unlimited library books`() {
        assertEquals(Int.MAX_VALUE, EntitlementTier.PRO.maxLibraryBooks)
    }

    @Test
    fun `PREMIUM has unlimited library books`() {
        assertEquals(Int.MAX_VALUE, EntitlementTier.PREMIUM.maxLibraryBooks)
    }

    // --- isPaid flag ---

    @Test
    fun `FREE is not paid`() {
        assertFalse(EntitlementTier.FREE.isPaid)
    }

    @Test
    fun `PRO is paid`() {
        assertTrue(EntitlementTier.PRO.isPaid)
    }

    @Test
    fun `PREMIUM is paid`() {
        assertTrue(EntitlementTier.PREMIUM.isPaid)
    }

    // --- fromName parsing ---

    @Test
    fun `fromName parses FREE`() {
        assertEquals(EntitlementTier.FREE, EntitlementTier.fromName("FREE"))
    }

    @Test
    fun `fromName parses PRO`() {
        assertEquals(EntitlementTier.PRO, EntitlementTier.fromName("PRO"))
    }

    @Test
    fun `fromName parses PREMIUM`() {
        assertEquals(EntitlementTier.PREMIUM, EntitlementTier.fromName("PREMIUM"))
    }

    @Test
    fun `fromName returns FREE for null`() {
        assertEquals(EntitlementTier.FREE, EntitlementTier.fromName(null))
    }

    @Test
    fun `fromName returns FREE for unknown string`() {
        assertEquals(EntitlementTier.FREE, EntitlementTier.fromName("UNKNOWN"))
    }

    @Test
    fun `fromName returns FREE for lowercase`() {
        // Case-sensitive — lowercase should fall back to FREE
        assertEquals(EntitlementTier.FREE, EntitlementTier.fromName("free"))
    }

    @Test
    fun `fromName returns FREE for empty string`() {
        assertEquals(EntitlementTier.FREE, EntitlementTier.fromName(""))
    }
}
