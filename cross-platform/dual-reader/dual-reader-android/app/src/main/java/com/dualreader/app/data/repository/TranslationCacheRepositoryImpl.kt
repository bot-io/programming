package com.dualreader.app.data.repository

import com.dualreader.app.data.local.dao.TranslationCacheDao
import com.dualreader.app.data.local.entity.TranslationCacheEntity
import com.dualreader.app.domain.repositories.TranslationCacheRepository
import java.security.MessageDigest
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class TranslationCacheRepositoryImpl @Inject constructor(
    private val dao: TranslationCacheDao,
) : TranslationCacheRepository {

    override suspend fun get(text: String, sourceLang: String?, targetLang: String): String? {
        val hash = sha256(text)
        val src = sourceLang ?: "auto"
        val entry = dao.get(hash, src, targetLang) ?: return null
        return entry.translatedText
    }

    override suspend fun put(text: String, sourceLang: String?, targetLang: String, translatedText: String, model: String) {
        val hash = sha256(text)
        val src = sourceLang ?: "auto"
        val now = System.currentTimeMillis()

        // Check if entry exists to preserve id and createdAt
        val existing = dao.get(hash, src, targetLang)
        val entry = if (existing != null) {
            existing.copy(
                translatedText = translatedText,
                model = model,
                updatedAt = now,
            )
        } else {
            TranslationCacheEntity(
                textHash = hash,
                sourceLang = src,
                targetLang = targetLang,
                sourceText = text.take(500), // Store first 500 chars for debugging
                translatedText = translatedText,
                model = model,
                createdAt = now,
                updatedAt = now,
            )
        }
        dao.upsert(entry)
    }

    override suspend fun clearAll(): Int {
        val count = dao.count()
        dao.clearAll()
        return count
    }

    override suspend fun count(): Int = dao.count()

    companion object {
        fun sha256(text: String): String {
            val md = MessageDigest.getInstance("SHA-256")
            val digest = md.digest(text.toByteArray(Charsets.UTF_8))
            return digest.joinToString("") { "%02x".format(it) }
        }
    }
}
