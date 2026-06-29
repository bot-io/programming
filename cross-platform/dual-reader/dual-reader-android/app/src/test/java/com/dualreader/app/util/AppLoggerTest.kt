package com.dualreader.app.util

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.io.File

/**
 * Regression tests for DR-054: AppLogger thread-safety.
 *
 * The bug: [java.text.SimpleDateFormat] was a single shared mutable instance accessed by every
 * concurrent log call. Concurrent `format()` invocations could corrupt its internal calendar
 * state, throwing `NumberFormatException` or emitting garbled timestamps. Additionally, the
 * file I/O (`appendText`, `readLines`, `writeText`) was unsynchronized, so concurrent appends
 * could interleave or merge log lines.
 *
 * The fix: immutable [java.time.format.DateTimeFormatter] + `@Synchronized` on all file-touching
 * methods.
 */
class AppLoggerTest {

    private val tempDir = File(System.getProperty("user.home"), "dualreader-test-logs")
    private lateinit var logFile: File

    @Before
    fun setUp() {
        tempDir.mkdirs()
        logFile = File(tempDir, "applogger-test.log")
        logFile.writeText("")
        setLogField(logFile)
    }

    @After
    fun tearDown() {
        setLogField(null)
        logFile.delete()
        if (tempDir.exists()) tempDir.listFiles()?.forEach { it.delete() }
    }

    /** Reflectively point the singleton's private `logFile` at a real temp file. */
    private fun setLogField(file: File?) {
        val field = AppLogger::class.java.getDeclaredField("logFile")
        field.isAccessible = true
        field.set(AppLogger, file)
    }

    @Test
    fun `single write appends one correctly-timestamped line`() {
        AppLogger.i("hello world")

        val lines = logFile.readLines()
        assertEquals(1, lines.size)
        assertTrue(
            "Line should start with an HH:mm:ss.SSS timestamp, was: ${lines[0]}",
            lines[0].matches(Regex("""\d{2}:\d{2}:\d{2}\.\d{3} I/DualReader: hello world""")),
        )
    }

    @Test
    fun `concurrent writes each produce exactly one intact line`() = runBlocking {
        val count = 200
        val messages = (0 until count).map { "concurrent-msg-$it" }

        // Spread writes across the IO dispatcher pool to maximise thread contention.
        val jobs = messages.map { msg ->
            async(Dispatchers.IO) {
                AppLogger.i(msg)
            }
        }
        jobs.awaitAll()

        val lines = logFile.readLines()
        assertEquals("Every write must produce exactly one line", count, lines.size)

        // No line may have been merged/corrupted — strip the timestamp/level prefix and
        // verify the full set of messages survived intact.
        val written = lines.map { it.substringAfter("I/DualReader: ") }.toSet()
        assertEquals(messages.toSet(), written)

        // Every line must carry a valid timestamp (proves the formatter never garbled).
        lines.forEach { line ->
            assertTrue(
                "Garbled timestamp in line: $line",
                line.matches(Regex("""\d{2}:\d{2}:\d{2}\.\d{3} I/DualReader: concurrent-msg-\d+""")),
            )
        }
    }

    @Test
    fun `concurrent mixed-level writes preserve all lines`() = runBlocking {
        val count = 120
        val jobs = (0 until count).map { i ->
            async(Dispatchers.IO) {
                when (i % 4) {
                    0 -> AppLogger.i("i-$i")
                    1 -> AppLogger.w("w-$i")
                    2 -> AppLogger.e("e-$i")
                    else -> AppLogger.d("d-$i")
                }
            }
        }
        jobs.awaitAll()

        val lines = logFile.readLines()
        assertEquals(count, lines.size)
        // Each line must carry a valid level prefix — no merges.
        lines.forEach { line ->
            assertTrue(
                "Line missing level marker: $line",
                Regex("""\d{2}:\d{2}:\d{2}\.\d{3} [IWED]/DualReader: [a-z]-\d+""").matches(line),
            )
        }
    }

    @Test
    fun `getRecentLogs returns last N lines in order`() {
        repeat(10) { AppLogger.d("line-$it") }

        val recent = AppLogger.getRecentLogs(3)
        val recentLines = recent.split("\n")
        assertEquals(3, recentLines.size)
        assertTrue("Should end with the last written line", recentLines.last().contains("line-9"))
        assertTrue("Should not contain the earliest line", recentLines.none { it.contains("line-0") })
    }

    @Test
    fun `clear empties the log file`() {
        AppLogger.w("something")
        assertTrue(logFile.readLines().isNotEmpty())

        AppLogger.clear()

        assertEquals("", logFile.readText())
    }

    @Test
    fun `error log includes stack trace when throwable is provided`() {
        val ex = RuntimeException("boom")
        AppLogger.e("failed op", ex)

        val content = logFile.readText()
        assertTrue(content.contains("E/DualReader: failed op"))
        assertTrue(content.contains("RuntimeException: boom"))
    }
}
