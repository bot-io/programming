package com.dualreader.app

import android.app.Application
import android.util.Log
import com.dualreader.app.data.pagination.PaginationServiceImpl
import dagger.hilt.android.HiltAndroidApp
import java.io.File

@HiltAndroidApp
class DualReaderApp : Application() {
    override fun onCreate() {
        // Install crash handler FIRST, before anything else
        val defaultHandler = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, throwable ->
            try {
                val report = buildString {
                    append("CRASH: ${throwable.javaClass.name}\n")
                    append("Message: ${throwable.message}\n")
                    append("Thread: ${thread.name}\n")
                    append("Stack:\n")
                    append(Log.getStackTraceString(throwable))
                    append("\n--- Cause ---\n")
                    var cause = throwable.cause
                    var depth = 0
                    while (cause != null && depth < 5) {
                        append("Cause $depth: ${cause.javaClass.name}: ${cause.message}\n")
                        append(Log.getStackTraceString(cause))
                        append("\n")
                        cause = cause.cause
                        depth++
                    }
                }
                val file = File(filesDir, "last_crash.txt")
                file.writeText(report)
                Log.e("DualReader", report)
            } catch (_: Exception) {}
            defaultHandler?.uncaughtException(thread, throwable)
        }

        super.onCreate()
        PaginationServiceImpl.displayDensity = resources.displayMetrics.density
    }
}
