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
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.dualreader.app.util.AppLogger
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch
import com.dualreader.app.ui.screens.*
import java.io.File
import java.util.UUID

private const val TAG = "NavHost"

private fun copyEpubToInternalStorage(context: Context, uri: Uri): String? {
    val epubsDir = File(context.filesDir, "epubs").apply { mkdirs() }
    val fileName = "${UUID.randomUUID()}.epub"
    val destFile = File(epubsDir, fileName)
    
    return try {
        context.contentResolver.openInputStream(uri)?.use { input ->
            destFile.outputStream().use { output -> input.copyTo(output) }
        } ?: return null
        Log.d(TAG, "EPUB copied to ${destFile.absolutePath}")
        destFile.absolutePath
    } catch (e: kotlinx.coroutines.CancellationException) {
        // Clean up partially copied file on cancellation
        // DR-111: Wrap delete() in try-catch to ensure CancellationException is always propagated
        if (destFile.exists()) {
            try {
                destFile.delete()
            } catch (deleteError: Exception) {
                Log.e(TAG, "Failed to delete partially copied file during cancellation: ${destFile.absolutePath}", deleteError)
            }
        }
        throw e
    } catch (e: Exception) {
        // Clean up partially copied file on other errors
        if (destFile.exists()) {
            try {
                destFile.delete()
            } catch (deleteError: Exception) {
                Log.e(TAG, "Failed to delete partially copied file: ${destFile.absolutePath}", deleteError)
            }
        }
        Log.e(TAG, "Error copying EPUB from URI: $uri", e)
        null
    }
}

@Composable
fun DualReaderNavHost(
    startOnboarding: Boolean = false,
    onOnboardingComplete: () -> Unit = {},
) {
    val navController = rememberNavController()
    val context = LocalContext.current

    NavHost(
        navController = navController,
        startDestination = if (startOnboarding) "onboarding" else "library",
    ) {
        // ── Onboarding ────────────────────────────────────────────────
        composable("onboarding") {
            OnboardingScreen(
                onComplete = {
                    onOnboardingComplete()
                    navController.navigate("library") {
                        popUpTo("onboarding") { inclusive = true }
                    }
                },
            )
        }

        // ── Paywall ───────────────────────────────────────────────────
        composable("paywall") {
            PaywallScreen(
                onDismiss = { navController.popBackStack() },
            )
        }

        // ── Library ──────────────────────────────────────────────────
        composable("library") {
            val viewModel: LibraryViewModel = hiltViewModel()
            val uiState by viewModel.uiState.collectAsState()

            // Check for crash report from previous run
            val crashReport = remember {
                val file = File(context.filesDir, "last_crash.txt")
                if (file.exists()) {
                    try {
                        val text = file.readText()
                        file.delete()
                        text
                    } catch (e: Exception) {
                        Log.e(TAG, "Failed to read or delete crash report: ${e.message}", e)
                        null
                    }
                } else null
            }
            var crashReportVisible by remember { mutableStateOf(crashReport != null) }

            // Show crash report as dismissible dialog, not blocking the library
                val epubPickerLauncher = rememberLauncherForActivityResult(
                    contract = ActivityResultContracts.OpenDocument()
                ) { uri: Uri? ->
                    uri?.let { pickedUri ->
                        val savedPath = copyEpubToInternalStorage(context, pickedUri)
                        if (savedPath != null) viewModel.importBook(savedPath)
                    }
                }

                // SAF launcher for exporting bookmarks from library
                val libraryScope = rememberCoroutineScope()
                var pendingLibraryExport by remember { mutableStateOf<Pair<String, String>?>(null) }
                val libraryExportLauncher = rememberLauncherForActivityResult(
                    contract = ActivityResultContracts.CreateDocument("text/plain")
                ) { uri: Uri? ->
                    uri?.let { u ->
                        pendingLibraryExport?.let { (content, _) ->
                            try {
                                context.contentResolver.openOutputStream(u)?.use { os ->
                                    os.write(content.toByteArray(Charsets.UTF_8))
                                }
                            } catch (e: CancellationException) {
                                throw e // Preserve coroutine cancellation semantics (DR-204)
                            } catch (e: Exception) {
                                AppLogger.e("Failed to export bookmarks from library: ${e.message}", e)
                            }
                        }
                        pendingLibraryExport = null
                    }
                }

                val allTags by viewModel.allTags.collectAsState()
                val collections by viewModel.collections.collectAsState()

                LibraryScreen(
                    uiState = uiState,
                    onBookClick = { bookId -> navController.navigate("reader/$bookId") },
                    onImportClick = { epubPickerLauncher.launch(arrayOf("application/epub+zip")) },
                    onSettingsClick = { navController.navigate("settings") },
                    onUpgradeClick = { navController.navigate("paywall") },
                    onRetryPagination = { book -> viewModel.retryPagination(book, 1080, 1000) },
                    onDeleteBook = { viewModel.deleteBook(it) },
                    onExportBookmarks = { bookId ->
                        libraryScope.launch {
                            val result = viewModel.formatBookmarksForExport(
                                bookId,
                                com.dualreader.app.domain.export.ExportFormat.MARKDOWN,
                            )
                            if (result != null) {
                                pendingLibraryExport = result
                                libraryExportLauncher.launch(result.second)
                            }
                        }
                    },
                    allTags = allTags,
                    selectedTag = viewModel.selectedTag,
                    onTagSelected = { viewModel.setSelectedTag(it) },
                    sortOrder = viewModel.currentSortOrder,
                    onSortOrderChanged = { viewModel.setSortOrder(it) },
                    onAddTagToBook = { bookId, tag -> viewModel.addTagToBook(bookId, tag) },
                    onRemoveTagFromBook = { bookId, tag -> viewModel.removeTagFromBook(bookId, tag) },
                    collections = collections,
                    onCreateCollection = { viewModel.createCollection(it) },
                    onDeleteCollection = { viewModel.deleteCollection(it) },
                    onAddBookToCollection = { collectionId, bookId ->
                        viewModel.addBookToCollection(collectionId, bookId)
                    },
                    onRemoveBookFromCollection = { collectionId, bookId ->
                        viewModel.removeBookFromCollection(collectionId, bookId)
                    },
                    errorEvents = viewModel.errorEvents,
                )

            // Crash report dialog (non-blocking, dismissible)
            if (crashReportVisible && crashReport != null) {
                AlertDialog(
                    onDismissRequest = { crashReportVisible = false },
                    title = { Text("⚠️ Crash Report") },
                    text = {
                        Text(
                            text = crashReport.take(500),
                            style = MaterialTheme.typography.bodySmall,
                        )
                    },
                    confirmButton = {
                        TextButton(onClick = { crashReportVisible = false }) {
                            Text("Dismiss")
                        }
                    },
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
            val ttsState by viewModel.ttsState.collectAsState()

            // Reload pages from DB when returning to reader (e.g., after clearing translations in Settings)
            val lifecycleOwner = LocalLifecycleOwner.current
            DisposableEffect(lifecycleOwner) {
                val observer = androidx.lifecycle.LifecycleEventObserver { _, event ->
                    if (event == androidx.lifecycle.Lifecycle.Event.ON_RESUME) {
                        viewModel.reloadPages()
                    }
                }
                lifecycleOwner.lifecycle.addObserver(observer)
                onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
            }

            // SAF launcher for exporting bookmarks
            var pendingExportContent by remember { mutableStateOf<String?>(null) }

            val safLauncher = rememberLauncherForActivityResult(
                contract = ActivityResultContracts.CreateDocument("text/plain")
            ) { uri: Uri? ->
                uri?.let { u ->
                    pendingExportContent?.let { content ->
                        try {
                            context.contentResolver.openOutputStream(u)?.use { os ->
                                os.write(content.toByteArray(Charsets.UTF_8))
                            }
                        } catch (e: CancellationException) {
                            throw e // Preserve coroutine cancellation semantics (DR-204)
                        } catch (e: Exception) {
                            AppLogger.e("Failed to export bookmarks from reader: ${e.message}", e)
                        }
                    }
                    pendingExportContent = null
                }
            }

            ReaderScreen(
                uiState = uiState,
                onBack = { navController.popBackStack() },
                onTranslateCurrentPage = { viewModel.translateCurrentPage() },
                onAddBookmark = { viewModel.addBookmark(it) },
                onRemoveBookmark = { viewModel.removeBookmark(it) },
                onToggleImmersive = { viewModel.toggleImmersiveMode() },
                onSettingsClick = { navController.navigate("settings") },
                onSearch = { viewModel.search(it) },
                onClearSearch = { viewModel.clearSearch() },
                searchQuery = searchQuery,
                searchResults = searchResults,
                onExportBookmarks = { format ->
                    val content = viewModel.formatBookmarks(format)
                    val fileName = viewModel.exportFileName(format)
                    pendingExportContent = content
                    safLauncher.launch(fileName)
                },
                ttsState = ttsState,
                onTtsPlay = { viewModel.speakCurrentPage() },
                onTtsPlayParagraph = { idx -> viewModel.speakParagraph(idx) },
                onTtsStop = { viewModel.stopTts() },
                onTtsPause = { viewModel.pauseTts() },
                onTtsSetRate = { rate -> viewModel.setTtsSpeechRate(rate) },
                onUpdateCurrentPage = { idx -> viewModel.updateCurrentPage(idx) },
                positionHistory = viewModel.positionHistory.collectAsState().value,
                onJumpToPosition = { idx -> viewModel.jumpToPosition(idx) },
                wordTranslation = viewModel.wordTranslation.collectAsState().value,
                onTranslateWord = { word, isOrig -> viewModel.translateWord(word, isOrig) },
                onDismissWordTranslation = { viewModel.dismissWordTranslation() },
                onTranslateParagraph = { idx -> viewModel.translateParagraph(idx) },
                onReTranslateParagraph = { idx -> viewModel.reTranslateParagraph(idx) },
                paragraphsTranslating = viewModel.paragraphsTranslating.collectAsState().value,
                translationEvents = viewModel.translationEvents,
                onRetryTranslation = { viewModel.translateCurrentPage() },
                onDownloadModel = { viewModel.downloadModelForCurrentLang() },
            )
        }

        // ── Settings ─────────────────────────────────────────────────
        composable("settings") {
            val viewModel: SettingsViewModel = hiltViewModel()
            val settings by viewModel.settings.collectAsState()
            val cachedCount by viewModel.cachedCount.collectAsState()
            val translationInfo by viewModel.translationInfo.collectAsState()
            val clearError by viewModel.clearError.collectAsState()
            // DR-115: Collect loadInfoError to show errors when loading translation info
            val loadInfoError by viewModel.loadInfoError.collectAsState()

            // DR-113: Show snackbar when clear fails
            val scope = rememberCoroutineScope()
            val snackbarHostState = remember { SnackbarHostState() }

            LaunchedEffect(clearError) {
                clearError?.let { error ->
                    val result = snackbarHostState.showSnackbar(
                        message = error,
                        duration = SnackbarDuration.Long,
                        actionLabel = "Dismiss"
                    )
                    if (result == SnackbarResult.ActionPerformed || result == SnackbarResult.Dismissed) {
                        viewModel.clearErrorShown()
                    }
                }
            }

            Scaffold(
                snackbarHost = { SnackbarHost(snackbarHostState) }
            ) { padding ->
                Box(modifier = Modifier.padding(padding)) {
                    SettingsScreen(
                        settings = settings,
                        cachedTranslationCount = cachedCount,
                        translationInfo = translationInfo,
                        loadInfoError = loadInfoError,
                        onSettingsChanged = { viewModel.updateSettings(it) },
                        onClearTranslations = { viewModel.clearAllTranslations() },
                        onViewTranslationInfo = { viewModel.loadTranslationInfo() },
                        onInfoErrorShown = { viewModel.loadInfoErrorShown() },
                        onUpgradeClick = { navController.navigate("paywall") },
                        onModelManagementClick = { navController.navigate("models") },
                        onTermsClick = { navController.navigate("terms") },
                        onBack = { navController.popBackStack() },
                    )
                }
            }
        }

        composable("models") {
            ModelManagementScreen(
                onBack = { navController.popBackStack() },
            )
        }

        composable("terms") {
            LegalScreen(
                title = "Terms of Service",
                assetPath = "legal/terms-of-service.md",
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
