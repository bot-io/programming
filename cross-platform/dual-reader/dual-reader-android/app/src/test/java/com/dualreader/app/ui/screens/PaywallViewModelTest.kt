package com.dualreader.app.ui.screens

import com.dualreader.app.domain.model.EntitlementTier
import com.dualreader.app.domain.model.ProductInfo
import com.dualreader.app.domain.model.ProductIds
import com.dualreader.app.domain.model.PurchaseResult
import com.dualreader.app.domain.repository.BillingRepository
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class PaywallViewModelTest {

    private val testDispatcher = StandardTestDispatcher()

    private lateinit var billingRepo: BillingRepository
    private lateinit var vm: PaywallViewModel

    private val entitlementFlow = MutableStateFlow(EntitlementTier.FREE)
    private val productsFlow = MutableStateFlow<List<ProductInfo>>(emptyList())

    private val monthlyProduct = ProductInfo(
        productId = ProductIds.PREMIUM_MONTHLY,
        title = "Premium Monthly",
        description = "Monthly subscription",
        price = "$5.99",
        pricePeriod = "/month",
        isSubscription = true,
        rawPriceAmountMicros = 5_990_000,
        rawCurrency = "USD",
    )

    private val yearlyProduct = ProductInfo(
        productId = ProductIds.PREMIUM_YEARLY,
        title = "Premium Yearly",
        description = "Annual subscription",
        price = "$39.99",
        pricePeriod = "/year",
        isSubscription = true,
        rawPriceAmountMicros = 39_990_000,
        rawCurrency = "USD",
    )

    @Before
    fun setUp() {
        Dispatchers.setMain(testDispatcher)

        billingRepo = mockk(relaxed = true)
        every { billingRepo.entitlement } returns entitlementFlow
        every { billingRepo.products } returns productsFlow
        coEvery { billingRepo.refreshPurchases() } returns Unit
        coEvery { billingRepo.restorePurchases() } returns EntitlementTier.FREE

        vm = PaywallViewModel(billingRepo)
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    // ── Initial State ──────────────────────────────────────────────

    @Test
    fun `initial state has isLoading false`() = runTest {
        backgroundScope.launch { vm.uiState.collect {} }
        advanceUntilIdle()
        assertFalse(vm.uiState.value.isLoading)
    }

    @Test
    fun `initial entitlement is FREE`() = runTest {
        backgroundScope.launch { vm.uiState.collect {} }
        advanceUntilIdle()
        assertEquals(EntitlementTier.FREE, vm.uiState.value.entitlement)
    }

    @Test
    fun `init calls refreshPurchases`() = runTest {
        coVerify { billingRepo.refreshPurchases() }
    }

    // ── Product Mapping ────────────────────────────────────────────

    @Test
    fun `products flow maps to monthlyProduct and yearlyProduct`() = runTest {
        backgroundScope.launch { vm.uiState.collect {} }
        advanceUntilIdle()

        productsFlow.value = listOf(monthlyProduct, yearlyProduct)
        advanceUntilIdle()

        assertEquals(monthlyProduct, vm.uiState.value.monthlyProduct)
        assertEquals(yearlyProduct, vm.uiState.value.yearlyProduct)
    }

    @Test
    fun `partial product list leaves missing products null`() = runTest {
        backgroundScope.launch { vm.uiState.collect {} }
        advanceUntilIdle()

        productsFlow.value = listOf(monthlyProduct)
        advanceUntilIdle()

        assertEquals(monthlyProduct, vm.uiState.value.monthlyProduct)
        assertNull(vm.uiState.value.yearlyProduct)
    }

    @Test
    fun `entitlement updates reflect in uiState`() = runTest {
        backgroundScope.launch { vm.uiState.collect {} }
        advanceUntilIdle()

        entitlementFlow.value = EntitlementTier.PREMIUM
        advanceUntilIdle()
        assertEquals(EntitlementTier.PREMIUM, vm.uiState.value.entitlement)
    }

    // ── purchase ───────────────────────────────────────────────────

    @Test
    fun `purchase success sets purchaseSuccess true`() = runTest {
        backgroundScope.launch { vm.uiState.collect {} }
        advanceUntilIdle()

        coEvery { billingRepo.launchPurchaseFlow(ProductIds.PREMIUM_YEARLY) } returns PurchaseResult.Success

        vm.purchase(ProductIds.PREMIUM_YEARLY)
        advanceUntilIdle()

        assertTrue(vm.uiState.value.purchaseSuccess)
        assertNull(vm.uiState.value.purchaseMessage)
        assertFalse(vm.uiState.value.isLoading)
    }

    @Test
    fun `purchase error sets error message`() = runTest {
        backgroundScope.launch { vm.uiState.collect {} }
        advanceUntilIdle()

        coEvery { billingRepo.launchPurchaseFlow(any()) } returns PurchaseResult.Error("Payment failed")

        vm.purchase(ProductIds.PREMIUM_MONTHLY)
        advanceUntilIdle()

        assertEquals("Payment failed", vm.uiState.value.purchaseMessage)
        assertFalse(vm.uiState.value.purchaseSuccess)
    }

    @Test
    fun `purchase cancelled clears message`() = runTest {
        backgroundScope.launch { vm.uiState.collect {} }
        advanceUntilIdle()

        coEvery { billingRepo.launchPurchaseFlow(any()) } returns PurchaseResult.Cancelled

        vm.purchase(ProductIds.PREMIUM_YEARLY)
        advanceUntilIdle()

        assertNull(vm.uiState.value.purchaseMessage)
        assertFalse(vm.uiState.value.purchaseSuccess)
    }

    @Test
    fun `purchase pending sets pending message`() = runTest {
        backgroundScope.launch { vm.uiState.collect {} }
        advanceUntilIdle()

        coEvery { billingRepo.launchPurchaseFlow(any()) } returns PurchaseResult.Pending

        vm.purchase(ProductIds.PREMIUM_MONTHLY)
        advanceUntilIdle()

        assertTrue(vm.uiState.value.purchaseMessage?.contains("pending") == true)
        assertFalse(vm.uiState.value.purchaseSuccess)
    }

    @Test
    fun `purchase sets isLoading during operation then clears`() = runTest {
        backgroundScope.launch { vm.uiState.collect {} }
        advanceUntilIdle()

        coEvery { billingRepo.launchPurchaseFlow(any()) } returns PurchaseResult.Success

        vm.purchase(ProductIds.PREMIUM_YEARLY)
        advanceUntilIdle()

        assertFalse(vm.uiState.value.isLoading)
    }

    // ── restorePurchases ───────────────────────────────────────────

    @Test
    fun `restorePurchases with PREMIUM tier sets success`() = runTest {
        backgroundScope.launch { vm.uiState.collect {} }
        advanceUntilIdle()

        coEvery { billingRepo.restorePurchases() } returns EntitlementTier.PREMIUM

        vm.restorePurchases()
        advanceUntilIdle()

        assertTrue(vm.uiState.value.purchaseSuccess)
        assertFalse(vm.uiState.value.isLoading)
    }

    @Test
    fun `restorePurchases with no previous purchase shows message`() = runTest {
        backgroundScope.launch { vm.uiState.collect {} }
        advanceUntilIdle()

        coEvery { billingRepo.restorePurchases() } returns EntitlementTier.FREE

        vm.restorePurchases()
        advanceUntilIdle()

        assertEquals("No previous purchases found.", vm.uiState.value.purchaseMessage)
        assertFalse(vm.uiState.value.purchaseSuccess)
    }

    // ── clearMessage ───────────────────────────────────────────────

    @Test
    fun `clearMessage nulls the purchaseMessage`() = runTest {
        backgroundScope.launch { vm.uiState.collect {} }
        advanceUntilIdle()

        coEvery { billingRepo.launchPurchaseFlow(any()) } returns PurchaseResult.Error("err")
        vm.purchase(ProductIds.PREMIUM_MONTHLY)
        advanceUntilIdle()
        org.junit.Assert.assertNotNull(vm.uiState.value.purchaseMessage)

        vm.clearMessage()
        advanceUntilIdle()
        assertNull(vm.uiState.value.purchaseMessage)
    }
}
