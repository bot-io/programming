package com.dualreader.app.data.repository

import android.app.Activity
import com.android.billingclient.api.BillingClient
import com.android.billingclient.api.AcknowledgePurchaseParams
import com.android.billingclient.api.BillingClientStateListener
import com.android.billingclient.api.BillingFlowParams
import com.android.billingclient.api.BillingResult
import com.android.billingclient.api.PendingPurchasesParams
import com.android.billingclient.api.ProductDetails
import com.android.billingclient.api.ProductDetailsResponseListener
import com.android.billingclient.api.Purchase
import com.android.billingclient.api.PurchasesResponseListener
import com.android.billingclient.api.PurchasesUpdatedListener
import com.android.billingclient.api.QueryProductDetailsParams
import com.android.billingclient.api.QueryProductDetailsResult
import com.android.billingclient.api.QueryPurchasesParams
import com.dualreader.app.domain.model.EntitlementTier
import com.dualreader.app.domain.model.ProductIds
import com.dualreader.app.domain.model.ProductInfo
import com.dualreader.app.domain.model.PurchaseResult
import com.dualreader.app.domain.repository.BillingRepository
import com.dualreader.app.util.AppLogger
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import javax.inject.Inject
import javax.inject.Singleton
import kotlin.coroutines.resume

private const val TAG = "BillingRepository"

@Singleton
class BillingRepositoryImpl @Inject constructor() : BillingRepository, PurchasesUpdatedListener {

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    private var billingClient: BillingClient? = null
    private var activityRef: Activity? = null
    private var purchaseDeferred: CompletableDeferred<PurchaseResult>? = null

    private val _entitlement = MutableStateFlow(EntitlementTier.FREE)
    override val entitlement: StateFlow<EntitlementTier> = _entitlement.asStateFlow()

    private val _products = MutableStateFlow<List<ProductInfo>>(emptyList())
    override val products: StateFlow<List<ProductInfo>> = _products.asStateFlow()

    private val _isConnected = MutableStateFlow(false)
    override val isConnected: StateFlow<Boolean> = _isConnected.asStateFlow()

    fun setActivity(activity: Activity?) {
        activityRef = activity
    }

    override suspend fun initialize() {
        val activity = activityRef
            ?: throw IllegalStateException("Activity not set. Call setActivity() before initialize().")

        if (billingClient == null) {
            billingClient = BillingClient.newBuilder(activity.applicationContext)
                .setListener(this)
                .enablePendingPurchases(
                    PendingPurchasesParams.newBuilder()
                        .enableOneTimeProducts()
                        .build()
                )
                .build()
        }

        if (billingClient?.connectionState == BillingClient.ConnectionState.CONNECTED) {
            _isConnected.value = true
            return
        }

        val connectResult = CompletableDeferred<Boolean>()
        billingClient?.startConnection(object : BillingClientStateListener {
            override fun onBillingSetupFinished(billingResult: BillingResult) {
                if (billingResult.responseCode == BillingClient.BillingResponseCode.OK) {
                    _isConnected.value = true
                    scope.launch {
                        queryProductDetails()
                        refreshPurchases()
                    }
                } else {
                    _isConnected.value = false
                }
                connectResult.complete(
                    billingResult.responseCode == BillingClient.BillingResponseCode.OK
                )
            }

            override fun onBillingServiceDisconnected() {
                _isConnected.value = false
                scope.launch { initialize() }
            }
        })
        connectResult.await()
    }

    private suspend fun queryProductDetails(): List<ProductDetails> {
        val client = billingClient ?: return emptyList()

        // Billing v8 requires separate queries per product type (INAPP vs SUBS).
        // Mixing types in one call throws IllegalArgumentException.
        val oneTimeIds = ProductIds.ALL.filter { it !in ProductIds.SUBSCRIPTIONS }
        val subIds = ProductIds.ALL.filter { it in ProductIds.SUBSCRIPTIONS }

        val oneTimeDetails = if (oneTimeIds.isNotEmpty()) {
            queryProductsByType(oneTimeIds, BillingClient.ProductType.INAPP)
        } else emptyList()

        val subDetails = if (subIds.isNotEmpty()) {
            queryProductsByType(subIds, BillingClient.ProductType.SUBS)
        } else emptyList()

        val details = oneTimeDetails + subDetails
        val products = details.mapNotNull { mapToProductInfo(it) }
        _products.value = products
        return details
    }

    private suspend fun queryProductsByType(
        productIds: List<String>,
        productType: String,
    ): List<ProductDetails> {
        val client = billingClient ?: return emptyList()
        val params = QueryProductDetailsParams.newBuilder()
            .setProductList(
                productIds.map { productId ->
                    QueryProductDetailsParams.Product.newBuilder()
                        .setProductId(productId)
                        .setProductType(productType)
                        .build()
                }
            )
            .build()

        return suspendCancellableCoroutine { cont ->
            client.queryProductDetailsAsync(
                params,
                object : ProductDetailsResponseListener {
                    override fun onProductDetailsResponse(
                        billingResult: BillingResult,
                        result: QueryProductDetailsResult,
                    ) {
                        if (billingResult.responseCode == BillingClient.BillingResponseCode.OK) {
                            cont.resume(result.productDetailsList)
                        } else {
                            cont.resume(emptyList())
                        }
                    }
                }
            )
        }
    }

    private fun mapToProductInfo(details: ProductDetails): ProductInfo? {
        val isSubscription = details.productType == BillingClient.ProductType.SUBS

        return if (isSubscription) {
            val offer = details.subscriptionOfferDetails?.firstOrNull()
            val pricing = offer?.pricingPhases?.pricingPhaseList?.firstOrNull()
            if (pricing != null) {
                val period = when {
                    pricing.billingPeriod.contains("Y") -> "/year"
                    pricing.billingPeriod.contains("M") -> "/month"
                    pricing.billingPeriod.contains("W") -> "/week"
                    else -> ""
                }
                ProductInfo(
                    productId = details.productId,
                    title = details.title,
                    description = details.description,
                    price = pricing.formattedPrice,
                    pricePeriod = period,
                    isSubscription = true,
                    rawPriceAmountMicros = pricing.priceAmountMicros,
                    rawCurrency = pricing.priceCurrencyCode,
                )
            } else null
        } else {
            val oneTime = details.oneTimePurchaseOfferDetails
            if (oneTime != null) {
                ProductInfo(
                    productId = details.productId,
                    title = details.title,
                    description = details.description,
                    price = oneTime.formattedPrice,
                    pricePeriod = "",
                    isSubscription = false,
                    rawPriceAmountMicros = oneTime.priceAmountMicros,
                    rawCurrency = oneTime.priceCurrencyCode,
                )
            } else null
        }
    }

    override suspend fun launchPurchaseFlow(productId: String): PurchaseResult {
        // Guard against concurrent purchase attempts — the previous deferred must complete first.
        purchaseDeferred?.let { existing ->
            existing.await() // Wait for any in-flight purchase to resolve
        }

        val client = billingClient
        val activity = activityRef
        if (client == null || activity == null) {
            return PurchaseResult.Error("Billing not initialized")
        }
        if (!_isConnected.value) {
            initialize()
            if (!_isConnected.value) {
                return PurchaseResult.Error("Not connected to Play Store")
            }
        }

        // Fetch fresh product details for the offer token
        val params = QueryProductDetailsParams.newBuilder()
            .setProductList(
                listOf(
                    QueryProductDetailsParams.Product.newBuilder()
                        .setProductId(productId)
                        .setProductType(
                            if (productId in ProductIds.SUBSCRIPTIONS)
                                BillingClient.ProductType.SUBS
                            else
                                BillingClient.ProductType.INAPP
                        )
                        .build()
                )
            )
            .build()

        val detailsList = suspendCancellableCoroutine<List<ProductDetails>> { cont ->
            client.queryProductDetailsAsync(
                params,
                object : ProductDetailsResponseListener {
                    override fun onProductDetailsResponse(
                        billingResult: BillingResult,
                        result: QueryProductDetailsResult,
                    ) {
                        if (billingResult.responseCode == BillingClient.BillingResponseCode.OK) {
                            cont.resume(result.productDetailsList)
                        } else {
                            cont.resume(emptyList())
                        }
                    }
                }
            )
        }
        val productDetails = detailsList.firstOrNull()
            ?: return PurchaseResult.Error("Could not load product details")

        val productDetailsParams = if (productId in ProductIds.SUBSCRIPTIONS) {
            val offerToken = productDetails.subscriptionOfferDetails?.firstOrNull()?.offerToken
                ?: return PurchaseResult.Error("No offer available")
            BillingFlowParams.ProductDetailsParams.newBuilder()
                .setProductDetails(productDetails)
                .setOfferToken(offerToken)
                .build()
        } else {
            BillingFlowParams.ProductDetailsParams.newBuilder()
                .setProductDetails(productDetails)
                .build()
        }

        val flowParams = BillingFlowParams.newBuilder()
            .setProductDetailsParamsList(listOf(productDetailsParams))
            .build()

        purchaseDeferred = CompletableDeferred()
        val billingResult = client.launchBillingFlow(activity, flowParams)
        if (billingResult.responseCode != BillingClient.BillingResponseCode.OK) {
            purchaseDeferred = null
            return PurchaseResult.Error("Failed to start purchase: ${billingResult.debugMessage}")
        }

        return purchaseDeferred!!.await()
    }

    override suspend fun refreshPurchases() {
        val client = billingClient ?: return
        if (!_isConnected.value) return

        val allPurchases = mutableListOf<Purchase>()
        for (productType in listOf(BillingClient.ProductType.SUBS, BillingClient.ProductType.INAPP)) {
            val params = QueryPurchasesParams.newBuilder()
                .setProductType(productType)
                .build()
            val purchases = suspendCancellableCoroutine { cont ->
                client.queryPurchasesAsync(params) { _, purchasesList ->
                    cont.resume(purchasesList)
                }
            }
            allPurchases.addAll(purchases)
        }
        processPurchases(allPurchases)
    }

    override suspend fun restorePurchases(): EntitlementTier {
        refreshPurchases()
        return _entitlement.value
    }

    private fun processPurchases(purchases: List<Purchase>) {
        val activeProductIds = mutableSetOf<String>()
        for (purchase in purchases) {
            if (purchase.purchaseState != Purchase.PurchaseState.PURCHASED) continue
            activeProductIds.addAll(purchase.products)

            // Acknowledge purchases that haven't been acknowledged yet.
            // Google Play requires acknowledgement within 3 days or the purchase is refunded.
            if (!purchase.isAcknowledged) {
                acknowledgePurchase(purchase)
            }
        }
        val newTier = when {
            ProductIds.PREMIUM_MONTHLY in activeProductIds ||
            ProductIds.PREMIUM_YEARLY in activeProductIds -> EntitlementTier.PREMIUM
            ProductIds.PRO_UNLOCK in activeProductIds -> EntitlementTier.PRO
            else -> EntitlementTier.FREE
        }
        if (newTier != _entitlement.value) {
            _entitlement.value = newTier
        }
    }

    private fun acknowledgePurchase(purchase: Purchase) {
        val client = billingClient ?: return
        val params = AcknowledgePurchaseParams.newBuilder()
            .setPurchaseToken(purchase.purchaseToken)
            .build()
        client.acknowledgePurchase(params) { billingResult ->
            if (billingResult.responseCode == BillingClient.BillingResponseCode.OK) {
                AppLogger.i("Purchase acknowledged: ${purchase.products}")
            } else {
                AppLogger.e("Failed to acknowledge purchase: ${billingResult.debugMessage}")
            }
        }
    }

    override fun onPurchasesUpdated(
        billingResult: BillingResult,
        purchases: List<Purchase>?
    ) {
        when (billingResult.responseCode) {
            BillingClient.BillingResponseCode.OK -> {
                processPurchases(purchases ?: emptyList())
                purchaseDeferred?.complete(PurchaseResult.Success)
                purchaseDeferred = null
            }
            BillingClient.BillingResponseCode.USER_CANCELED -> {
                purchaseDeferred?.complete(PurchaseResult.Cancelled)
                purchaseDeferred = null
            }
            BillingClient.BillingResponseCode.ITEM_ALREADY_OWNED -> {
                scope.launch { refreshPurchases() }
                purchaseDeferred?.complete(PurchaseResult.Success)
                purchaseDeferred = null
            }
            else -> {
                purchaseDeferred?.complete(
                    PurchaseResult.Error(billingResult.debugMessage.ifEmpty { "Purchase failed" })
                )
                purchaseDeferred = null
            }
        }
    }
}
