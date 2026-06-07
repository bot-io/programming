package com.dualreader.app.ui.navigation

import android.content.Context
import android.net.Uri
import android.util.Log
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.platform.LocalContext
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

/**
 * Copies an EPUB from a content URI (SAF picker) to internal storage.
 * Returns the absolute file path on success, or null on failure.
 */
private fun copyEpubToInternalStorage(context: Context, uri: Uri): String? {
    return try {
        val epubsDir = File(context.filesDir, "epubs").apply { mkdirs() }
        val fileName = "${UUID.randomUUID()}.epub"
        val destFile = File(epubsDir, fileName)

        context.contentResolver.openInputStream(uri)?.use { input ->
            destFile.outputStream().use { output ->
                input.copyTo(output)
            }
        } ?: run {
            Log.e(TAG, "Failed to open input stream for URI: $uri")
            return null
        }

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

    NavHost(
        navController = navController,
        startDestination = "library",
    ) {
        // ── Library ──────────────────────────────────────────────────
        composable("library") {
            val viewModel: LibraryViewModel = hiltViewModel()
            val uiState by viewModel.uiState.collectAsState()

            // SAF launcher must be created at the top level of the composable,
            // outside any callback or conditional block (Compose requirement).
            val epubPickerLauncher = rememberLauncherForActivityResult(
                contract = ActivityResultContracts.OpenDocument()
            ) { uri: Uri? ->
                uri?.let { pickedUri ->
                    val savedPath = copyEpubToInternalStorage(context, pickedUri)
                    if (savedPath != null) {
                        viewModel.importBook(savedPath)
                    }
                }
            }

            LibraryScreen(
                uiState = uiState,
                onBookClick = { bookId ->
                    navController.navigate("reader/$bookId")
                },
                onImportClick = {
                    epubPickerLauncher.launch(arrayOf("application/epub+zip"))
                },
                onSettingsClick = {
                    navController.navigate("settings")
                },
                onRetryPagination = { book ->
                    viewModel.retryPagination(book, 1080, 2280)
                },
                onDeleteBook = { viewModel.deleteBook(it) },
            )
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
            )
        }

        // ── Settings ─────────────────────────────────────────────────
        composable("settings") {
            val viewModel: SettingsViewModel = hiltViewModel()
            val settings by viewModel.settings.collectAsState()

            SettingsScreen(
                settings = settings,
                onSettingsChanged = { viewModel.updateSettings(it) },
                onBack = { navController.popBackStack() },
            )
        }
    }
}
