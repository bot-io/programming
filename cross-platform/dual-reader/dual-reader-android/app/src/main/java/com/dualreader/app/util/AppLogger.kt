package com.dualreader.app.util

import android.content.Context
import android.util.Log
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
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
    private val dateFormat = SimpleDateFormat("HH:mm:ss.SSS", Locale.US)

    fun init(context: Context) {
        logFile = File(context.filesDir, LOG_FILE)
        // Truncate if too large
        logFile?.let { file ->
            if (file.exists() && file.length() > MAX_LOG_SIZE) {
                val lines = file.readLines()
                if (lines.size > 500) {
                    file.writeText(lines.takeLast(500).joinToString("\n") + "\n")
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

    private fun writeLog(level: String, message: String) {
        val file = logFile ?: return
        try {
            val timestamp = dateFormat.format(Date())
            val line = "$timestamp $level/$TAG: $message\n"
            file.appendText(line)
        } catch (_: Exception) {
            // Don't crash if logging fails
        }
    }

    /** Read the last N lines of the log file for the debug panel. */
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
    fun clear() {
        logFile?.writeText("")
    }
}
