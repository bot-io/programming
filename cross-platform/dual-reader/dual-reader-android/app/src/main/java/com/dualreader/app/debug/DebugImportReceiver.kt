package com.dualreader.app.debug

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import java.io.File

/**
 * Debug-only receiver to import EPUB files via ADB:
 *   adb shell am broadcast -a com.dualreader.app.IMPORT_EPUB --es path /sdcard/.../test.epub
 *
 * Copies the file to internal storage and triggers import via ContentProvider.
 */
class DebugImportReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != "com.dualreader.app.IMPORT_EPUB") return
        val srcPath = intent.getStringExtra("path") ?: run {
            Log.e(TAG, "No 'path' extra provided")
            return
        }

        Log.d(TAG, "Copying EPUB from: $srcPath")

        val pendingResult = goAsync()
        try {
            // Copy to app's internal epubs directory
            val epubsDir = File(context.filesDir, "epubs").apply { mkdirs() }
            val destFile = File(epubsDir, "debug_import_${System.currentTimeMillis()}.epub")

            File(srcPath).inputStream().use { input ->
                destFile.outputStream().use { output ->
                    input.copyTo(output)
                }
            }

            Log.d(TAG, "EPUB copied to: ${destFile.absolutePath}")
            Log.d(TAG, "File size: ${destFile.length()} bytes")

            // Notify the app to import via a content provider trigger
            // The LibraryViewModel will pick up the file via ContentObserver
            // For now, just log success - the user can import from the app's library
            Log.d(TAG, "SUCCESS: File ready for import at ${destFile.absolutePath}")
            Log.d(TAG, "Open the app and use the Import button to select the file.")

        } catch (e: Exception) {
            Log.e(TAG, "Error copying EPUB", e)
        } finally {
            pendingResult.finish()
        }
    }

    companion object {
        private const val TAG = "DebugImport"
    }
}
