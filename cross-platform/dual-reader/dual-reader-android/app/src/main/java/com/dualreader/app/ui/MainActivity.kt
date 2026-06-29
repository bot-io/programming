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
import androidx.lifecycle.lifecycleScope
import com.dualreader.app.data.initializer.PreInstalledBooksInitializer
import com.dualreader.app.data.repository.BillingRepositoryImpl
import com.dualreader.app.domain.repositories.SettingsRepository
import com.dualreader.app.domain.repository.BillingRepository
import com.dualreader.app.domain.usecases.ImportBookUseCase
import com.dualreader.app.domain.usecases.PaginateBookUseCase
import com.dualreader.app.ui.navigation.DualReaderNavHost
import com.dualreader.app.ui.theme.DualReaderTheme
import dagger.hilt.android.AndroidEntryPoint
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import javax.inject.Inject

@AndroidEntryPoint
class MainActivity : ComponentActivity() {

    @Inject lateinit var settingsRepository: SettingsRepository
    @Inject lateinit var billingRepository: BillingRepository
    @Inject lateinit var importBookUseCase: ImportBookUseCase
    @Inject lateinit var paginateBookUseCase: PaginateBookUseCase

    // DR-137: Use StateFlow instead of mutable var to avoid race condition
    // Null means still loading, true/false is the actual onboarding decision
    private val _showOnboarding = MutableStateFlow<Boolean?>(null)
    private val showOnboarding: StateFlow<Boolean?> = _showOnboarding

    override fun onCreate(savedInstanceState: Bundle?) {
        // Install splash screen before super.onCreate — required by SplashScreen compat lib
        val splashScreen = installSplashScreen()
        super.onCreate(savedInstanceState)

        // DR-137: Keep splash screen on while onboarding state is loading (null)
        splashScreen.setKeepOnScreenCondition { showOnboarding.value == null }

        // Check onboarding + init billing in background
        lifecycleScope.launch {
            _showOnboarding.value = !settingsRepository.isOnboardingCompleted.first()

            // Import pre-installed books on first launch (non-blocking)
            val booksInitializer = PreInstalledBooksInitializer(
                context = this@MainActivity,
                importBookUseCase = importBookUseCase,
                paginateBookUseCase = paginateBookUseCase,
            )
            booksInitializer.importPreInstalledBooks()

            // Set up billing with activity reference
            (billingRepository as? BillingRepositoryImpl)?.setActivity(this@MainActivity)
            billingRepository.initialize()
        }

        enableEdgeToEdge()
        setContent {
            val settings by settingsRepository.settings.collectAsState(
                initial = com.dualreader.app.domain.entities.ReadingSettings()
            )

            // DR-137: Collect StateFlow safely - null means loading, default to false (library)
            val startOnboarding by showOnboarding.collectAsState(initial = null)
            // NavHost requires non-nullable Boolean - use false as default when loading
            val startDestination = if (startOnboarding == true) "onboarding" else "library"

            DualReaderTheme(theme = settings.theme) {
                Surface(modifier = Modifier.fillMaxSize()) {
                    DualReaderNavHost(
                        startOnboarding = startDestination == "onboarding",
                        onOnboardingComplete = {
                            lifecycleScope.launch {
                                settingsRepository.setOnboardingCompleted()
                            }
                        },
                    )
                }
            }
        }
    }
}
