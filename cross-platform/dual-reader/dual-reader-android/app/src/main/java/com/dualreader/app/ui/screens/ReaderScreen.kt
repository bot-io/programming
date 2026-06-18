package com.dualreader.app.ui.screens

import android.app.Activity
import android.view.WindowManager
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.tween
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.shape.RoundedCornerShape
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
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.BaselineShift
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.dualreader.app.domain.entities.Book
import com.dualreader.app.domain.entities.Bookmark
import com.dualreader.app.domain.entities.DisplayMode
import com.dualreader.app.domain.entities.Page
import com.dualreader.app.domain.entities.ReaderTheme
import com.dualreader.app.domain.entities.ReadingSettings
import com.dualreader.app.data.translation.ParagraphAligner
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

/**
 * Animated version of [ReaderColors] — each color smoothly transitions when the theme changes.
 * Uses [animateColorAsState] for a 400ms cross-fade between themes.
 */
@Composable
fun animatedReaderColors(theme: ReaderTheme): ReaderColors {
    val target = readerColors(theme)
    return ReaderColors(
        background = animateColorAsState(target.background, animationSpec = tween(400), label = "bg").value,
        text = animateColorAsState(target.text, animationSpec = tween(400), label = "text").value,
        textSecondary = animateColorAsState(target.textSecondary, animationSpec = tween(400), label = "text2").value,
        divider = animateColorAsState(target.divider, animationSpec = tween(400), label = "divider").value,
        accent = animateColorAsState(target.accent, animationSpec = tween(400), label = "accent").value,
    )
}

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
    ReaderTheme.NIGHT -> ReaderColors(
        background = Color(0xFF000000), text = Color(0xFFE0E0E0),
        textSecondary = Color(0xFFB0B0B0), divider = Color(0xFF1A1A1A), accent = Color(0xFF6C63FF),
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

/** Regex matching a potential sentence boundary: punctuation + optional quotes + whitespace. */
private val boundaryRegex = Regex("""([.!?…]["'"»'')\]]{0,3})(\s+)""")

/** Known abbreviations whose trailing dot is NOT a sentence boundary. */
private val ABBREVIATIONS = setOf(
    "dr", "mr", "mrs", "ms", "prof", "st", "jr", "sr", "vs", "no",
    "gen", "sgt", "lt", "col", "capt", "pvt", "rep", "sen", "rev",
    "hon", "pres", "gov", "inc", "ltd", "corp", "co", "etc", "ed",
    "al", "vol", "min", "max", "fig", "approx", "apt", "dept", "est",
)

/**
 * Check whether the punctuation at [punctPos] in [text] follows an abbreviation or initial.
 * Walks backwards from the punctuation, skipping any quotes, then collects the preceding
 * word and checks it against [ABBREVIATIONS] or the single-uppercase-letter pattern.
 */
private fun isAbbreviationBoundary(text: String, punctPos: Int): Boolean {
    if (punctPos <= 0) return false
    var i = punctPos - 1
    // Skip trailing quotes/brackets before the punctuation
    while (i >= 0 && text[i] in "\"'»\u201C\u201D\u2018\u2019)]}\u00AB") i--
    val wordEnd = i + 1
    // Collect the preceding word (letters only)
    while (i >= 0 && text[i].isLetter()) i--
    val word = text.substring(i + 1, wordEnd)
    if (word.isEmpty()) return false
    // Single uppercase Latin or Cyrillic letter = initial (A., И.)
    if (word.length == 1 && (word[0] in 'A'..'Z' || word[0] in '\u0410'..'\u042F')) return true
    return word.lowercase() in ABBREVIATIONS
}

/**
 * Split text into sentences, correctly handling abbreviations (Dr., Mr., etc.)
 * and single-letter initials (A., И.).
 *
 * Uses a two-phase approach: first finds all potential boundaries, then filters
 * out those following abbreviations.
 */
internal fun splitSentences(text: String): List<String> {
    if (text.isBlank()) return emptyList()
    val result = mutableListOf<String>()
    var last = 0
    for (m in boundaryRegex.findAll(text)) {
        val punctPos = m.range.first
        if (isAbbreviationBoundary(text, punctPos)) continue
        val boundary = m.range.last + 1
        val sentence = text.substring(last, boundary).trim()
        if (sentence.isNotEmpty()) result.add(sentence)
        last = boundary
    }
    val tail = text.substring(last).trim()
    if (tail.isNotEmpty()) result.add(tail)
    return if (result.isEmpty() && text.isNotBlank()) listOf(text.trim()) else result
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
    onTranslateCurrentPage: () -> Unit,
    onTranslateAll: () -> Unit,
    onTranslateParagraph: (Int) -> Unit = {},
    onAddBookmark: (String) -> Unit,
    onRemoveBookmark: (String) -> Unit,
    onToggleImmersive: () -> Unit,
    onSettingsClick: () -> Unit,
    onSearch: (String) -> Unit = {},
    onClearSearch: () -> Unit = {},
    searchQuery: String = "",
    searchResults: List<ReaderViewModel.SearchResult> = emptyList(),
    onExportBookmarks: (com.dualreader.app.domain.export.ExportFormat) -> Unit = {},
    // TTS
    ttsState: ReaderViewModel.TtsUiState = ReaderViewModel.TtsUiState(),
    onTtsPlay: () -> Unit = {},
    onTtsPlayParagraph: (Int) -> Unit = {},
    onTtsStop: () -> Unit = {},
    onTtsPause: () -> Unit = {},
    onTtsSetRate: (Float) -> Unit = {},
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
                pages = uiState.pages,
                currentPage = uiState.currentPage,
                settings = uiState.settings,
                bookmarks = uiState.bookmarks,
                isTranslating = uiState.isTranslating,
                translationError = uiState.translationError,
                onBack = onBack,
                onTranslateCurrentPage = onTranslateCurrentPage,
                onTranslateAll = onTranslateAll,
                onTranslateParagraph = onTranslateParagraph,
                onAddBookmark = onAddBookmark,
                onRemoveBookmark = onRemoveBookmark,
                onToggleImmersive = onToggleImmersive,
                onSettingsClick = onSettingsClick,
                onSearch = onSearch,
                onClearSearch = onClearSearch,
                searchQuery = searchQuery,
                searchResults = searchResults,
                onExportBookmarks = onExportBookmarks,
                ttsState = ttsState,
                onTtsPlay = onTtsPlay,
                onTtsPlayParagraph = onTtsPlayParagraph,
                onTtsStop = onTtsStop,
                onTtsPause = onTtsPause,
                onTtsSetRate = onTtsSetRate,
            )
        }
    }
}

// ─── Reader Content ──────────────────────────────────────────────────────────

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ReaderContent(
    book: Book,
    pages: List<Page>,
    currentPage: Page,
    settings: ReadingSettings,
    bookmarks: List<Bookmark>,
    isTranslating: Boolean,
    translationError: String? = null,
    onBack: () -> Unit,
    onTranslateCurrentPage: () -> Unit,
    onTranslateAll: () -> Unit,
    onTranslateParagraph: (Int) -> Unit,
    onAddBookmark: (String) -> Unit,
    onRemoveBookmark: (String) -> Unit,
    onToggleImmersive: () -> Unit,
    onSettingsClick: () -> Unit,
    onSearch: (String) -> Unit,
    onClearSearch: () -> Unit,
    searchQuery: String,
    searchResults: List<ReaderViewModel.SearchResult>,
    onExportBookmarks: (com.dualreader.app.domain.export.ExportFormat) -> Unit = {},
    // TTS
    ttsState: ReaderViewModel.TtsUiState = ReaderViewModel.TtsUiState(),
    onTtsPlay: () -> Unit = {},
    onTtsPlayParagraph: (Int) -> Unit = {},
    onTtsStop: () -> Unit = {},
    onTtsPause: () -> Unit = {},
    onTtsSetRate: (Float) -> Unit = {},
) {
    val colors = animatedReaderColors(settings.theme)
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val listState = rememberLazyListState()

    // Bars visible by default; the top-bar fullscreen button toggles them.
    var barsVisible by remember { mutableStateOf(true) }
    var showBookmarkDialog by remember { mutableStateOf(false) }
    var showBookmarkList by remember { mutableStateOf(false) }
    var showExportFormatPicker by remember { mutableStateOf(false) }
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
        // ── Paragraph List (scrollable) ────────────────────────────
        LazyColumn(
            state = listState,
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(
                top = if (barsVisible) 56.dp else 0.dp,
                bottom = if (ttsState.isSpeaking || ttsState.error != null) 88.dp else 8.dp,
            ),
        ) {
            items(
                items = pages,
                key = { page -> page.index },
            ) { page ->
                ParagraphCard(
                    originalText = page.originalText,
                    translation = page.effectiveTranslation(settings.targetLanguage),
                    hasTranslation = page.hasTranslation(settings.targetLanguage),
                    fontSize = settings.fontSize,
                    lineHeight = settings.lineHeight,
                    chapterIndex = page.chapterIndex,
                    isSpeaking = ttsState.isSpeaking && ttsState.currentParagraph == page.index,
                    colors = colors,
                    onTranslate = { onTranslateParagraph(page.index) },
                    onSpeak = { onTtsPlayParagraph(page.index) },
                )
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
                            IconButton(onClick = onTranslateAll) {
                                Icon(Icons.Default.Translate, "Translate all")
                            }
                            // TTS speaker toggle
                            IconButton(onClick = {
                                if (ttsState.isSpeaking) onTtsStop() else onTtsPlay()
                            }) {
                                Icon(
                                    if (ttsState.isSpeaking) Icons.Default.Stop else Icons.Default.VolumeUp,
                                    if (ttsState.isSpeaking) "Stop reading" else "Read aloud",
                                    tint = if (ttsState.isSpeaking) colors.accent else MaterialTheme.colorScheme.onSurface,
                                )
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
                                    scope.launch { listState.animateScrollToItem(result.pageIndex) }
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

        // ── TTS Control Bar (floating, always visible when speaking) ────
        if (ttsState.isSpeaking || ttsState.error != null) {
            TtsControlBar(
                ttsState = ttsState,
                colors = colors,
                onStop = onTtsStop,
                onPause = onTtsPause,
                onResume = onTtsPlay,
                onSetRate = onTtsSetRate,
                onDismissError = { /* error clears on next action */ },
                modifier = Modifier.align(Alignment.BottomCenter),
            )
        }
    }

    // Bookmark list bottom sheet
    if (showBookmarkList) {
        BookmarkListSheet(
            bookmarks = bookmarks,
            currentPageIndex = currentPage.index,
            onNavigateToBookmark = {
                scope.launch { listState.animateScrollToItem(it) }
            },
            onDeleteBookmark = onRemoveBookmark,
            onDismiss = { showBookmarkList = false },
            onExport = if (bookmarks.isNotEmpty()) {
                { showExportFormatPicker = true }
            } else null,
        )
    }

    // Export format picker dialog
    if (showExportFormatPicker) {
        ExportFormatDialog(
            onDismiss = { showExportFormatPicker = false },
            onSelectFormat = { format ->
                showExportFormatPicker = false
                showBookmarkList = false
                onExportBookmarks(format)
            },
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

// ─── Paragraph Card ──────────────────────────────────────────────────────────

/**
 * A single paragraph in the scrollable reader list.
 * Shows the original text, an optional translation box with a speak button,
 * and a "Translate" button when no translation exists yet.
 */
@Composable
private fun ParagraphCard(
    originalText: String,
    translation: String?,
    hasTranslation: Boolean,
    fontSize: Float,
    lineHeight: Float,
    chapterIndex: Int,
    isSpeaking: Boolean,
    colors: ReaderColors,
    onTranslate: () -> Unit,
    onSpeak: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(modifier = modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp)) {
        // Original text
        SelectionContainer {
            Text(
                text = originalText,
                fontSize = fontSize.sp,
                lineHeight = (fontSize * lineHeight).sp,
                color = colors.text,
                fontFamily = FontFamily.Serif,
            )
        }

        Spacer(Modifier.height(8.dp))

        // Translation box (if translation exists)
        if (translation != null) {
            Surface(
                shape = RoundedCornerShape(8.dp),
                color = colors.divider.copy(alpha = 0.3f),
                border = BorderStroke(1.dp, colors.divider),
                modifier = Modifier.fillMaxWidth(),
            ) {
                Column(Modifier.padding(12.dp)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(
                            text = "Translated",
                            style = MaterialTheme.typography.labelSmall,
                            color = colors.textSecondary,
                            fontStyle = FontStyle.Italic,
                        )
                        Spacer(Modifier.weight(1f))
                        IconButton(
                            onClick = onSpeak,
                            modifier = Modifier.size(36.dp),
                        ) {
                            Icon(
                                imageVector = if (isSpeaking) Icons.Default.Stop else Icons.Default.VolumeUp,
                                contentDescription = "Speak translation",
                                tint = colors.accent,
                            )
                        }
                    }
                    Spacer(Modifier.height(4.dp))
                    SelectionContainer {
                        Text(
                            text = translation,
                            fontSize = (fontSize * 0.92f).sp,
                            lineHeight = (fontSize * 0.92f * lineHeight).sp,
                            color = colors.textSecondary,
                            fontStyle = FontStyle.Italic,
                        )
                    }
                }
            }
        }

        // Translate button (if no translation yet)
        if (translation == null && !hasTranslation) {
            TextButton(onClick = onTranslate) {
                Icon(Icons.Default.Translate, contentDescription = null, Modifier.size(18.dp))
                Spacer(Modifier.width(4.dp))
                Text("Translate")
            }
        }

        HorizontalDivider(color = colors.divider.copy(alpha = 0.2f))
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
    onExport: (() -> Unit)? = null,
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
                // Export button above the bookmark list
                if (onExport != null) {
                    OutlinedButton(
                        onClick = onExport,
                        modifier = Modifier.fillMaxWidth().padding(bottom = 8.dp)
                    ) {
                        Icon(Icons.Default.IosShare, null, Modifier.size(18.dp))
                        Spacer(Modifier.width(8.dp))
                        Text("Export bookmarks")
                    }
                }

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

// ─── Export Format Picker Dialog ─────────────────────────────────────────────

@Composable
fun ExportFormatDialog(
    onDismiss: () -> Unit,
    onSelectFormat: (com.dualreader.app.domain.export.ExportFormat) -> Unit,
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Export format") },
        text = {
            Column {
                Text(
                    "Choose a format for the exported bookmarks:",
                    style = MaterialTheme.typography.bodyMedium,
                    modifier = Modifier.padding(bottom = 12.dp),
                )
                listOf(
                    com.dualreader.app.domain.export.ExportFormat.PLAIN_TEXT to "Plain Text (.txt)",
                    com.dualreader.app.domain.export.ExportFormat.MARKDOWN to "Markdown (.md)",
                    com.dualreader.app.domain.export.ExportFormat.JSON to "JSON (.json)",
                ).forEach { (format, label) ->
                    TextButton(
                        onClick = { onSelectFormat(format) },
                        modifier = Modifier.fillMaxWidth(),
                    ) {
                        Text(label)
                    }
                }
            }
        },
        confirmButton = {},
        dismissButton = {
            TextButton(onClick = onDismiss) { Text("Cancel") }
        },
    )
}

// ─── TTS Control Bar ──────────────────────────────────────────────────────────

/**
 * Floating control bar shown when TTS is active or has an error.
 * Shows play/pause, stop, speech rate slider, and current paragraph indicator.
 */
@Composable
private fun TtsControlBar(
    ttsState: ReaderViewModel.TtsUiState,
    colors: ReaderColors,
    onStop: () -> Unit,
    onPause: () -> Unit,
    onResume: () -> Unit,
    onSetRate: (Float) -> Unit,
    onDismissError: () -> Unit,
    modifier: Modifier = Modifier,
) {
    // Error state — show a small error banner
    if (ttsState.error != null && !ttsState.isSpeaking) {
        Surface(
            color = MaterialTheme.colorScheme.errorContainer,
            shadowElevation = 6.dp,
            modifier = modifier
                .padding(16.dp)
                .fillMaxWidth(),
        ) {
            Row(
                modifier = Modifier.padding(horizontal = 12.dp, vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Icon(Icons.Default.ErrorOutline, null, Modifier.size(18.dp),
                    tint = MaterialTheme.colorScheme.error)
                Spacer(Modifier.width(8.dp))
                Text(ttsState.error, style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onErrorContainer,
                    modifier = Modifier.weight(1f))
                IconButton(onClick = onDismissError, modifier = Modifier.size(24.dp)) {
                    Icon(Icons.Default.Close, "Dismiss", Modifier.size(16.dp))
                }
            }
        }
        return
    }

    // Active playback bar
    Surface(
        color = colors.background.copy(alpha = 0.95f),
        shadowElevation = 6.dp,
        modifier = modifier
            .padding(16.dp)
            .fillMaxWidth(),
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 12.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            // Play/Pause
            IconButton(onClick = if (ttsState.isSpeaking) onPause else onResume) {
                Icon(
                    if (ttsState.isSpeaking) Icons.Default.Pause else Icons.Default.PlayArrow,
                    if (ttsState.isSpeaking) "Pause" else "Resume",
                    tint = colors.accent,
                )
            }

            // Paragraph indicator
            Text(
                text = if (ttsState.currentParagraph >= 0) "¶ ${ttsState.currentParagraph + 1}" else "—",
                style = MaterialTheme.typography.labelSmall,
                color = colors.textSecondary,
                modifier = Modifier.width(40.dp),
            )

            // Speed slider (compact)
            Text("Aa", style = MaterialTheme.typography.labelSmall, color = colors.textSecondary)
            Slider(
                value = ttsState.speechRate,
                onValueChange = onSetRate,
                valueRange = 0.5f..2.0f,
                modifier = Modifier.weight(1f),
            )
            Text("${ttsState.speechRate}x", style = MaterialTheme.typography.labelSmall,
                color = colors.textSecondary, modifier = Modifier.width(32.dp))

            // Stop
            IconButton(onClick = onStop) {
                Icon(Icons.Default.Stop, "Stop", tint = MaterialTheme.colorScheme.error)
            }
        }
    }
}
