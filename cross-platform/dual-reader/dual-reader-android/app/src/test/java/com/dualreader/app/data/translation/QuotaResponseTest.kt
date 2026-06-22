package com.dualreader.app.data.translation

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Test

class QuotaResponseTest {

    // ── Defaults ──────────────────────────────────────────────────

    @Test
    fun `default pagesUsed is 0`() {
        assertEquals(0, QuotaResponse().pagesUsed)
    }

    @Test
    fun `default dailyLimit is 50`() {
        assertEquals(50, QuotaResponse().dailyLimit)
    }

    @Test
    fun `default remaining is 50`() {
        assertEquals(50, QuotaResponse().remaining)
    }

    @Test
    fun `default resetAt is empty string`() {
        assertEquals("", QuotaResponse().resetAt)
    }

    // ── Custom values ─────────────────────────────────────────────

    @Test
    fun `custom pagesUsed`() {
        val resp = QuotaResponse(pagesUsed = 30)
        assertEquals(30, resp.pagesUsed)
    }

    @Test
    fun `custom dailyLimit`() {
        val resp = QuotaResponse(dailyLimit = 100)
        assertEquals(100, resp.dailyLimit)
    }

    @Test
    fun `custom remaining`() {
        val resp = QuotaResponse(remaining = 70)
        assertEquals(70, resp.remaining)
    }

    @Test
    fun `custom resetAt`() {
        val resp = QuotaResponse(resetAt = "2025-01-01T00:00:00Z")
        assertEquals("2025-01-01T00:00:00Z", resp.resetAt)
    }

    // ── Full object ───────────────────────────────────────────────

    @Test
    fun `full quota response with all fields`() {
        val resp = QuotaResponse(
            pagesUsed = 45,
            dailyLimit = 50,
            remaining = 5,
            resetAt = "2025-06-22T12:00:00Z",
        )
        assertEquals(45, resp.pagesUsed)
        assertEquals(50, resp.dailyLimit)
        assertEquals(5, resp.remaining)
        assertEquals("2025-06-22T12:00:00Z", resp.resetAt)
    }

    // ── Copy ──────────────────────────────────────────────────────

    @Test
    fun `copy preserves unchanged fields`() {
        val original = QuotaResponse(pagesUsed = 10, dailyLimit = 50, remaining = 40)
        val copy = original.copy(pagesUsed = 20)
        assertEquals(20, copy.pagesUsed)
        assertEquals(50, copy.dailyLimit) // unchanged
        assertEquals(40, copy.remaining) // unchanged
    }

    // ── Equality ──────────────────────────────────────────────────

    @Test
    fun `two default responses are equal`() {
        assertEquals(QuotaResponse(), QuotaResponse())
    }

    @Test
    fun `responses with same values are equal`() {
        val r1 = QuotaResponse(10, 50, 40, "2025-01-01")
        val r2 = QuotaResponse(10, 50, 40, "2025-01-01")
        assertEquals(r1, r2)
    }

    @Test
    fun `responses with different pagesUsed are not equal`() {
        assertNotEquals(
            QuotaResponse(pagesUsed = 10),
            QuotaResponse(pagesUsed = 20),
        )
    }

    // ── Quota exhaustion scenarios ────────────────────────────────

    @Test
    fun `quota fully used has remaining 0`() {
        val resp = QuotaResponse(pagesUsed = 50, dailyLimit = 50, remaining = 0)
        assertEquals(0, resp.remaining)
        assertEquals(resp.dailyLimit, resp.pagesUsed)
    }

    @Test
    fun `quota not used has remaining equal to dailyLimit`() {
        val resp = QuotaResponse()
        assertEquals(resp.dailyLimit, resp.remaining)
    }

    @Test
    fun `premium tier unlimited quota`() {
        val resp = QuotaResponse(
            pagesUsed = 10000,
            dailyLimit = Int.MAX_VALUE,
            remaining = Int.MAX_VALUE - 10000,
        )
        assertEquals(Int.MAX_VALUE, resp.dailyLimit)
    }
}
