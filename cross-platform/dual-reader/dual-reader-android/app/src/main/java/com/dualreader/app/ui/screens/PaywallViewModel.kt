package com.dualreader.app.ui.screens

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.dualreader.app.domain.model.EntitlementTier
import com.dualreader.app.domain.model.ProductInfo
import com.dualreader.app.domain.model.ProductIds
import com.dualreader.app.domain.model.PurchaseResult
import com.dualreader.app.domain.repository.BillingRepository
import com.dualreader.app.util.AppLogger
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import javax.inject.Inject

data class PaywallUiState(
    val isLoading: Boolean = false,
    val entitlement: EntitlementTier = EntitlementTier.FREE,
    val monthlyProduct: ProductInfo? = null,
    val yearlyProduct: ProductInfo? = null,
    val purchaseMessage: String? = null,
    val purchaseSuccess: Boolean = false,
)

@HiltViewModel
class PaywallViewModel @Inject constructor(
    private val billingRepository: BillingRepository,
) : ViewModel() {

    private val _isLoading = MutableStateFlow(false)
    private val _purchaseMessage = MutableStateFlow<String?>(null)
    private val _purchaseSuccess = MutableStateFlow(false)

    val uiState: StateFlow<PaywallUiState> = combine(
        billingRepository.entitlement,
        billingRepository.products,
        _isLoading,
        _purchaseMessage,
        _purchaseSuccess,
    ) { entitlement, products, loading, message, success ->
        PaywallUiState(
            isLoading = loading,
            entitlement = entitlement,
            monthlyProduct = products.firstOrNull { it.productId == ProductIds.PREMIUM_MONTHLY },
            yearlyProduct = products.firstOrNull { it.productId == ProductIds.PREMIUM_YEARLY },
            purchaseMessage = message,
            purchaseSuccess = success,
        )
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), PaywallUiState())

    init {
        viewModelScope.launch {
            try {
                billingRepository.refreshPurchases()
            } catch (e: kotlinx.coroutines.CancellationException) {
                throw e // Preserve cancellation semantics
            } catch (e: Exception) {
                com.dualreader.app.util.AppLogger.e("PaywallViewModel: Failed to refresh purchases on init: ${e.message}", e)
            }
        }
    }

    fun purchase(productId: String) {
        viewModelScope.launch {
            _isLoading.value = true
            _purchaseMessage.value = null
            _purchaseSuccess.value = false

            val result = try {
                billingRepository.launchPurchaseFlow(productId)
            } catch (e: kotlinx.coroutines.CancellationException) {
                _isLoading.value = false // Reset loading state before rethrowing (DR-154)
                throw e // Preserve cancellation semantics (DR-121 pattern)
            } catch (e: Exception) {
                _isLoading.value = false
                _purchaseMessage.value = "Purchase failed: ${e.message}"
                AppLogger.e("PaywallViewModel: purchase failed: ${e.message}", e)
                return@launch
            }

            _isLoading.value = false
            when (result) {
                is PurchaseResult.Success -> {
                    _purchaseSuccess.value = true
                    _purchaseMessage.value = null
                }
                is PurchaseResult.Cancelled -> {
                    _purchaseMessage.value = null
                }
                is PurchaseResult.Error -> {
                    _purchaseMessage.value = result.message
                }
                is PurchaseResult.Pending -> {
                    _purchaseMessage.value = "Purchase pending. You'll be notified when it completes."
                }
            }
        }
    }

    fun restorePurchases() {
        viewModelScope.launch {
            _isLoading.value = true
            val tier = try {
                billingRepository.restorePurchases()
            } catch (e: kotlinx.coroutines.CancellationException) {
                _isLoading.value = false // Reset loading state before rethrowing (DR-154)
                throw e // Preserve cancellation semantics (DR-121 pattern)
            } catch (e: Exception) {
                _isLoading.value = false
                _purchaseMessage.value = "Restore failed: ${e.message}"
                AppLogger.e("PaywallViewModel: restorePurchases failed: ${e.message}", e)
                return@launch
            }
            _isLoading.value = false
            if (tier.isPaid) {
                _purchaseSuccess.value = true
            } else {
                _purchaseMessage.value = "No previous purchases found."
            }
        }
    }

    fun clearMessage() {
        _purchaseMessage.value = null
    }
}
