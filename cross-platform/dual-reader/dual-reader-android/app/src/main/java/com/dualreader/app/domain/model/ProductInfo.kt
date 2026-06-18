package com.dualreader.app.domain.model

/**
 * Product info for paywall display.
 * Populated from Google Play BillingClient product details.
 */
data class ProductInfo(
    val productId: String,
    val title: String,
    val description: String,
    val price: String,           // Formatted price e.g. "$2.99"
    val pricePeriod: String,     // e.g. "/month", "/year", or "" for one-time
    val isSubscription: Boolean,
    val rawPriceAmountMicros: Long,
    val rawCurrency: String,
)

/**
 * Known product IDs in Google Play Console.
 * Must match the in-app products configured in Play Console.
 */
object ProductIds {
    const val PRO_UNLOCK = "pro_unlock"            // One-time purchase
    const val PREMIUM_MONTHLY = "premium_monthly"   // Monthly subscription
    const val PREMIUM_YEARLY = "premium_yearly"     // Annual subscription

    val ALL = listOf(PRO_UNLOCK, PREMIUM_MONTHLY, PREMIUM_YEARLY)
    val SUBSCRIPTIONS = listOf(PREMIUM_MONTHLY, PREMIUM_YEARLY)
    val ONE_TIME = listOf(PRO_UNLOCK)
}
