package com.dualreader.app.domain.model

/**
 * Result of a purchase attempt.
 */
sealed class PurchaseResult {
    data object Success : PurchaseResult()
    data class Error(val message: String) : PurchaseResult()
    data object Cancelled : PurchaseResult()
    data object Pending : PurchaseResult()
}
