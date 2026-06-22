package com.dualreader.app.data.local

import android.content.ContentValues
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
import org.json.JSONObject

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
    version = 7,
    exportSchema = true,
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

                // Copy data — build translationsJson via org.json.JSONObject so values are
                // escaped correctly. The previous string-concatenation approach broke on
                // embedded quotes, backslashes, and newlines, producing invalid JSON.
                // Both translatedText + translatedLang -> {"lang":"text"}.
                // Only translatedText -> {"unknown":"text"}. Otherwise -> NULL.
                db.query(
                    """
                    SELECT id, bookId, pageIndex, chapterIndex, originalText,
                           translatedText, translatedLang, startCharOffset, endCharOffset
                    FROM pages
                    """.trimIndent(),
                    emptyArray(),
                ).use { cursor ->
                    while (cursor.moveToNext()) {
                        val translatedText = cursor.getColumnIndex("translatedText")
                            .takeIf { it >= 0 && !cursor.isNull(it) }
                            ?.let { cursor.getString(it) }
                        val translatedLang = cursor.getColumnIndex("translatedLang")
                            .takeIf { it >= 0 && !cursor.isNull(it) }
                            ?.let { cursor.getString(it) }

                        val translationsJson: String? = when {
                            translatedText != null && translatedLang != null ->
                                JSONObject().put(translatedLang, translatedText).toString()
                            translatedText != null ->
                                JSONObject().put("unknown", translatedText).toString()
                            else -> null
                        }

                        val values = ContentValues().apply {
                            put("id", cursor.getLong(cursor.getColumnIndexOrThrow("id")))
                            put("bookId", cursor.getString(cursor.getColumnIndexOrThrow("bookId")))
                            put("pageIndex", cursor.getInt(cursor.getColumnIndexOrThrow("pageIndex")))
                            put("chapterIndex", cursor.getInt(cursor.getColumnIndexOrThrow("chapterIndex")))
                            put("originalText", cursor.getString(cursor.getColumnIndexOrThrow("originalText")))
                            put("translationsJson", translationsJson)
                            put("startCharOffset", cursor.getInt(cursor.getColumnIndexOrThrow("startCharOffset")))
                            put("endCharOffset", cursor.getInt(cursor.getColumnIndexOrThrow("endCharOffset")))
                        }
                        db.insert(
                            "pages_new",
                            android.database.sqlite.SQLiteDatabase.CONFLICT_REPLACE,
                            values,
                        )
                    }
                }

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

        /** Migration v6→v7: add translationTimestampsJson column to pages. */
        val MIGRATION_6_7 = object : Migration(6, 7) {
            override fun migrate(db: SupportSQLiteDatabase) {
                db.execSQL("ALTER TABLE pages ADD COLUMN translationTimestampsJson TEXT DEFAULT NULL")
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
