package com.dualreader.app.ui.screens

import com.dualreader.app.domain.model.EntitlementTier
import com.dualreader.app.domain.model.PurchaseResult
import com.dualreader.app.domain.repository.BillingRepository
import io.mockk.coEvery
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import kotlinx.coroutines.test.advanceUntilIdle
import org.junit.After
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class PaywallViewModelErrorHandlingTest {

    private lateinit var viewModel: PaywallViewModel
    private val billingRepository: BillingRepository = mockk(relaxed = true)

    private val testDispatcher = StandardTestDispatcher()
    private val entitlementFlow = MutableStateFlow(EntitlementTier.FREE)
    private val productsFlow = MutableStateFlow<List<com.dualreader.app.domain.model.ProductInfo>>(emptyList())

    @Before
    fun setup() {
        Dispatchers.setMain(testDispatcher)
        every { billingRepository.entitlement } returns entitlementFlow
        every { billingRepository.products } returns productsFlow
        coEvery { billingRepository.refreshPurchases() } returns Unit
        viewModel = PaywallViewModel(billingRepository)
        // Note: DR-160 - The uiState flow is collected in each test using backgroundScope.launch
        // because it uses SharingStarted.WhileSubscribed(5000)
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    @Test
    fun `purchase success - completes successfully and shows success message`() = runTest {
        coEvery { billingRepository.launchPurchaseFlow("premium_yearly") } returns PurchaseResult.Success

        backgroundScope.launch { viewModel.uiState.collect {} }
        advanceUntilIdle()

        viewModel.purchase("premium_yearly")
        advanceUntilIdle()

        assertFalse(viewModel.uiState.value.isLoading)
        assertTrue(viewModel.uiState.value.purchaseSuccess)
        assert(viewModel.uiState.value.purchaseMessage == null) { "purchaseMessage should be null after success" }
    }

    @Test
    fun `purchase failure - logs error, resets loading state, and shows error to user`() = runTest {
        coEvery { billingRepository.launchPurchaseFlow("premium_yearly") } throws RuntimeException("Billing API error")

        backgroundScope.launch { viewModel.uiState.collect {} }
        advanceUntilIdle()

        viewModel.purchase("premium_yearly")
        advanceUntilIdle()

        assertFalse(viewModel.uiState.value.isLoading)
        assertFalse(viewModel.uiState.value.purchaseSuccess)
        assertTrue(viewModel.uiState.value.purchaseMessage == "Purchase failed: Billing API error")
    }

    @Test
    fun `purchase CancellationException is re-thrown to preserve cancellation semantics`() = runTest {
        coEvery { billingRepository.launchPurchaseFlow("premium_yearly") } throws kotlinx.coroutines.CancellationException("User cancelled")

        backgroundScope.launch { viewModel.uiState.collect {} }
        advanceUntilIdle()

        // Act & Assert - CancellationException should propagate
        try {
            viewModel.purchase("premium_yearly")
            advanceUntilIdle()
        } catch (e: kotlinx.coroutines.CancellationException) {
            // Expected - cancellation should propagate
            kotlin.test.assertEquals("User cancelled", e.message)
        }

        // Verify isLoading was reset (DR-154)
        assertFalse("isLoading should be false after cancellation (DR-154)", viewModel.uiState.value.isLoading)
    }

    @Test
    fun `restorePurchases success - completes successfully for paid user`() = runTest {
        coEvery { billingRepository.restorePurchases() } returns EntitlementTier.PREMIUM

        backgroundScope.launch { viewModel.uiState.collect {} }
        advanceUntilIdle()

        viewModel.restorePurchases()
        advanceUntilIdle()

        assertFalse(viewModel.uiState.value.isLoading)
        assertTrue(viewModel.uiState.value.purchaseSuccess)
    }

    @Test
    fun `restorePurchases failure - logs error, resets loading state, and shows error to user`() = runTest {
        coEvery { billingRepository.restorePurchases() } throws RuntimeException("Network error")

        backgroundScope.launch { viewModel.uiState.collect {} }
        advanceUntilIdle()

        viewModel.restorePurchases()
        advanceUntilIdle()

        assertFalse(viewModel.uiState.value.isLoading)
        assertFalse(viewModel.uiState.value.purchaseSuccess)
        assertTrue(viewModel.uiState.value.purchaseMessage == "Restore failed: Network error")
    }

    @Test
    fun `restorePurchases CancellationException is re-thrown to preserve cancellation semantics`() = runTest {
        coEvery { billingRepository.restorePurchases() } throws kotlinx.coroutines.CancellationException("User cancelled")

        backgroundScope.launch { viewModel.uiState.collect {} }
        advanceUntilIdle()

        // Act & Assert - CancellationException should propagate
        try {
            viewModel.restorePurchases()
            advanceUntilIdle()
        } catch (e: kotlinx.coroutines.CancellationException) {
            // Expected - cancellation should propagate
            kotlin.test.assertEquals("User cancelled", e.message)
        }

        // Verify isLoading was reset (DR-154)
        assertFalse("isLoading should be false after cancellation (DR-154)", viewModel.uiState.value.isLoading)
    }
}