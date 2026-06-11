package com.dualreader.app.ui

import android.os.Bundle
import android.util.Log
import android.widget.Toast
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import com.dualreader.app.ui.navigation.DualReaderNavHost
import com.dualreader.app.ui.theme.DualReaderTheme
import dagger.hilt.android.AndroidEntryPoint

@AndroidEntryPoint
class MainActivity : ComponentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        // Install splash screen BEFORE super.onCreate() and setContent
        val splashScreen = installSplashScreen()

        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            DualReaderTheme {
                Surface(modifier = Modifier.fillMaxSize()) {
                    DualReaderNavHost()
                }
            }
        }
    }
}
