package com.dualreader.app.domain.model

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class EntitlementTierTest {

    // ── dailyTranslationLimit ──────────────────────────────────────

    @Test
    fun `FREE has 10 daily translations`() {
        assertEquals(10, EntitlementTier.FREE.dailyTranslationLimit)
    }

    @Test
    fun `PRO has 50 daily translations`() {
        assertEquals(50, EntitlementTier.PRO.dailyTranslationLimit)
    }

    @Test
    fun `PREMIUM has unlimited daily translations`() {
        assertEquals(Int.MAX_VALUE, EntitlementTier.PREMIUM.dailyTranslationLimit)
    }

    // ── maxLibraryBooks ────────────────────────────────────────────

    @Test
    fun `FREE can have 1 library book`() {
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

    // ── isPaid ─────────────────────────────────────────────────────

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

    // ── fromName ───────────────────────────────────────────────────

    @Test
    fun `fromName FREE returns FREE`() {
        assertEquals(EntitlementTier.FREE, EntitlementTier.fromName("FREE"))
    }

    @Test
    fun `fromName PRO returns PRO`() {
        assertEquals(EntitlementTier.PRO, EntitlementTier.fromName("PRO"))
    }

    @Test
    fun `fromName PREMIUM returns PREMIUM`() {
        assertEquals(EntitlementTier.PREMIUM, EntitlementTier.fromName("PREMIUM"))
    }

    @Test
    fun `fromName null returns FREE`() {
        assertEquals(EntitlementTier.FREE, EntitlementTier.fromName(null))
    }

    @Test
    fun `fromName unknown returns FREE`() {
        assertEquals(EntitlementTier.FREE, EntitlementTier.fromName("WHATEVER"))
    }

    @Test
    fun `fromName lowercase returns FREE (case-sensitive)`() {
        assertEquals(EntitlementTier.FREE, EntitlementTier.fromName("free"))
    }

    @Test
    fun `fromName empty string returns FREE`() {
        assertEquals(EntitlementTier.FREE, EntitlementTier.fromName(""))
    }

    // ── Progression ────────────────────────────────────────────────

    @Test
    fun `FREE limit less than PRO limit`() {
        assertTrue(EntitlementTier.FREE.dailyTranslationLimit < EntitlementTier.PRO.dailyTranslationLimit)
    }

    @Test
    fun `PRO limit less than PREMIUM limit`() {
        assertTrue(EntitlementTier.PRO.dailyTranslationLimit < EntitlementTier.PREMIUM.dailyTranslationLimit)
    }

    @Test
    fun `enum has exactly 3 tiers`() {
        assertEquals(3, EntitlementTier.entries.size)
    }
}
