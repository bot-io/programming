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
    fun `PREMIUM has unlimited daily translations`() {
        assertEquals(Int.MAX_VALUE, EntitlementTier.PREMIUM.dailyTranslationLimit)
    }

    // ── maxLibraryBooks ────────────────────────────────────────────

    @Test
    fun `FREE can have 1 library book`() {
        assertEquals(1, EntitlementTier.FREE.maxLibraryBooks)
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
    fun `PREMIUM is paid`() {
        assertTrue(EntitlementTier.PREMIUM.isPaid)
    }

    // ── DR-248: New properties ─────────────────────────────────────

    @Test
    fun `FREE does not have priority model`() {
        assertFalse(EntitlementTier.FREE.hasPriorityModel)
    }

    @Test
    fun `PREMIUM has priority model`() {
        assertTrue(EntitlementTier.PREMIUM.hasPriorityModel)
    }

    @Test
    fun `FREE does not have history and export`() {
        assertFalse(EntitlementTier.FREE.hasHistoryAndExport)
    }

    @Test
    fun `PREMIUM has history and export`() {
        assertTrue(EntitlementTier.PREMIUM.hasHistoryAndExport)
    }

    // ── fromName ───────────────────────────────────────────────────

    @Test
    fun `fromName FREE returns FREE`() {
        assertEquals(EntitlementTier.FREE, EntitlementTier.fromName("FREE"))
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

    // DR-248: PRO tier removed — fromName("PRO") now returns FREE for backward compat
    @Test
    fun `fromName PRO returns FREE (DR-248 backward compat)`() {
        assertEquals(EntitlementTier.FREE, EntitlementTier.fromName("PRO"))
    }

    // ── Progression ────────────────────────────────────────────────

    @Test
    fun `FREE limit less than PREMIUM limit`() {
        assertTrue(EntitlementTier.FREE.dailyTranslationLimit < EntitlementTier.PREMIUM.dailyTranslationLimit)
    }

    @Test
    fun `enum has exactly 2 tiers`() {
        assertEquals(2, EntitlementTier.entries.size)
    }
}
