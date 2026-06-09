package com.dualreader.app.ui.navigation

import android.content.Context
import android.net.Uri
import android.util.Log
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.dualreader.app.ui.screens.*
import java.io.File
import java.util.UUID

private const val TAG = "NavHost"

private fun copyEpubToInternalStorage(context: Context, uri: Uri): String? {
    return try {
        val epubsDir = File(context.filesDir, "epubs").apply { mkdirs() }
        val fileName = "${UUID.randomUUID()}.epub"
        val destFile = File(epubsDir, fileName)
        context.contentResolver.openInputStream(uri)?.use { input ->
            destFile.outputStream().use { output -> input.copyTo(output) }
        } ?: return null
        Log.d(TAG, "EPUB copied to ${destFile.absolutePath}")
        destFile.absolutePath
    } catch (e: Exception) {
        Log.e(TAG, "Error copying EPUB from URI: $uri", e)
        null
    }
}

@Composable
fun DualReaderNavHost() {
    val navController = rememberNavController()
    val context = LocalContext.current

    NavHost(navController = navController, startDestination = "library") {
        // ── Library ──────────────────────────────────────────────────
        composable("library") {
            val viewModel: LibraryViewModel = hiltViewModel()
            val uiState by viewModel.uiState.collectAsState()

            // Check for crash report from previous run
            val crashReport = remember {
                val file = File(context.filesDir, "last_crash.txt")
                if (file.exists()) {
                    val text = file.readText()
                    file.delete()
                    text
                } else null
            }

            if (crashReport != null) {
                CrashReportView(report = crashReport)
            } else {
                val epubPickerLauncher = rememberLauncherForActivityResult(
                    contract = ActivityResultContracts.OpenDocument()
                ) { uri: Uri? ->
                    uri?.let { pickedUri ->
                        val savedPath = copyEpubToInternalStorage(context, pickedUri)
                        if (savedPath != null) viewModel.importBook(savedPath)
                    }
                }

                LibraryScreen(
                    uiState = uiState,
                    onBookClick = { bookId -> navController.navigate("reader/$bookId") },
                    onImportClick = { epubPickerLauncher.launch(arrayOf("application/epub+zip")) },
                    onSettingsClick = { navController.navigate("settings") },
                    onRetryPagination = { book -> viewModel.retryPagination(book, 1080, 1000) },
                    onDeleteBook = { viewModel.deleteBook(it) },
                )
            }
        }

        // ── Reader ───────────────────────────────────────────────────
        composable(
            route = "reader/{bookId}",
            arguments = listOf(navArgument("bookId") { type = NavType.StringType }),
        ) { backStackEntry ->
            val bookId = backStackEntry.arguments?.getString("bookId") ?: return@composable
            val viewModel: ReaderViewModel = hiltViewModel()
            val uiState by viewModel.uiState.collectAsState()
            val searchQuery by viewModel.searchQuery.collectAsState()
            val searchResults by viewModel.searchResults.collectAsState()

            ReaderScreen(
                uiState = uiState,
                onBack = { navController.popBackStack() },
                onNextPage = { viewModel.nextPage() },
                onPreviousPage = { viewModel.previousPage() },
                onTranslateCurrentPage = { viewModel.translateCurrentPage() },
                onTranslateAll = { viewModel.translateAllPages() },
                onAddBookmark = { viewModel.addBookmark(it) },
                onRemoveBookmark = { viewModel.removeBookmark(it) },
                onToggleImmersive = { viewModel.toggleImmersiveMode() },
                onGoToPage = { viewModel.goToPage(it) },
                onSettingsClick = { navController.navigate("settings") },
                onSearch = { viewModel.search(it) },
                onClearSearch = { viewModel.clearSearch() },
                searchQuery = searchQuery,
                searchResults = searchResults,
                onRePaginate = { w, h, d -> viewModel.rePaginate(w, h, d) },
            )
        }

        // ── Settings ─────────────────────────────────────────────────
        composable("settings") {
            val viewModel: SettingsViewModel = hiltViewModel()
            val settings by viewModel.settings.collectAsState()
            val cachedCount by viewModel.cachedCount.collectAsState()

            SettingsScreen(
                settings = settings,
                cachedTranslationCount = cachedCount,
                onSettingsChanged = { viewModel.updateSettings(it) },
                onClearTranslations = { viewModel.clearAllTranslations() },
                onBack = { navController.popBackStack() },
            )
        }
    }
}

@Composable
private fun CrashReportView(report: String) {
    Column(modifier = Modifier.fillMaxSize().padding(16.dp)) {
        Text("Crash Report", style = MaterialTheme.typography.titleLarge,
            color = MaterialTheme.colorScheme.error)
        Spacer(Modifier.height(12.dp))
        Box(
            modifier = Modifier.weight(1f).verticalScroll(rememberScrollState())
        ) {
            SelectionContainer {
                Text(report, style = MaterialTheme.typography.bodySmall,
                    fontFamily = FontFamily.Monospace)
            }
        }
        Spacer(Modifier.height(12.dp))
        Text("Please share this crash report. The app will work normally after you navigate away.",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}
