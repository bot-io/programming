package com.dualreader.app.data.local.dao

import androidx.room.*
import com.dualreader.app.data.local.entity.TranslationCacheEntity

@Dao
interface TranslationCacheDao {

    @Query("SELECT * FROM translation_cache WHERE textHash = :hash AND sourceLang = :src AND targetLang = :tgt LIMIT 1")
    suspend fun get(hash: String, src: String, tgt: String): TranslationCacheEntity?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(entry: TranslationCacheEntity)

    @Query("DELETE FROM translation_cache")
    suspend fun clearAll()

    @Query("SELECT COUNT(*) FROM translation_cache")
    suspend fun count(): Int

    @Query("DELETE FROM translation_cache WHERE textHash = :hash")
    suspend fun deleteByHash(hash: String)
}
