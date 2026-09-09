package com.dualreader.app.domain.model

/**
 * User entitlement tier — controls translation quota and features.
 *
 * DR-248: PRO tier removed. Two-tier model: FREE + PREMIUM only.
 *
 * - FREE: 10 pages/day AI translation, 1 book in library, unlimited offline ML Kit
 * - PREMIUM: unlimited AI translation (fair-use soft cap enforced server-side, DR-250),
 *   unlimited books, priority model, history/export (subscription)
 */
enum class EntitlementTier {
    FREE,
    PREMIUM;

    val dailyTranslationLimit: Int
        get() = when (this) {
            FREE -> 10
            PREMIUM -> Int.MAX_VALUE // Soft cap enforced server-side (DR-250)
        }

    val maxLibraryBooks: Int
        get() = when (this) {
            FREE -> 1
            PREMIUM -> Int.MAX_VALUE
        }

    val isPaid: Boolean
        get() = this != FREE

    val hasPriorityModel: Boolean
        get() = this == PREMIUM

    val hasHistoryAndExport: Boolean
        get() = this == PREMIUM

    companion object {
        /**
         * Parse from string. Returns FREE for unknown/null values.
         * DR-248: "PRO" maps to FREE (backward compat — no PRO tier anymore).
         */
        fun fromName(name: String?): EntitlementTier =
            entries.firstOrNull { it.name == name } ?: FREE
    }
}
