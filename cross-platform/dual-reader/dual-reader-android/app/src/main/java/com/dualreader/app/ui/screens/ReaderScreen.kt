package com.dualreader.app.ui.screens

import android.app.Activity
import android.view.WindowManager
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.BaselineShift
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.dualreader.app.domain.entities.Book
import com.dualreader.app.domain.entities.Bookmark
import com.dualreader.app.domain.entities.Page
import com.dualreader.app.domain.entities.ReaderTheme
import com.dualreader.app.domain.entities.ReadingSettings
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

// ─── Theme colors ────────────────────────────────────────────────────────────

data class ReaderColors(
    val background: Color,
    val text: Color,
    val textSecondary: Color,
    val divider: Color,
    val accent: Color,
)

@Composable
fun readerColors(theme: ReaderTheme): ReaderColors = when (theme) {
    ReaderTheme.DARK -> ReaderColors(
        background = Color(0xFF1A1A2E), text = Color(0xFFE0E0E0),
        textSecondary = Color(0xFFB0B0B0), divider = Color(0xFF333355), accent = Color(0xFF6C63FF),
    )
    ReaderTheme.LIGHT -> ReaderColors(
        background = Color(0xFFFFFBF5), text = Color(0xFF2D2D2D),
        textSecondary = Color(0xFF666666), divider = Color(0xFFE0D8CF), accent = Color(0xFF6C63FF),
    )
    ReaderTheme.SEPIA -> ReaderColors(
        background = Color(0xFFF4ECD8), text = Color(0xFF5B4636),
        textSecondary = Color(0xFF8B7355), divider = Color(0xFFD4C5A9), accent = Color(0xFF8B6914),
    )
    ReaderTheme.OCEAN -> ReaderColors(
        background = Color(0xFF0D1B2A), text = Color(0xFFE0FBFC),
        textSecondary = Color(0xFF98C1D9), divider = Color(0xFF1B3A4B), accent = Color(0xFF3D5A80),
    )
    ReaderTheme.FOREST -> ReaderColors(
        background = Color(0xFF1B2D1B), text = Color(0xFFD4E7C5),
        textSecondary = Color(0xFF99B88F), divider = Color(0xFF2D4A2D), accent = Color(0xFF6B8F6B),
    )
    ReaderTheme.MIDNIGHT -> ReaderColors(
        background = Color(0xFF0A0A1A), text = Color(0xFFD0D0E0),
        textSecondary = Color(0xFF8080A0), divider = Color(0xFF1A1A3A), accent = Color(0xFF5858B0),
    )
}

// ─── Search Highlighting ─────────────────────────────────────────────────────

fun highlightText(
    text: String,
    query: String,
    highlightColor: Color,
): AnnotatedString {
    if (query.isBlank()) return AnnotatedString(text)
    return buildAnnotatedString {
        var searchFrom = 0
        while (true) {
            val matchIndex = text.indexOf(query, searchFrom, ignoreCase = true)
            if (matchIndex == -1) {
                append(text.substring(searchFrom))
                break
            }
            append(text.substring(searchFrom, matchIndex))
            withStyle(SpanStyle(background = highlightColor)) {
                append(text.substring(matchIndex, matchIndex + query.length))
            }
            searchFrom = matchIndex + query.length
        }
    }
}

// ─── Sentence splitting ──────────────────────────────────────────────────────

/**
 * Split text into sentences.
 *
 * Strategy: match the boundary *between* the end-of-sentence punctuation
 * (plus optional trailing quotes/brackets) and the whitespace that follows,
 * without using a lookbehind.  We match the punctuation + quotes + space
 * and then split, keeping the punctuation/quotes on the preceding sentence
 * by using a capture group.
 *
 * Original regex crashed on Android because it used an unbounded lookbehind:
 *   (?<=[.!?…]["'"»'')\]]*\s+)
 * Android's ICU regex engine requires bounded-length lookbehinds.
 */
private val sentenceSplitRegex = Regex(
    """([.!?…]["'"»'')\]]{0,3})\s+"""
)

internal fun splitSentences(text: String): List<String> {
    if (text.isBlank()) return emptyList()
    // Replace the boundary with the captured punctuation + a null char,
    // then split on the null char. This preserves the punctuation on the
    // preceding sentence and trims the inter-sentence whitespace.
    val stitched = sentenceSplitRegex.replace(text) { match ->
        match.groupValues[1] + "\u0000"
    }
    return stitched.split('\u0000').filter { it.isNotBlank() }
}

// ─── Layout Mode ─────────────────────────────────────────────────────────────
// Side-by-side on wide screens (≥600dp), top/bottom split on phones

enum class ReaderLayoutMode { VERTICAL_SPLIT, SIDE_BY_SIDE }

@Composable
fun rememberLayoutMode(): ReaderLayoutMode {
    val config = LocalConfiguration.current
    return remember(config.screenWidthDp, config.screenHeightDp) {
        if (config.screenWidthDp >= 600) ReaderLayoutMode.SIDE_BY_SIDE
        else ReaderLayoutMode.VERTICAL_SPLIT
    }
}

// ─── Main Screen ─────────────────────────────────────────────────────────────

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ReaderScreen(
    uiState: ReaderUiState,
    onBack: () -> Unit,
    onNextPage: () -> Unit,
    onPreviousPage: () -> Unit,
    onTranslateCurrentPage: () -> Unit,
    onTranslateAll: () -> Unit,
    onAddBookmark: (String) -> Unit,
    onRemoveBookmark: (String) -> Unit,
    onToggleImmersive: () -> Unit,
    onGoToPage: (Int) -> Unit,
    onSettingsClick: () -> Unit,
    onSearch: (String) -> Unit = {},
    onClearSearch: () -> Unit = {},
    searchQuery: String = "",
    searchResults: List<ReaderViewModel.SearchResult> = emptyList(),
    onRePaginate: (widthPx: Int, heightPx: Int, density: Float) -> Unit = { _, _, _ -> },
) {
    when (uiState) {
        is ReaderUiState.Loading -> {
            Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                CircularProgressIndicator()
            }
        }
        is ReaderUiState.Error -> {
            Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                Column(horizontalAlignment = Alignment.CenterHorizontally,
                    modifier = Modifier.padding(24.dp)) {
                    Icon(Icons.Default.ErrorOutline, null, Modifier.size(48.dp), MaterialTheme.colorScheme.error)
                    Spacer(Modifier.height(16.dp))
                    SelectionContainer {
                        Text(uiState.message, style = MaterialTheme.typography.bodyLarge,
                            color = MaterialTheme.colorScheme.error, textAlign = TextAlign.Center)
                    }
                    Spacer(Modifier.height(16.dp))
                    Button(onClick = onBack) { Text("Go Back") }
                }
            }
        }
        is ReaderUiState.ReaderReady -> {
            ReaderContent(
                book = uiState.book,
                currentPage = uiState.currentPage,
                totalPages = uiState.book.totalPages,
                settings = uiState.settings,
                bookmarks = uiState.bookmarks,
                isTranslating = uiState.isTranslating,
                translationError = uiState.translationError,
                isRePaginating = uiState.isRePaginating,
                onBack = onBack,
                onNextPage = onNextPage,
                onPreviousPage = onPreviousPage,
                onTranslateCurrentPage = onTranslateCurrentPage,
                onTranslateAll = onTranslateAll,
                onAddBookmark = onAddBookmark,
                onRemoveBookmark = onRemoveBookmark,
                onToggleImmersive = onToggleImmersive,
                onGoToPage = onGoToPage,
                onSettingsClick = onSettingsClick,
                onSearch = onSearch,
                onClearSearch = onClearSearch,
                searchQuery = searchQuery,
                searchResults = searchResults,
                onRePaginate = onRePaginate,
            )
        }
    }
}

// ─── Reader Content ──────────────────────────────────────────────────────────

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ReaderContent(
    book: Book,
    currentPage: Page,
    totalPages: Int,
    settings: ReadingSettings,
    bookmarks: List<Bookmark>,
    isTranslating: Boolean,
    translationError: String? = null,
    isRePaginating: Boolean = false,
    onBack: () -> Unit,
    onNextPage: () -> Unit,
    onPreviousPage: () -> Unit,
    onTranslateCurrentPage: () -> Unit,
    onTranslateAll: () -> Unit,
    onAddBookmark: (String) -> Unit,
    onRemoveBookmark: (String) -> Unit,
    onToggleImmersive: () -> Unit,
    onGoToPage: (Int) -> Unit,
    onSettingsClick: () -> Unit,
    onSearch: (String) -> Unit,
    onClearSearch: () -> Unit,
    searchQuery: String,
    searchResults: List<ReaderViewModel.SearchResult>,
    onRePaginate: (widthPx: Int, heightPx: Int, density: Float) -> Unit = { _, _, _ -> },
) {
    val colors = readerColors(settings.theme)
    val layoutMode = rememberLayoutMode()
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    // Bars hidden by default — tap center of screen to show.
    var barsVisible by remember { mutableStateOf(false) }
    var showBookmarkDialog by remember { mutableStateOf(false) }
    var showBookmarkList by remember { mutableStateOf(false) }
    var showSearch by remember { mutableStateOf(false) }
    var searchInput by remember { mutableStateOf("") }

    // ── Keep screen awake ──────────────────────────────────────────
    DisposableEffect(settings.screenWakeTimeoutMinutes) {
        val activity = context as? Activity
        val window = activity?.window
        window?.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

        val timeoutMs = settings.screenWakeTimeoutMinutes * 60_000L
        val job = scope.launch {
            delay(timeoutMs)
            window?.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        }

        onDispose {
            job.cancel()
            window?.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        }
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(colors.background)
            .windowInsetsPadding(WindowInsets.systemBars)
    ) {
        // ── Content Area (fills entire screen) ─────────────────────
        // Measure the maximized content area and trigger pagination ONCE.
        // Bars overlay on top — they never resize the text area.
        var hasPaginated by remember { mutableStateOf(false) }

        Box(modifier = Modifier.fillMaxSize()
            .pointerInput(Unit) {
                detectTapGestures { offset ->
                    val third = size.width / 3
                    when {
                        offset.x < third -> onPreviousPage()
                        offset.x > size.width - third -> onNextPage()
                        else -> barsVisible = !barsVisible
                    }
                }
            }
            .onSizeChanged { size ->
                if (!hasPaginated && size.width > 0 && size.height > 0) {
                    hasPaginated = true
                    // Panel height: full screen for side-by-side, half for vertical split
                    val panelHeight = if (layoutMode == ReaderLayoutMode.VERTICAL_SPLIT) {
                        size.height / 2
                    } else {
                        size.height
                    }
                    val density = context.resources.displayMetrics.density
                    onRePaginate(size.width, panelHeight, density)
                }
            }
        ) {
            if (layoutMode == ReaderLayoutMode.SIDE_BY_SIDE) {
                Row(Modifier.fillMaxSize()) {
                    TextPanel("Original", currentPage.originalText,
                        settings.fontSize, settings.lineHeight, colors,
                        searchQuery, Modifier.weight(1f), showLabel = barsVisible,
                        sentenceCounterEnabled = settings.sentenceCounterEnabled)
                    Box(Modifier.width(2.dp).fillMaxHeight().background(colors.accent.copy(alpha = 0.5f)))
                    TranslationPanel(currentPage.effectiveTranslation(settings.targetLanguage), isTranslating, translationError,
                        settings.fontSize, settings.lineHeight, colors,
                        onTranslateCurrentPage, searchQuery, Modifier.weight(1f), showLabel = barsVisible,
                        sentenceCounterEnabled = settings.sentenceCounterEnabled)
                }
            } else {
                Column(Modifier.fillMaxSize()) {
                    TextPanel("Original", currentPage.originalText,
                        settings.fontSize, settings.lineHeight, colors,
                        searchQuery, Modifier.weight(1f), showLabel = barsVisible,
                        sentenceCounterEnabled = settings.sentenceCounterEnabled)
                    Box(Modifier.fillMaxWidth().height(2.dp).background(colors.accent.copy(alpha = 0.5f)))
                    TranslationPanel(currentPage.effectiveTranslation(settings.targetLanguage), isTranslating, translationError,
                        settings.fontSize, settings.lineHeight, colors,
                        onTranslateCurrentPage, searchQuery, Modifier.weight(1f), showLabel = barsVisible,
                        sentenceCounterEnabled = settings.sentenceCounterEnabled)
                }
            }

            // Re-pagination loading overlay
            if (isRePaginating) {
                Box(
                    Modifier.fillMaxSize().background(colors.background.copy(alpha = 0.7f)),
                    contentAlignment = Alignment.Center,
                ) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        CircularProgressIndicator(color = colors.accent)
                        Spacer(Modifier.height(8.dp))
                        Text("Re-paginating…", color = colors.text,
                            style = MaterialTheme.typography.bodySmall)
                    }
                }
            }
        }

        // ── Top Bar (overlays on top of content) ───────────────────
        AnimatedVisibility(
            visible = barsVisible,
            enter = fadeIn() + expandVertically(expandFrom = Alignment.Top),
            exit = fadeOut() + shrinkVertically(shrinkTowards = Alignment.Top),
            modifier = Modifier.align(Alignment.TopCenter),
        ) {
            Surface(
                color = colors.background.copy(alpha = 0.92f),
                shadowElevation = 4.dp,
            ) {
                TopAppBar(
                    title = {
                        if (showSearch) {
                            OutlinedTextField(
                                value = searchInput,
                                onValueChange = { searchInput = it; onSearch(it) },
                                placeholder = { Text("Search in book...") },
                                singleLine = true,
                                modifier = Modifier.fillMaxWidth(),
                                trailingIcon = {
                                    if (searchInput.isNotEmpty()) {
                                        IconButton(onClick = {
                                            searchInput = ""
                                            onClearSearch()
                                        }) { Icon(Icons.Default.Clear, "Clear") }
                                    }
                                }
                            )
                        } else {
                            Text(book.title, maxLines = 1, overflow = TextOverflow.Ellipsis,
                                style = MaterialTheme.typography.titleMedium)
                        }
                    },
                    navigationIcon = {
                        if (showSearch) {
                            IconButton(onClick = {
                                showSearch = false
                                searchInput = ""
                                onClearSearch()
                            }) { Icon(Icons.Default.ArrowBack, "Back") }
                        } else {
                            IconButton(onClick = onBack) {
                                Icon(Icons.AutoMirrored.Filled.ArrowBack, "Back")
                            }
                        }
                    },
                    actions = {
                        if (!showSearch) {
                            IconButton(onClick = { showSearch = true }) {
                                Icon(Icons.Default.Search, "Search")
                            }
                            if (bookmarks.isNotEmpty()) {
                                BadgedBox(badge = { Badge { Text("${bookmarks.size}") } }) {
                                    IconButton(onClick = { showBookmarkList = true }) {
                                        Icon(Icons.Default.BookmarkBorder, "Bookmarks")
                                    }
                                }
                            } else {
                                IconButton(onClick = { showBookmarkDialog = true }) {
                                    Icon(Icons.Default.BookmarkAdd, "Add bookmark")
                                }
                            }
                            IconButton(onClick = onTranslateCurrentPage) {
                                Icon(Icons.Default.Translate, "Translate page")
                            }
                            IconButton(onClick = onSettingsClick) {
                                Icon(Icons.Default.Settings, "Settings")
                            }
                            IconButton(onClick = { barsVisible = !barsVisible }) {
                                Icon(
                                    if (barsVisible) Icons.Default.Fullscreen else Icons.Default.FullscreenExit,
                                    if (barsVisible) "Fullscreen" else "Exit fullscreen",
                                )
                            }
                        }
                    },
                )
            }
        }

        // ── Search Results Dropdown (overlays on top) ──────────────
        AnimatedVisibility(
            visible = showSearch && searchResults.isNotEmpty(),
            enter = fadeIn(), exit = fadeOut(),
            modifier = Modifier.align(Alignment.TopCenter).padding(top = 56.dp),
        ) {
            Surface(
                color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.95f),
                shadowElevation = 2.dp,
            ) {
                Column(
                    Modifier
                        .fillMaxWidth(0.9f)
                        .heightIn(max = 200.dp)
                        .verticalScroll(rememberScrollState())
                        .padding(horizontal = 8.dp)
                ) {
                    Text(
                        "${searchResults.size} results",
                        style = MaterialTheme.typography.labelSmall,
                        modifier = Modifier.padding(4.dp),
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    searchResults.take(20).forEach { result ->
                        Row(
                            Modifier
                                .fillMaxWidth()
                                .clickable {
                                    onGoToPage(result.pageIndex)
                                    showSearch = false
                                    searchInput = ""
                                    onClearSearch()
                                }
                                .padding(vertical = 6.dp, horizontal = 8.dp)
                        ) {
                            Text("p${result.pageIndex + 1}", fontWeight = FontWeight.Bold,
                                color = MaterialTheme.colorScheme.primary,
                                modifier = Modifier.width(36.dp))
                            Text(result.snippet, maxLines = 1, overflow = TextOverflow.Ellipsis,
                                style = MaterialTheme.typography.bodySmall)
                        }
                        HorizontalDivider()
                    }
                }
            }
        }

        // ── Bottom Bar (overlays on top of content) ────────────────
        AnimatedVisibility(
            visible = barsVisible,
            enter = fadeIn() + expandVertically(expandFrom = Alignment.Bottom),
            exit = fadeOut() + shrinkVertically(shrinkTowards = Alignment.Bottom),
            modifier = Modifier.align(Alignment.BottomCenter),
        ) {
            Surface(
                color = colors.background.copy(alpha = 0.92f),
                shadowElevation = 4.dp,
            ) {
                BottomReaderBar(
                    currentPage = book.currentPage,
                    totalPages = totalPages,
                    onPrevious = onPreviousPage,
                    onNext = onNextPage,
                    onGoToPage = onGoToPage,
                    colors = colors,
                )
            }
        }
    }

    // Bookmark list bottom sheet
    if (showBookmarkList) {
        BookmarkListSheet(
            bookmarks = bookmarks,
            currentPageIndex = currentPage.index,
            onNavigateToBookmark = { onGoToPage(it) },
            onDeleteBookmark = onRemoveBookmark,
            onDismiss = { showBookmarkList = false },
        )
    }

    // Bookmark dialog
    if (showBookmarkDialog) {
        var note by remember { mutableStateOf("") }
        AlertDialog(
            onDismissRequest = { showBookmarkDialog = false },
            title = { Text("Add Bookmark") },
            text = {
                OutlinedTextField(value = note, onValueChange = { note = it },
                    label = { Text("Note (optional)") }, singleLine = true)
            },
            confirmButton = {
                TextButton(onClick = {
                    onAddBookmark(note); showBookmarkDialog = false
                }) { Text("Add") }
            },
            dismissButton = {
                TextButton(onClick = { showBookmarkDialog = false }) { Text("Cancel") }
            },
        )
    }
}

// ─── Text Panel ───────────────────────────────────────────────────────────────

@Composable
private fun TextPanel(
    label: String,
    text: String,
    fontSize: Float,
    lineHeight: Float,
    colors: ReaderColors,
    searchQuery: String = "",
    modifier: Modifier = Modifier,
    showLabel: Boolean = true,
    sentenceCounterEnabled: Boolean = false,
) {
    Column(modifier = modifier) {
        if (showLabel) {
            Box(Modifier.fillMaxWidth().background(colors.divider.copy(alpha = 0.3f))
                .padding(horizontal = 12.dp, vertical = 4.dp)) {
                Text(label, style = MaterialTheme.typography.labelSmall,
                    color = colors.textSecondary, fontWeight = FontWeight.Medium)
            }
        }
        if (sentenceCounterEnabled) {
            SentenceCountedText(
                text = text,
                fontSize = fontSize,
                lineHeight = lineHeight,
                colors = colors,
                searchQuery = searchQuery,
            )
        } else {
            Box(Modifier.fillMaxSize().verticalScroll(rememberScrollState())
                .padding(horizontal = 16.dp, vertical = 12.dp)) {
                val displayText = if (searchQuery.isNotBlank())
                    highlightText(text, searchQuery, colors.accent.copy(alpha = 0.35f))
                else AnnotatedString(text)
                SelectionContainer {
                    Text(text = displayText, color = colors.text,
                        fontSize = fontSize.sp, lineHeight = (fontSize * lineHeight).sp,
                        fontFamily = FontFamily.Serif)
                }
            }
        }
    }
}

// ─── Translation Panel ────────────────────────────────────────────────────────

@Composable
private fun TranslationPanel(
    translatedText: String?,
    isTranslating: Boolean,
    translationError: String? = null,
    fontSize: Float,
    lineHeight: Float,
    colors: ReaderColors,
    onTranslate: () -> Unit,
    searchQuery: String = "",
    modifier: Modifier = Modifier,
    showLabel: Boolean = true,
    sentenceCounterEnabled: Boolean = false,
) {
    Column(modifier = modifier) {
        if (showLabel) {
            Box(Modifier.fillMaxWidth().background(colors.divider.copy(alpha = 0.3f))
                .padding(horizontal = 12.dp, vertical = 4.dp)) {
                Text("Translation", style = MaterialTheme.typography.labelSmall,
                    color = colors.textSecondary, fontWeight = FontWeight.Medium)
            }
        }
        Box(Modifier.fillMaxSize().verticalScroll(rememberScrollState())
            .padding(horizontal = 16.dp, vertical = 12.dp),
            contentAlignment = Alignment.TopStart) {
            when {
                isTranslating -> {
                    Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
                        Spacer(Modifier.height(24.dp))
                        CircularProgressIndicator()
                        Spacer(Modifier.height(8.dp))
                        Text("Translating...", color = colors.textSecondary,
                            style = MaterialTheme.typography.bodyMedium)
                    }
                }
                translationError != null -> {
                    Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
                        Spacer(Modifier.height(24.dp))
                        Icon(Icons.Default.ErrorOutline, null, Modifier.size(36.dp),
                            tint = MaterialTheme.colorScheme.error.copy(alpha = 0.7f))
                        Spacer(Modifier.height(8.dp))
                        SelectionContainer {
                            Text(translationError, color = MaterialTheme.colorScheme.error,
                                style = MaterialTheme.typography.bodyMedium, textAlign = TextAlign.Center)
                        }
                        Spacer(Modifier.height(12.dp))
                        FilledTonalButton(onClick = onTranslate) {
                            Icon(Icons.Default.Refresh, null, Modifier.size(18.dp))
                            Spacer(Modifier.width(8.dp))
                            Text("Retry")
                        }
                    }
                }
                translatedText != null -> {
                    if (sentenceCounterEnabled) {
                        // Inline sentence counter — no surrounding Box
                        SentenceCountedTextInner(
                            text = translatedText,
                            fontSize = fontSize,
                            lineHeight = lineHeight,
                            colors = colors,
                            searchQuery = searchQuery,
                        )
                    } else {
                        val displayText = if (searchQuery.isNotBlank())
                            highlightText(translatedText, searchQuery, colors.accent.copy(alpha = 0.35f))
                        else AnnotatedString(translatedText)
                        SelectionContainer {
                            Text(text = displayText, color = colors.text,
                                fontSize = fontSize.sp, lineHeight = (fontSize * lineHeight).sp,
                                fontFamily = FontFamily.Serif)
                        }
                    }
                }
                else -> {
                    Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
                        Spacer(Modifier.height(24.dp))
                        Icon(Icons.Default.Translate, null, Modifier.size(36.dp),
                            tint = colors.textSecondary.copy(alpha = 0.6f))
                        Spacer(Modifier.height(8.dp))
                        Text("No translation yet", color = colors.textSecondary,
                            style = MaterialTheme.typography.bodyMedium)
                        Spacer(Modifier.height(12.dp))
                        FilledTonalButton(onClick = onTranslate) {
                            Icon(Icons.Default.Translate, null, Modifier.size(18.dp))
                            Spacer(Modifier.width(8.dp))
                            Text("Translate")
                        }
                    }
                }
            }
        }
    }
}

// ─── Sentence Counter Text ───────────────────────────────────────────────────
// Shows small numbered markers on the left at regular sentence intervals.
// Target: 5-6 cues per page, reset per page.

/**
 * Build an AnnotatedString with inline sentence counters.
 * Each sentence is prefixed with a small superscript number: ¹First sentence. ²Second sentence.
 * The numbers are always aligned with their sentence because they're part of the text flow.
 */
private fun buildSentenceCountedText(
    text: String,
    colors: ReaderColors,
    searchQuery: String = "",
): AnnotatedString {
    val sentences = splitSentences(text)
    if (sentences.isEmpty()) return AnnotatedString(text)

    return buildAnnotatedString {
        sentences.forEachIndexed { i, sentence ->
            val num = i + 1
            // Superscript-style inline marker
            withStyle(SpanStyle(
                fontSize = 9.sp,
                color = colors.textSecondary.copy(alpha = 0.6f),
                fontWeight = FontWeight.Medium,
                baselineShift = BaselineShift.Superscript,
            )) {
                append("$num")
            }
            // Thin space between number and sentence
            append("\u2009")
            // Apply search highlighting if needed
            if (searchQuery.isNotBlank() && sentence.contains(searchQuery, ignoreCase = true)) {
                val highlighted = highlightText(sentence, searchQuery, colors.accent.copy(alpha = 0.35f))
                append(highlighted)
            } else {
                append(sentence)
            }
            // Space between sentences (preserving original spacing)
            if (i < sentences.lastIndex) append(" ")
        }
    }
}

/** Sentence-counted text with its own scroll container (for TextPanel) */
@Composable
private fun SentenceCountedText(
    text: String,
    fontSize: Float,
    lineHeight: Float,
    colors: ReaderColors,
    searchQuery: String = "",
) {
    val annotatedText = remember(text, searchQuery) { buildSentenceCountedText(text, colors, searchQuery) }
    Box(Modifier.fillMaxSize().verticalScroll(rememberScrollState())
        .padding(horizontal = 8.dp, vertical = 12.dp)) {
        SelectionContainer {
            Text(
                text = annotatedText,
                color = colors.text,
                fontSize = fontSize.sp,
                lineHeight = (fontSize * lineHeight).sp,
                fontFamily = FontFamily.Serif,
            )
        }
    }
}

/** Sentence-counted text without outer scroll (for TranslationPanel, already inside a scroll) */
@Composable
private fun SentenceCountedTextInner(
    text: String,
    fontSize: Float,
    lineHeight: Float,
    colors: ReaderColors,
    searchQuery: String = "",
) {
    val annotatedText = remember(text, searchQuery) { buildSentenceCountedText(text, colors, searchQuery) }
    SelectionContainer {
        Text(
            text = annotatedText,
            color = colors.text,
            fontSize = fontSize.sp,
            lineHeight = (fontSize * lineHeight).sp,
            fontFamily = FontFamily.Serif,
            modifier = Modifier.fillMaxWidth(),
        )
    }
}

// ─── Bottom Bar ───────────────────────────────────────────────────────────────

@Composable
private fun BottomReaderBar(
    currentPage: Int,
    totalPages: Int,
    onPrevious: () -> Unit,
    onNext: () -> Unit,
    onGoToPage: (Int) -> Unit,
    colors: ReaderColors,
) {
    Surface(
        tonalElevation = 3.dp
    ) {
        Row(
            Modifier
                .fillMaxWidth()
                .padding(horizontal = 8.dp, vertical = 4.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
                IconButton(onClick = onPrevious, enabled = currentPage > 0) {
                    Icon(Icons.Default.NavigateBefore, "Previous page")
                }
                Slider(
                    value = if (totalPages > 1) currentPage.toFloat() / (totalPages - 1) else 0f,
                    onValueChange = { fraction ->
                        val page = (fraction * (totalPages - 1)).toInt().coerceIn(0, totalPages - 1)
                        onGoToPage(page)
                    },
                    modifier = Modifier.weight(1f),
                )
                Text("${currentPage + 1}/$totalPages", style = MaterialTheme.typography.labelMedium,
                    modifier = Modifier.padding(horizontal = 8.dp))
                IconButton(onClick = onNext, enabled = currentPage < totalPages - 1) {
                    Icon(Icons.Default.NavigateNext, "Next page")
                }
            }
    }
}

// ─── Bookmark List Bottom Sheet ──────────────────────────────────────────────

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun BookmarkListSheet(
    bookmarks: List<Bookmark>,
    currentPageIndex: Int,
    onNavigateToBookmark: (Int) -> Unit,
    onDeleteBookmark: (String) -> Unit,
    onDismiss: () -> Unit,
) {
    ModalBottomSheet(onDismissRequest = onDismiss) {
        Column(Modifier.fillMaxWidth().padding(horizontal = 16.dp)
            .windowInsetsPadding(WindowInsets.navigationBars)
            .padding(bottom = 16.dp)) {
            Text("Bookmarks", style = MaterialTheme.typography.headlineSmall,
                modifier = Modifier.padding(bottom = 16.dp))

            // Add bookmark button at top
            FilledTonalButton(
                onClick = {
                    onDismiss()
                    // Will need to trigger add from parent; for now, close sheet
                },
                modifier = Modifier.fillMaxWidth().padding(bottom = 12.dp)
            ) {
                Icon(Icons.Default.BookmarkAdd, null, Modifier.size(18.dp))
                Spacer(Modifier.width(8.dp))
                Text("Bookmark current page")
            }

            if (bookmarks.isEmpty()) {
                Box(Modifier.fillMaxWidth().padding(vertical = 32.dp),
                    contentAlignment = Alignment.Center) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Icon(Icons.Default.BookmarkBorder, null, Modifier.size(48.dp),
                            tint = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.5f))
                        Spacer(Modifier.height(8.dp))
                        Text("No bookmarks yet", style = MaterialTheme.typography.bodyLarge,
                            color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                }
            } else {
                bookmarks.sortedByDescending { it.createdAt }.forEach { bookmark ->
                    val isCurrentPage = bookmark.pageIndex == currentPageIndex
                    Card(
                        modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp)
                            .clickable { onNavigateToBookmark(bookmark.pageIndex); onDismiss() },
                        colors = CardDefaults.cardColors(
                            containerColor = if (isCurrentPage) MaterialTheme.colorScheme.primaryContainer
                            else MaterialTheme.colorScheme.surfaceVariant)
                    ) {
                        Row(Modifier.padding(12.dp), verticalAlignment = Alignment.Top) {
                            Icon(
                                if (isCurrentPage) Icons.Default.Bookmark else Icons.Default.BookmarkBorder,
                                null, Modifier.size(20.dp),
                                tint = if (isCurrentPage) MaterialTheme.colorScheme.primary
                                else MaterialTheme.colorScheme.onSurfaceVariant)
                            Spacer(Modifier.width(12.dp))
                            Column(Modifier.weight(1f)) {
                                Text("Page ${bookmark.pageIndex + 1}",
                                    style = MaterialTheme.typography.titleSmall,
                                    fontWeight = FontWeight.Medium)
                                if (bookmark.textSnippet.isNotBlank()) {
                                    Text(bookmark.textSnippet.take(80) +
                                        if (bookmark.textSnippet.length > 80) "..." else "",
                                        style = MaterialTheme.typography.bodySmall,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                                        maxLines = 2, overflow = TextOverflow.Ellipsis)
                                }
                                if (bookmark.note.isNotBlank()) {
                                    Spacer(Modifier.height(4.dp))
                                    Text("\uD83D\uDCDD ${bookmark.note}",
                                        style = MaterialTheme.typography.bodySmall,
                                        color = MaterialTheme.colorScheme.primary,
                                        fontWeight = FontWeight.Medium)
                                }
                            }
                            IconButton(onClick = { onDeleteBookmark(bookmark.id) },
                                modifier = Modifier.size(32.dp)) {
                                Icon(Icons.Default.DeleteOutline, "Delete",
                                    Modifier.size(18.dp),
                                    tint = MaterialTheme.colorScheme.error.copy(alpha = 0.7f))
                            }
                        }
                    }
                }
            }
        }
    }
}
