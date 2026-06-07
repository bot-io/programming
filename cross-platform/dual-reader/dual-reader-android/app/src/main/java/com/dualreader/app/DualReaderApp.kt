package com.dualreader.app

import android.app.Application
import com.dualreader.app.data.pagination.PaginationServiceImpl
import dagger.hilt.android.HiltAndroidApp

@HiltAndroidApp
class DualReaderApp : Application() {
    override fun onCreate() {
        super.onCreate()
        PaginationServiceImpl.displayDensity = resources.displayMetrics.density
    }
}
