package com.dualreader.app.domain.model

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ProductInfoTest {

    private fun makeProduct(
        id: String = "test_id",
        title: String = "Test",
        desc: String = "Desc",
        price: String = "$9.99",
        period: String = "",
        isSub: Boolean = false,
        micros: Long = 9_990_000,
        currency: String = "USD",
    ) = ProductInfo(id, title, desc, price, period, isSub, micros, currency)

    // ── Data class equality ────────────────────────────────────────

    @Test
    fun `two products with same fields are equal`() {
        val p1 = makeProduct()
        val p2 = makeProduct()
        assertEquals(p1, p2)
    }

    @Test
    fun `product with different price is not equal`() {
        val p1 = makeProduct(price = "$9.99")
        val p2 = makeProduct(price = "$19.99")
        assertFalse(p1 == p2)
    }

    @Test
    fun `product copy works correctly`() {
        val original = makeProduct(price = "$5.00")
        val copy = original.copy(price = "$10.00")
        assertEquals("$5.00", original.price)
        assertEquals("$10.00", copy.price)
    }

    // ── Product IDs (DR-248: PRO_UNLOCK removed) ───────────────────

    @Test
    fun `PREMIUM_MONTHLY is premium_monthly`() {
        assertEquals("premium_monthly", ProductIds.PREMIUM_MONTHLY)
    }

    @Test
    fun `PREMIUM_YEARLY is premium_yearly`() {
        assertEquals("premium_yearly", ProductIds.PREMIUM_YEARLY)
    }

    @Test
    fun `ALL contains exactly 2 products`() {
        assertEquals(2, ProductIds.ALL.size)
    }

    @Test
    fun `ALL contains monthly and yearly only`() {
        assertTrue(ProductIds.ALL.contains(ProductIds.PREMIUM_MONTHLY))
        assertTrue(ProductIds.ALL.contains(ProductIds.PREMIUM_YEARLY))
    }

    @Test
    fun `SUBSCRIPTIONS contains 2 products`() {
        assertEquals(2, ProductIds.SUBSCRIPTIONS.size)
    }

    @Test
    fun `SUBSCRIPTIONS contains monthly and yearly`() {
        assertTrue(ProductIds.SUBSCRIPTIONS.contains(ProductIds.PREMIUM_MONTHLY))
        assertTrue(ProductIds.SUBSCRIPTIONS.contains(ProductIds.PREMIUM_YEARLY))
    }

    @Test
    fun `ONE_TIME is empty (DR-248)`() {
        assertEquals(0, ProductIds.ONE_TIME.size)
    }

    // ── Product field semantics ────────────────────────────────────

    @Test
    fun `monthly subscription has per-month period`() {
        val product = makeProduct(id = ProductIds.PREMIUM_MONTHLY, period = "/month", isSub = true)
        assertEquals("/month", product.pricePeriod)
        assertTrue(product.isSubscription)
    }

    @Test
    fun `yearly subscription has per-year period`() {
        val product = makeProduct(id = ProductIds.PREMIUM_YEARLY, period = "/year", isSub = true)
        assertEquals("/year", product.pricePeriod)
        assertTrue(product.isSubscription)
    }
}
