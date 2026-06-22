package com.dualreader.app.domain.model

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class PurchaseResultTest {

    // ── Type discrimination ────────────────────────────────────────

    @Test
    fun `Success is a PurchaseResult`() {
        val result: PurchaseResult = PurchaseResult.Success
        assertTrue(result is PurchaseResult.Success)
    }

    @Test
    fun `Error is a PurchaseResult`() {
        val result: PurchaseResult = PurchaseResult.Error("fail")
        assertTrue(result is PurchaseResult.Error)
        assertFalse(result is PurchaseResult.Success)
    }

    @Test
    fun `Cancelled is a PurchaseResult`() {
        val result: PurchaseResult = PurchaseResult.Cancelled
        assertTrue(result is PurchaseResult.Cancelled)
    }

    @Test
    fun `Pending is a PurchaseResult`() {
        val result: PurchaseResult = PurchaseResult.Pending
        assertTrue(result is PurchaseResult.Pending)
    }

    // ── Error message ──────────────────────────────────────────────

    @Test
    fun `Error stores message correctly`() {
        val result = PurchaseResult.Error("Payment declined")
        assertEquals("Payment declined", result.message)
    }

    @Test
    fun `Error with empty message`() {
        val result = PurchaseResult.Error("")
        assertEquals("", result.message)
    }

    @Test
    fun `Error with null-like message`() {
        val result = PurchaseResult.Error("null")
        assertEquals("null", result.message)
    }

    // ── Exhaustive when ────────────────────────────────────────────

    @Test
    fun `when expression covers all cases`() {
        val results = listOf(
            PurchaseResult.Success,
            PurchaseResult.Error("err"),
            PurchaseResult.Cancelled,
            PurchaseResult.Pending,
        )
        val labels = results.map { result ->
            when (result) {
                is PurchaseResult.Success -> "success"
                is PurchaseResult.Error -> "error"
                is PurchaseResult.Cancelled -> "cancelled"
                is PurchaseResult.Pending -> "pending"
            }
        }
        assertEquals(listOf("success", "error", "cancelled", "pending"), labels)
    }

    // ── Equality ───────────────────────────────────────────────────

    @Test
    fun `Success equality`() {
        assertEquals(PurchaseResult.Success, PurchaseResult.Success)
    }

    @Test
    fun `Cancelled equality`() {
        assertEquals(PurchaseResult.Cancelled, PurchaseResult.Cancelled)
    }

    @Test
    fun `Pending equality`() {
        assertEquals(PurchaseResult.Pending, PurchaseResult.Pending)
    }

    @Test
    fun `Error equality with same message`() {
        assertEquals(PurchaseResult.Error("err"), PurchaseResult.Error("err"))
    }

    @Test
    fun `Error inequality with different message`() {
        assertFalse(PurchaseResult.Error("a") == PurchaseResult.Error("b"))
    }
}
