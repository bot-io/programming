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
 * DR-248: PRO one-time removed. Two-tier pricing: subscription only.
 * Must match the in-app products configured in Play Console.
 */
object ProductIds {
    const val PREMIUM_MONTHLY = "premium_monthly"   // Monthly subscription — $5.99/mo
    const val PREMIUM_YEARLY = "premium_yearly"     // Annual subscription — $39.99/yr (7-day free trial)

    val ALL = listOf(PREMIUM_MONTHLY, PREMIUM_YEARLY)
    val SUBSCRIPTIONS = listOf(PREMIUM_MONTHLY, PREMIUM_YEARLY)
    val ONE_TIME = emptyList<String>()
}
