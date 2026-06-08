package com.dualreader.app.data.local.entity

import androidx.room.ColumnInfo
import androidx.room.Entity
import androidx.room.Index
import androidx.room.PrimaryKey

/**
 * Caches translations keyed by (textHash, sourceLang, targetLang).
 *
 * Re-translating the same text with the same language pair updates the row
 * (new model, better quality) rather than creating a duplicate.
 */
@Entity(
    tableName = "translation_cache",
    indices = [
        Index(value = ["textHash", "sourceLang", "targetLang"], unique = true),
    ],
)
data class TranslationCacheEntity(
    @PrimaryKey(autoGenerate = true)
    val id: Long = 0,

    val textHash: String,
    val sourceLang: String,
    val targetLang: String,

    @ColumnInfo(defaultValue = "")
    val sourceText: String = "",

    val translatedText: String,
    val model: String = "",

    val createdAt: Long = System.currentTimeMillis(),
    val updatedAt: Long = System.currentTimeMillis(),
)
