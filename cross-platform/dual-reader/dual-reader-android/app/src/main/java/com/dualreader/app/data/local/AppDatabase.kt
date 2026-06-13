package com.dualreader.app.data.local

import androidx.room.Database
import androidx.room.RoomDatabase
import androidx.room.TypeConverters
import androidx.room.migration.Migration
import androidx.sqlite.db.SupportSQLiteDatabase
import com.dualreader.app.data.local.dao.BookDao
import com.dualreader.app.data.local.dao.BookmarkDao
import com.dualreader.app.data.local.dao.BookTagDao
import com.dualreader.app.data.local.dao.CollectionDao
import com.dualreader.app.data.local.dao.PageDao
import com.dualreader.app.data.local.dao.TranslationCacheDao
import com.dualreader.app.data.local.entity.BookEntity
import com.dualreader.app.data.local.entity.BookTagEntity
import com.dualreader.app.data.local.entity.BookmarkEntity
import com.dualreader.app.data.local.entity.CollectionBookEntity
import com.dualreader.app.data.local.entity.CollectionEntity
import com.dualreader.app.data.local.entity.PageEntity
import com.dualreader.app.data.local.entity.TranslationCacheEntity

@Database(
    entities = [
        BookEntity::class,
        PageEntity::class,
        BookmarkEntity::class,
        TranslationCacheEntity::class,
        BookTagEntity::class,
        CollectionEntity::class,
        CollectionBookEntity::class,
    ],
    version = 6,
    exportSchema = false,
)
@TypeConverters(Converters::class)
abstract class AppDatabase : RoomDatabase() {
    abstract fun bookDao(): BookDao
    abstract fun pageDao(): PageDao
    abstract fun bookmarkDao(): BookmarkDao
    abstract fun translationCacheDao(): TranslationCacheDao
    abstract fun bookTagDao(): BookTagDao
    abstract fun collectionDao(): CollectionDao

    companion object {
        /** Migration v2→v3: add translatedLang column to pages table. */
        val MIGRATION_2_3 = object : Migration(2, 3) {
            override fun migrate(db: SupportSQLiteDatabase) {
                db.execSQL("ALTER TABLE pages ADD COLUMN translatedLang TEXT DEFAULT NULL")
            }
        }

        /**
         * Migration v3→v4: replace translatedText + translatedLang with translationsJson.
         * Creates a new table, copies data (merging the two columns into a JSON map),
         * then swaps tables.
         */
        val MIGRATION_3_4 = object : Migration(3, 4) {
            override fun migrate(db: SupportSQLiteDatabase) {
                // Create new pages table with translationsJson instead of translatedText/translatedLang
                db.execSQL("""
                    CREATE TABLE pages_new (
                        id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
                        bookId TEXT NOT NULL,
                        pageIndex INTEGER NOT NULL,
                        chapterIndex INTEGER NOT NULL,
                        originalText TEXT NOT NULL,
                        translationsJson TEXT DEFAULT NULL,
                        startCharOffset INTEGER NOT NULL,
                        endCharOffset INTEGER NOT NULL,
                        FOREIGN KEY (bookId) REFERENCES books(id) ON DELETE CASCADE
                    )
                """.trimIndent())

                // Create the unique index
                db.execSQL("CREATE UNIQUE INDEX index_pages_new_bookId_pageIndex ON pages_new(bookId, pageIndex)")

                // Copy data — construct JSON from translatedText + translatedLang
                // If both exist: {"lang":"text"}. Otherwise: NULL.
                db.execSQL("""
                    INSERT INTO pages_new (id, bookId, pageIndex, chapterIndex, originalText, translationsJson, startCharOffset, endCharOffset)
                    SELECT
                        id, bookId, pageIndex, chapterIndex, originalText,
                        CASE
                            WHEN translatedText IS NOT NULL AND translatedLang IS NOT NULL
                                THEN '{' || '"' || translatedLang || '"' || ':' || '"' || REPLACE(REPLACE(translatedText, '\', '\\'), '"', '\"') || '"' || '}'
                            WHEN translatedText IS NOT NULL
                                THEN '{"unknown":"' || REPLACE(REPLACE(translatedText, '\', '\\'), '"', '\"') || '"}'
                            ELSE NULL
                        END,
                        startCharOffset, endCharOffset
                    FROM pages
                """.trimIndent())

                // Swap tables
                db.execSQL("DROP TABLE pages")
                db.execSQL("ALTER TABLE pages_new RENAME TO pages")
            }
        }

        /** Migration v4→v5: add translationModelsJson column to pages. */
        val MIGRATION_4_5 = object : Migration(4, 5) {
            override fun migrate(db: SupportSQLiteDatabase) {
                db.execSQL("ALTER TABLE pages ADD COLUMN translationModelsJson TEXT DEFAULT NULL")
            }
        }

        /** Migration v5→v6: add book_tags, collections, collection_books tables. */
        val MIGRATION_5_6 = object : Migration(5, 6) {
            override fun migrate(db: SupportSQLiteDatabase) {
                // book_tags table
                db.execSQL("""
                    CREATE TABLE IF NOT EXISTS `book_tags` (
                        `bookId` TEXT NOT NULL,
                        `tag` TEXT NOT NULL,
                        PRIMARY KEY(`bookId`, `tag`),
                        FOREIGN KEY(`bookId`) REFERENCES `books`(`id`) ON DELETE CASCADE
                    )
                """.trimIndent())
                db.execSQL("CREATE INDEX IF NOT EXISTS `index_book_tags_tag` ON `book_tags` (`tag`)")

                // collections table
                db.execSQL("""
                    CREATE TABLE IF NOT EXISTS `collections` (
                        `id` INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
                        `name` TEXT NOT NULL,
                        `createdAt` INTEGER NOT NULL
                    )
                """.trimIndent())

                // collection_books junction table
                db.execSQL("""
                    CREATE TABLE IF NOT EXISTS `collection_books` (
                        `collectionId` INTEGER NOT NULL,
                        `bookId` TEXT NOT NULL,
                        PRIMARY KEY(`collectionId`, `bookId`),
                        FOREIGN KEY(`collectionId`) REFERENCES `collections`(`id`) ON DELETE CASCADE,
                        FOREIGN KEY(`bookId`) REFERENCES `books`(`id`) ON DELETE CASCADE
                    )
                """.trimIndent())
                db.execSQL("CREATE INDEX IF NOT EXISTS `index_collection_books_bookId` ON `collection_books` (`bookId`)")
            }
        }
    }
}
