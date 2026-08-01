package com.dualreader.app.domain.repository

import com.dualreader.app.domain.model.EntitlementTier
import com.dualreader.app.domain.model.ProductInfo
import com.dualreader.app.domain.model.PurchaseResult
import kotlinx.coroutines.flow.Flow

/**
 * Abstraction over Google Play Billing.
 *
 * Entitlement is derived from active purchases:
 * - Active PREMIUM subscription → PREMIUM
 * - PRO one-time purchase → PRO
 * - Nothing → FREE
 */
interface BillingRepository {

    /** Current entitlement tier, updated reactively. */
    val entitlement: Flow<EntitlementTier>

    /** All available products for the paywall. */
    val products: Flow<List<ProductInfo>>

    /** Whether the billing client is connected and ready. */
    val isConnected: Flow<Boolean>

    /** Start connection + query purchases + product details. Call on app start. */
    suspend fun initialize()

    /** Launch the Google Play purchase flow for a product. */
    suspend fun launchPurchaseFlow(productId: String): PurchaseResult

    /** Refresh purchases from Play Store (e.g. after returning from background). */
    suspend fun refreshPurchases()

    /** Restore previous purchases (called from settings). */
    suspend fun restorePurchases(): EntitlementTier

    /** Cleanup method to cancel background coroutines and release BillingClient. DR-197 */
    fun cleanup()
}
