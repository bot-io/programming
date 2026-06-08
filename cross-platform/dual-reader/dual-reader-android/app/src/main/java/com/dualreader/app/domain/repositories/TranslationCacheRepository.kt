package com.dualreader.app.domain.repositories

/**
 * Repository for managing the translation cache.
 *
 * The cache stores translations keyed by (text content, source language, target language).
 * Re-translating the same text updates the existing cache entry rather than duplicating.
 */
interface TranslationCacheRepository {

    /**
     * Look up a cached translation.
     * @return cached translation text, or null if not found
     */
    suspend fun get(text: String, sourceLang: String?, targetLang: String): String?

    /**
     * Store or update a translation in the cache.
     * If the same text+language pair already exists, it is overwritten with the new translation.
     */
    suspend fun put(text: String, sourceLang: String?, targetLang: String, translatedText: String, model: String = "")

    /**
     * Clear all cached translations.
     * @return number of entries deleted
     */
    suspend fun clearAll(): Int

    /**
     * Get the number of cached entries.
     */
    suspend fun count(): Int

    /**
     * Delete cache entries matching a list of source texts.
     * Used when a book is deleted to clean up its translations.
     */
    suspend fun deleteForTexts(texts: List<String>)
}
