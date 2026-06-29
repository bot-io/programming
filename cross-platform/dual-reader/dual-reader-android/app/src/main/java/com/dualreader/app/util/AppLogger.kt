package com.dualreader.app.util

import android.content.Context
import android.util.Log
import java.io.File
import java.time.LocalTime
import java.time.format.DateTimeFormatter
import java.util.Locale

/**
 * Application-wide logger that writes to both logcat AND a file.
 * The file approach works on all devices, including Huawei with HK2-encrypted logcat.
 * Debug panel reads from the file to show actual logs.
 */
object AppLogger {
    private const val LOG_FILE = "app_debug.log"
    private const val MAX_LOG_SIZE = 200_000L // ~200KB, then truncate
    private const val TAG = "DualReader"

    private var logFile: File? = null
    
    // DR-116: Track consecutive write failures to detect persistent logging issues
    @Volatile
    private var consecutiveWriteFailures = 0

    /**
     * Immutable, thread-safe formatter (DR-054). The previous [java.text.SimpleDateFormat]
     * was a single shared mutable instance mutated by every concurrent `format()` call,
     * which could corrupt its internal state and throw `NumberFormatException` or emit
     * garbled timestamps under concurrent logging.
     */
    private val timeFormatter: DateTimeFormatter =
        DateTimeFormatter.ofPattern("HH:mm:ss.SSS", Locale.US)

    @Synchronized
    fun init(context: Context) {
        logFile = File(context.filesDir, LOG_FILE)
        // Truncate if too large
        logFile?.let { file ->
            if (file.exists() && file.length() > MAX_LOG_SIZE) {
                try {
                    val lines = file.readLines()
                    if (lines.size > 500) {
                        file.writeText(lines.takeLast(500).joinToString("\n") + "\n")
                    }
                } catch (e: Exception) {
                    Log.w(TAG, "Failed to truncate log file during init: ${e.message}")
                    // Continue without truncating - logger will still work
                }
            }
        }
    }

    fun i(message: String) {
        Log.i(TAG, message)
        writeLog("I", message)
    }

    fun e(message: String, throwable: Throwable? = null) {
        Log.e(TAG, message, throwable)
        writeLog("E", "$message${throwable?.let { "\n${it.stackTraceToString().take(500)}" } ?: ""}")
    }

    fun w(message: String) {
        Log.w(TAG, message)
        writeLog("W", message)
    }

    fun d(message: String) {
        Log.d(TAG, message)
        writeLog("D", message)
    }

    @Synchronized
    private fun writeLog(level: String, message: String) {
        val file = logFile ?: return
        try {
            val timestamp = timeFormatter.format(LocalTime.now())
            val line = "$timestamp $level/$TAG: $message\n"
            file.appendText(line)
            // DR-116: Reset failure counter on successful write
            consecutiveWriteFailures = 0
        } catch (e: Exception) {
            // DR-116: Track consecutive write failures
            consecutiveWriteFailures++
            // Log to Android Log as fallback if file write fails
            Log.w(TAG, "Failed to write to log file (failure #$consecutiveWriteFailures): ${e.message}")
        }
    }

    /** Read the last N lines of the log file for the debug panel. */
    @Synchronized
    fun getRecentLogs(maxLines: Int = 200): String {
        val file = logFile ?: return "(logger not initialized)"
        return try {
            if (!file.exists()) return "(no log file)"
            file.readLines().takeLast(maxLines).joinToString("\n")
        } catch (e: Exception) {
            "(error reading log: ${e.message})"
        }
    }

    /** Clear the log file. */
    @Synchronized
    fun clear() {
        val file = logFile ?: return
        try {
            file.writeText("")
            // DR-125: Reset failure counter on successful clear
            consecutiveWriteFailures = 0
        } catch (e: Exception) {
            // DR-125: Track clear failures and increment counter
            consecutiveWriteFailures++
            Log.w(TAG, "Failed to clear log file (failure #$consecutiveWriteFailures): ${e.message}")
        }
    }

    /** Get the number of consecutive write failures. DR-116 */
    @Synchronized
    fun getConsecutiveWriteFailures(): Int = consecutiveWriteFailures
}
