package com.dualreader.app.data.local.mapper

import com.dualreader.app.data.local.Converters
import com.dualreader.app.data.local.entity.BookEntity
import com.dualreader.app.data.local.entity.BookmarkEntity
import com.dualreader.app.data.local.entity.PageEntity
import com.dualreader.app.domain.entities.Book
import com.dualreader.app.domain.entities.Bookmark
import com.dualreader.app.domain.entities.Page
import java.time.LocalDateTime
import java.time.ZoneOffset

// --- Book ---

fun BookEntity.toDomain(): Book {
    val chapters = Converters().fromChaptersJson(chaptersJson)
    return Book(
        id = id,
        title = title,
        author = author,
        coverPath = coverPath,
        filePath = filePath,
        language = language,
        importedAt = LocalDateTime.ofEpochSecond(importedAt / 1000, 0, ZoneOffset.UTC),
        lastReadAt = lastReadAt?.let { LocalDateTime.ofEpochSecond(it / 1000, 0, ZoneOffset.UTC) },
        currentPage = currentPage,
        totalPages = totalPages,
        paginationStatus = Converters().fromPaginationStatus(paginationStatus),
        paginationProgress = paginationProgress,
        chapters = chapters,
    )
}

fun Book.toEntity(): BookEntity = BookEntity(
    id = id,
    title = title,
    author = author,
    coverPath = coverPath,
    filePath = filePath,
    language = language,
    importedAt = importedAt.atZone(ZoneOffset.UTC).toInstant().toEpochMilli(),
    lastReadAt = lastReadAt?.atZone(ZoneOffset.UTC)?.toInstant()?.toEpochMilli(),
    currentPage = currentPage,
    totalPages = totalPages,
    paginationStatus = paginationStatus.name,
    paginationProgress = paginationProgress,
    chaptersJson = Converters().toChaptersJson(chapters),
)

// --- Page ---

private val converters = Converters()

fun PageEntity.toDomain(): Page = Page(
    index = pageIndex,
    bookId = bookId,
    chapterIndex = chapterIndex,
    originalText = originalText,
    translations = converters.fromTranslationsJson(translationsJson),
    translationModels = converters.fromTranslationsJson(translationModelsJson),
    startCharOffset = startCharOffset,
    endCharOffset = endCharOffset,
)

fun Page.toEntity(existingId: Long = 0): PageEntity = PageEntity(
    id = existingId,
    bookId = bookId,
    pageIndex = index,
    chapterIndex = chapterIndex,
    originalText = originalText,
    translationsJson = converters.toTranslationsJson(translations),
    translationModelsJson = converters.toTranslationsJson(translationModels),
    startCharOffset = startCharOffset,
    endCharOffset = endCharOffset,
)

// --- Bookmark ---

fun BookmarkEntity.toDomain(): Bookmark = Bookmark(
    id = id,
    bookId = bookId,
    pageIndex = pageIndex,
    chapterIndex = chapterIndex,
    textSnippet = textSnippet,
    note = note,
    createdAt = LocalDateTime.ofEpochSecond(createdAt / 1000, 0, ZoneOffset.UTC),
)

fun Bookmark.toEntity(): BookmarkEntity = BookmarkEntity(
    id = id,
    bookId = bookId,
    pageIndex = pageIndex,
    chapterIndex = chapterIndex,
    textSnippet = textSnippet,
    note = note,
    createdAt = createdAt.atZone(ZoneOffset.UTC).toInstant().toEpochMilli(),
)
