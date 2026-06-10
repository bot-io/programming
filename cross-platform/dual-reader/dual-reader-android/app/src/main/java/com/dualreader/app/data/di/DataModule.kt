package com.dualreader.app.data.di

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.PreferenceDataStoreFactory
import androidx.datastore.preferences.preferencesDataStoreFile
import androidx.room.Room
import androidx.room.migration.Migration
import androidx.sqlite.db.SupportSQLiteDatabase
import com.dualreader.app.data.local.AppDatabase
import com.dualreader.app.data.local.dao.BookDao
import com.dualreader.app.data.local.dao.BookmarkDao
import com.dualreader.app.data.local.dao.PageDao
import com.dualreader.app.data.local.dao.TranslationCacheDao
import com.dualreader.app.data.repository.BookmarkRepositoryImpl
import com.dualreader.app.data.repository.BookRepositoryImpl
import com.dualreader.app.data.repository.SettingsRepositoryImpl
import com.dualreader.app.data.repository.TranslationCacheRepositoryImpl
import com.dualreader.app.domain.repositories.BookmarkRepository
import com.dualreader.app.domain.repositories.BookRepository
import com.dualreader.app.domain.repositories.SettingsRepository
import com.dualreader.app.domain.repositories.TranslationCacheRepository
import dagger.Binds
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
abstract class DataModule {

    @Binds
    @Singleton
    abstract fun bindBookRepository(impl: BookRepositoryImpl): BookRepository

    @Binds
    @Singleton
    abstract fun bindBookmarkRepository(impl: BookmarkRepositoryImpl): BookmarkRepository

    @Binds
    @Singleton
    abstract fun bindSettingsRepository(impl: SettingsRepositoryImpl): SettingsRepository

    @Binds
    @Singleton
    abstract fun bindTranslationCacheRepository(impl: TranslationCacheRepositoryImpl): TranslationCacheRepository

    companion object {

        private val MIGRATION_1_2 = object : Migration(1, 2) {
            override fun migrate(db: SupportSQLiteDatabase) {
                db.execSQL("""
                    CREATE TABLE IF NOT EXISTS `translation_cache` (
                        `id` INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
                        `textHash` TEXT NOT NULL,
                        `sourceLang` TEXT NOT NULL,
                        `targetLang` TEXT NOT NULL,
                        `sourceText` TEXT NOT NULL DEFAULT '',
                        `translatedText` TEXT NOT NULL,
                        `model` TEXT NOT NULL,
                        `createdAt` INTEGER NOT NULL,
                        `updatedAt` INTEGER NOT NULL
                    )
                """.trimIndent())
                db.execSQL("CREATE UNIQUE INDEX IF NOT EXISTS `index_translation_cache_textHash_sourceLang_targetLang` ON `translation_cache` (`textHash`, `sourceLang`, `targetLang`)")
            }
        }

        @Provides
        @Singleton
        fun provideDatabase(@ApplicationContext context: Context): AppDatabase =
            Room.databaseBuilder(context, AppDatabase::class.java, "dualreader.db")
                .addMigrations(MIGRATION_1_2, AppDatabase.MIGRATION_2_3, AppDatabase.MIGRATION_3_4, AppDatabase.MIGRATION_4_5)
                .fallbackToDestructiveMigration()
                .build()

        @Provides
        fun provideBookDao(db: AppDatabase): BookDao = db.bookDao()

        @Provides
        fun providePageDao(db: AppDatabase): PageDao = db.pageDao()

        @Provides
        fun provideBookmarkDao(db: AppDatabase): BookmarkDao = db.bookmarkDao()

        @Provides
        fun provideTranslationCacheDao(db: AppDatabase): TranslationCacheDao = db.translationCacheDao()

        @Provides
        @Singleton
        fun provideDataStore(@ApplicationContext context: Context): DataStore<Preferences> =
            PreferenceDataStoreFactory.create {
                context.preferencesDataStoreFile("settings")
            }
    }
}
