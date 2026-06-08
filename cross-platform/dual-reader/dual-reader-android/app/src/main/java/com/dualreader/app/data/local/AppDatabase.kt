package com.dualreader.app.data.local

import androidx.room.Database
import androidx.room.RoomDatabase
import androidx.room.TypeConverters
import androidx.room.migration.Migration
import androidx.sqlite.db.SupportSQLiteDatabase
import com.dualreader.app.data.local.dao.BookDao
import com.dualreader.app.data.local.dao.BookmarkDao
import com.dualreader.app.data.local.dao.PageDao
import com.dualreader.app.data.local.dao.TranslationCacheDao
import com.dualreader.app.data.local.entity.BookEntity
import com.dualreader.app.data.local.entity.BookmarkEntity
import com.dualreader.app.data.local.entity.PageEntity
import com.dualreader.app.data.local.entity.TranslationCacheEntity

@Database(
    entities = [BookEntity::class, PageEntity::class, BookmarkEntity::class, TranslationCacheEntity::class],
    version = 3,
    exportSchema = false,
)
@TypeConverters(Converters::class)
abstract class AppDatabase : RoomDatabase() {
    abstract fun bookDao(): BookDao
    abstract fun pageDao(): PageDao
    abstract fun bookmarkDao(): BookmarkDao
    abstract fun translationCacheDao(): TranslationCacheDao

    companion object {
        /** Migration v2→v3: add translatedLang column to pages table. */
        val MIGRATION_2_3 = object : Migration(2, 3) {
            override fun migrate(db: SupportSQLiteDatabase) {
                db.execSQL("ALTER TABLE pages ADD COLUMN translatedLang TEXT DEFAULT NULL")
            }
        }
    }
}
