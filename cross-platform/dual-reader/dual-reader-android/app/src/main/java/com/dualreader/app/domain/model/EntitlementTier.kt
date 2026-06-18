package com.dualreader.app.domain.model

/**
 * User entitlement tier — controls translation quota and features.
 *
 * - FREE: 10 pages/day AI translation, 1 book in library
 * - PRO: 50 pages/day, unlimited books (one-time purchase)
 * - PREMIUM: unlimited translation, priority model (subscription)
 */
enum class EntitlementTier {
    FREE,
    PRO,
    PREMIUM;

    val dailyTranslationLimit: Int
        get() = when (this) {
            FREE -> 10
            PRO -> 50
            PREMIUM -> Int.MAX_VALUE
        }

    val maxLibraryBooks: Int
        get() = when (this) {
            FREE -> 1
            PRO -> Int.MAX_VALUE
            PREMIUM -> Int.MAX_VALUE
        }

    val isPaid: Boolean
        get() = this != FREE

    companion object {
        fun fromName(name: String?): EntitlementTier =
            entries.firstOrNull { it.name == name } ?: FREE
    }
}
