package com.dualreader.app.ui

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import com.dualreader.app.domain.repositories.SettingsRepository
import com.dualreader.app.ui.navigation.DualReaderNavHost
import com.dualreader.app.ui.theme.DualReaderTheme
import dagger.hilt.android.AndroidEntryPoint
import javax.inject.Inject

@AndroidEntryPoint
class MainActivity : ComponentActivity() {

    @Inject lateinit var settingsRepository: SettingsRepository

    override fun onCreate(savedInstanceState: Bundle?) {
        // Install splash screen before super.onCreate — required by SplashScreen compat lib
        val splashScreen = installSplashScreen()
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            val settings by settingsRepository.settings.collectAsState(
                initial = com.dualreader.app.domain.entities.ReadingSettings()
            )
            DualReaderTheme(theme = settings.theme) {
                Surface(modifier = Modifier.fillMaxSize()) {
                    DualReaderNavHost()
                }
            }
        }
        // Dismiss splash once content is ready
        splashScreen.setKeepOnScreenCondition { false }
    }
}
