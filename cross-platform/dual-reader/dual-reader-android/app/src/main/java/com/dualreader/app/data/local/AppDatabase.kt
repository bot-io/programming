package com.dualreader.app.data.local

import androidx.room.Database
import androidx.room.RoomDatabase
import androidx.room.TypeConverters
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
    version = 2,
    exportSchema = false,
)
@TypeConverters(Converters::class)
abstract class AppDatabase : RoomDatabase() {
    abstract fun bookDao(): BookDao
    abstract fun pageDao(): PageDao
    abstract fun bookmarkDao(): BookmarkDao
    abstract fun translationCacheDao(): TranslationCacheDao
}
