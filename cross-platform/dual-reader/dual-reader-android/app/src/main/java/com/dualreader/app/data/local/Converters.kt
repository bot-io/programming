package com.dualreader.app.data.local

import androidx.room.TypeConverter
import com.dualreader.app.domain.entities.BookChapter
import com.dualreader.app.domain.entities.BookFormat
import com.dualreader.app.domain.entities.PaginationStatus
import com.dualreader.app.util.AppLogger
import org.json.JSONArray
import org.json.JSONObject
import java.time.LocalDateTime
import java.time.ZoneOffset

class Converters {

    @TypeConverter
    fun fromTimestamp(value: Long?): LocalDateTime? =
        value?.let {
            // Preserve sub-second precision: epoch-millis → seconds + nanos.
            // The previous `0` for nanos silently dropped milliseconds on every
            // DB round-trip (DR-056).
            LocalDateTime.ofEpochSecond(it / 1000, ((it % 1000) * 1_000_000).toInt(), ZoneOffset.UTC)
        }

    @TypeConverter
    fun toTimestamp(date: LocalDateTime?): Long? =
        date?.atZone(ZoneOffset.UTC)?.toInstant()?.toEpochMilli()

    @TypeConverter
    fun fromChaptersJson(value: String): List<BookChapter> {
        if (value == "[]" || value.isBlank()) return emptyList()
        val array = JSONArray(value)
        return (0 until array.length()).map { i ->
            val obj = array.getJSONObject(i)
            BookChapter(
                index = obj.getInt("index"),
                title = obj.getString("title"),
                level = obj.optInt("level", 0),
                startIndex = obj.optInt("startIndex", 0),
                endIndex = obj.optInt("endIndex", 0),
            )
        }
    }

    @TypeConverter
    fun toChaptersJson(chapters: List<BookChapter>): String {
        if (chapters.isEmpty()) return "[]"
        val array = JSONArray()
        chapters.forEach { ch ->
            val obj = JSONObject().apply {
                put("index", ch.index)
                put("title", ch.title)
                put("level", ch.level)
                put("startIndex", ch.startIndex)
                put("endIndex", ch.endIndex)
            }
            array.put(obj)
        }
        return array.toString()
    }

    @TypeConverter
    fun fromPaginationStatus(value: String): PaginationStatus =
        try {
            PaginationStatus.valueOf(value)
        } catch (e: Exception) {
            AppLogger.w("Failed to parse PaginationStatus: '$value', using NOT_STARTED. Error: ${e.message}")
            PaginationStatus.NOT_STARTED
        }

    @TypeConverter
    fun toPaginationStatus(status: PaginationStatus): String = status.name

    @TypeConverter
    fun fromBookFormat(value: String): BookFormat =
        try {
            BookFormat.valueOf(value)
        } catch (e: Exception) {
            AppLogger.w("Failed to parse BookFormat: '$value', using EPUB. Error: ${e.message}")
            BookFormat.EPUB
        }

    @TypeConverter
    fun toBookFormat(format: BookFormat): String = format.name

    // ── Translations map (lang → translated text) ──────────────────────

    @TypeConverter
    fun fromTranslationsJson(value: String?): Map<String, String> {
        if (value.isNullOrBlank() || value == "{}") return emptyMap()
        return try {
            val obj = JSONObject(value)
            val map = mutableMapOf<String, String>()
            val keys = obj.keys()
            while (keys.hasNext()) {
                val key = keys.next()
                map[key] = obj.getString(key)
            }
            map
        } catch (e: Exception) {
            AppLogger.e("Failed to parse translations JSON: ${e.message}")
            emptyMap()
        }
    }

    @TypeConverter
    fun toTranslationsJson(map: Map<String, String>): String? {
        if (map.isEmpty()) return null
        val obj = JSONObject()
        map.forEach { (k, v) -> obj.put(k, v) }
        return obj.toString()
    }

    // ── Translation timestamps map (lang → epoch millis) ───────────────

    @TypeConverter
    fun fromTranslationTimestampsJson(value: String?): Map<String, Long> {
        if (value.isNullOrBlank() || value == "{}") return emptyMap()
        return try {
            val obj = JSONObject(value)
            val map = mutableMapOf<String, Long>()
            val keys = obj.keys()
            while (keys.hasNext()) {
                val key = keys.next()
                map[key] = obj.getLong(key)
            }
            map
        } catch (e: Exception) {
            AppLogger.e("Failed to parse translation timestamps JSON: ${e.message}")
            emptyMap()
        }
    }

    @TypeConverter
    fun toTranslationTimestampsJson(map: Map<String, Long>): String? {
        if (map.isEmpty()) return null
        val obj = JSONObject()
        map.forEach { (k, v) -> obj.put(k, v) }
        return obj.toString()
    }
}
