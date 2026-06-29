package com.dualreader.app.ui.screens

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.dualreader.app.domain.entities.DisplayMode
import com.dualreader.app.domain.entities.ReaderTheme
import com.dualreader.app.domain.entities.ReadingSettings
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File
import java.util.Locale

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(
    settings: ReadingSettings,
    cachedTranslationCount: Int,
    translationInfo: List<PageTranslationInfo>,
    loadInfoError: String?,
    onSettingsChanged: (ReadingSettings) -> Unit,
    onClearTranslations: () -> Unit,
    onViewTranslationInfo: () -> Unit,
    onInfoErrorShown: () -> Unit,
    onUpgradeClick: () -> Unit,
    onModelManagementClick: () -> Unit,
    onTermsClick: () -> Unit,
    onBack: () -> Unit,
) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Reading Settings") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, "Back")
                    }
                },
            )
        }
    ) { padding ->
        // Local state for sliders — updates UI instantly, writes to DB only on drag end
        var localFontSize by remember { mutableStateOf(settings.fontSize) }
        var localLineHeight by remember { mutableStateOf(settings.lineHeight) }
        var localMargins by remember { mutableStateOf(settings.margins.toFloat()) }

        // Sync local state when external settings change (e.g., from another screen)
        // Use a single LaunchedEffect to avoid coroutine restart thrashing when settings update rapidly
        LaunchedEffect(settings) {
            if (localFontSize != settings.fontSize) localFontSize = settings.fontSize
            if (localLineHeight != settings.lineHeight) localLineHeight = settings.lineHeight
            if (localMargins != settings.margins.toFloat()) localMargins = settings.margins.toFloat()
        }

        Column(
            Modifier
                .padding(padding)
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(24.dp),
        ) {
            // ── Font Size ────────────────────────────────────────────
            SettingsSection("Font Size") {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text("A", fontSize = 12.sp, fontFamily = FontFamily.Serif)
                    Slider(
                        value = localFontSize,
                        onValueChange = { localFontSize = it },
                        onValueChangeFinished = { onSettingsChanged(settings.copy(fontSize = localFontSize)) },
                        valueRange = 12f..32f,
                        steps = 9,
                        modifier = Modifier.weight(1f).padding(horizontal = 8.dp),
                    )
                    Text("A", fontSize = 24.sp, fontFamily = FontFamily.Serif)
                }
                Text(
                    "${localFontSize.toInt()} sp",
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }

            // ── Line Height ──────────────────────────────────────────
            SettingsSection("Line Spacing") {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text("Compact")
                    Slider(
                        value = localLineHeight,
                        onValueChange = { localLineHeight = it },
                        onValueChangeFinished = { onSettingsChanged(settings.copy(lineHeight = localLineHeight)) },
                        valueRange = 1.0f..2.5f,
                        steps = 5,
                        modifier = Modifier.weight(1f).padding(horizontal = 8.dp),
                    )
                    Text("Relaxed")
                    }
                    Text(
                        // DR-103: Use Locale.US for consistent decimal formatting across locales
                        String.format(Locale.US, "%.1fx", localLineHeight),
                        style = MaterialTheme.typography.labelMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
            }

            // ── Margins ──────────────────────────────────────────────
            SettingsSection("Page Margins") {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text("Narrow")
                    Slider(
                        value = localMargins,
                        onValueChange = { localMargins = it },
                        onValueChangeFinished = { onSettingsChanged(settings.copy(margins = localMargins.toInt())) },
                        valueRange = 0f..48f,
                        modifier = Modifier.weight(1f).padding(horizontal = 8.dp),
                    )
                    Text("Wide")
                }
                Text(
                    "${localMargins.toInt()} dp",
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }

            // ── Theme ────────────────────────────────────────────────
            SettingsSection("Reader Theme") {
                Column {
                    ReaderTheme.entries.forEach { theme ->
                        val colors = readerColors(theme)
                        Row(
                            Modifier
                                .fillMaxWidth()
                                .clickable { onSettingsChanged(settings.copy(theme = theme)) }
                                .padding(vertical = 8.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            RadioButton(
                                selected = settings.theme == theme,
                                onClick = { onSettingsChanged(settings.copy(theme = theme)) },
                            )
                            Spacer(Modifier.width(8.dp))
                            Surface(
                                color = colors.background,
                                shape = MaterialTheme.shapes.small,
                                modifier = Modifier.size(32.dp),
                            ) {
                                Box(contentAlignment = Alignment.Center) {
                                    Text(
                                        "Aa",
                                        color = colors.text,
                                        fontSize = 12.sp,
                                        fontFamily = FontFamily.Serif,
                                    )
                                }
                            }
                            Spacer(Modifier.width(12.dp))
                            Text(
                                theme.name.lowercase().replaceFirstChar { it.uppercase() },
                                style = MaterialTheme.typography.bodyLarge,
                            )
                        }
                    }
                }
            }

            // ── Target Language ──
            SettingsSection("Target Language") {
                val languages = listOf(
                    "bg" to "Bulgarian",
                    "en" to "English",
                    "de" to "German",
                    "fr" to "French",
                    "es" to "Spanish",
                    "it" to "Italian",
                    "pt" to "Portuguese",
                    "ru" to "Russian",
                    "zh" to "Chinese",
                    "ja" to "Japanese",
                    "ko" to "Korean",
                )
                Column {
                    languages.forEach { (code, name) ->
                        Row(
                            Modifier
                                .fillMaxWidth()
                                .clickable {
                                    onSettingsChanged(settings.copy(targetLanguage = code))
                                }
                                .padding(vertical = 8.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            RadioButton(
                                selected = settings.targetLanguage == code,
                                onClick = {
                                    onSettingsChanged(settings.copy(targetLanguage = code))
                                },
                            )
                            Spacer(Modifier.width(8.dp))
                            Text(name, style = MaterialTheme.typography.bodyLarge)
                        }
                    }
                }
            }

            // ── Screen Wake ──────────────────────────────────────────
            SettingsSection("Keep Screen On") {
                val options = listOf(5 to "5 min", 10 to "10 min", 15 to "15 min", 30 to "30 min", 60 to "1 hour", 0 to "Disabled")
                Column {
                    options.forEach { (minutes, label) ->
                        Row(
                            Modifier
                                .fillMaxWidth()
                                .clickable {
                                    onSettingsChanged(settings.copy(screenWakeTimeoutMinutes = minutes))
                                }
                                .padding(vertical = 6.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            RadioButton(
                                selected = settings.screenWakeTimeoutMinutes == minutes,
                                onClick = {
                                    onSettingsChanged(settings.copy(screenWakeTimeoutMinutes = minutes))
                                },
                            )
                            Spacer(Modifier.width(8.dp))
                            Text(label, style = MaterialTheme.typography.bodyLarge)
                        }
                    }
                }
            }

            // ── Sentence Counter ─────────────────────────────────────
            SettingsSection("Sentence Counter") {
                Row(
                    Modifier
                        .fillMaxWidth()
                        .padding(vertical = 4.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Column(Modifier.weight(1f)) {
                        Text("Show sentence numbers", style = MaterialTheme.typography.bodyLarge)
                        Text(
                            "Display numbered markers on the left side to help align original and translated text",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                    Switch(
                        checked = settings.sentenceCounterEnabled,
                        onCheckedChange = {
                            onSettingsChanged(settings.copy(sentenceCounterEnabled = it))
                        },
                    )
                }
            }

            // ── Display Mode ───────────────────────────────────
            SettingsSection("Bilingual Display") {
                Column(Modifier.fillMaxWidth().padding(vertical = 4.dp)) {
                    Row(
                        Modifier.fillMaxWidth(),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        FilterChip(
                            selected = settings.displayMode == DisplayMode.SPLIT,
                            onClick = {
                                onSettingsChanged(settings.copy(displayMode = DisplayMode.SPLIT))
                            },
                            label = { Text("Split") },
                        )
                        Spacer(Modifier.width(8.dp))
                        FilterChip(
                            selected = settings.displayMode == DisplayMode.INTERLEAVED,
                            onClick = {
                                onSettingsChanged(settings.copy(displayMode = DisplayMode.INTERLEAVED))
                            },
                            label = { Text("Interleaved") },
                        )
                    }
                    Spacer(Modifier.height(4.dp))
                    Text(
                        if (settings.displayMode == DisplayMode.INTERLEAVED)
                            "Each paragraph is followed by its translation — best for language learning"
                        else
                            "Original and translation in separate panels",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }

            // ── Translation Cache ──────────────────────────────
            SettingsSection("Translation Cache") {
                var showClearDialog by remember { mutableStateOf(false) }
                var showInfoDialog by remember { mutableStateOf(false) }

                Row(
                    Modifier
                        .fillMaxWidth()
                        .padding(vertical = 8.dp)
                        .clickable(enabled = cachedTranslationCount > 0) {
                            onViewTranslationInfo()
                            showInfoDialog = true
                        },
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Column(Modifier.weight(1f)) {
                        Text(
                            "Cached translations: $cachedTranslationCount",
                            style = MaterialTheme.typography.bodyLarge,
                            color = if (cachedTranslationCount > 0)
                                MaterialTheme.colorScheme.primary
                            else
                                MaterialTheme.colorScheme.onSurface,
                        )
                        Text(
                            if (cachedTranslationCount > 0) "Tap to view translation details"
                            else "No translations cached yet",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                    Spacer(Modifier.width(12.dp))
                    OutlinedButton(
                        onClick = { showClearDialog = true },
                        enabled = cachedTranslationCount > 0,
                    ) {
                        Text("Clear All")
                    }
                }

                if (showInfoDialog) {
                    TranslationInfoDialog(
                        translationInfo = translationInfo,
                        loadError = loadInfoError,
                        onDismiss = { showInfoDialog = false },
                        onErrorShown = onInfoErrorShown,
                    )
                }

                if (showClearDialog) {
                    AlertDialog(
                        onDismissRequest = { showClearDialog = false },
                        title = { Text("Clear all translations?") },
                        text = { Text("Cached translations will be deleted. Next time you translate a page, it will be re-translated from scratch. Your reading progress is not affected.") },
                        confirmButton = {
                            TextButton(onClick = {
                                onClearTranslations()
                                showClearDialog = false
                            }) {
                                Text("Clear")
                            }
                        },
                        dismissButton = {
                            TextButton(onClick = { showClearDialog = false }) {
                                Text("Cancel")
                            }
                        },
                    )
                }
            }

            // ── On-Device Models ─────────────────────────────────
            SettingsSection("Offline Translation") {
                Row(
                    Modifier.fillMaxWidth().padding(vertical = 4.dp)
                        .clickable { onModelManagementClick() },
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Column(Modifier.weight(1f)) {
                        Text("On-Device Language Models", style = MaterialTheme.typography.bodyLarge)
                        Text(
                            "Download language models for offline translation (~30MB each)",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                    Text("›", style = MaterialTheme.typography.titleLarge, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }

            // ── Upgrade ──────────────────────────────────────────────
            SettingsSection("Plan") {
                Column(
                    Modifier.fillMaxWidth(),
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    Text(
                        "Free Tier",
                        style = MaterialTheme.typography.bodyLarge,
                        color = MaterialTheme.colorScheme.onSurface,
                    )
                    Text(
                        "10 pages/day AI translation • 1 book",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    Spacer(Modifier.height(12.dp))
                    Button(
                        onClick = onUpgradeClick,
                        modifier = Modifier.fillMaxWidth(),
                        shape = androidx.compose.foundation.shape.RoundedCornerShape(12.dp),
                    ) {
                        Text("Upgrade to Pro or Premium")
                    }
                }
            }

            Spacer(Modifier.height(32.dp))

            // ── About ───────────────────────────────────────────────
            SettingsSection("About") {
                Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text(
                        text = "Dual Reader",
                        style = MaterialTheme.typography.bodyLarge,
                    )
                    var versionTapCount by remember { mutableStateOf(0) }
                    var showDebugPanel by remember { mutableStateOf(false) }
                    val context = LocalContext.current

                    Text(
                        text = "Version ${com.dualreader.app.BuildConfig.VERSION_NAME} (${com.dualreader.app.BuildConfig.VERSION_CODE})",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.clickable {
                            versionTapCount++
                            if (versionTapCount >= 7) {
                                versionTapCount = 0
                                showDebugPanel = true
                            }
                        }
                    )
                    Text(
                        text = "A dual-language EPUB reader with AI-powered translation.",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    Spacer(Modifier.height(4.dp))
                    Text(
                        text = "Privacy Policy",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.primary,
                        modifier = Modifier.clickable {
                            context.startActivity(
                                android.content.Intent(context, com.dualreader.app.ui.PrivacyPolicyActivity::class.java)
                            )
                        }
                    )
                    Text(
                        text = "Terms of Service",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.primary,
                        modifier = Modifier.clickable { onTermsClick() }
                    )

                    if (showDebugPanel) {
                        DebugPanel(
                            onDismiss = { showDebugPanel = false },
                        )
                    }
                }
            }

            Spacer(Modifier.height(32.dp))
        }
    }
}

/**
 * Dialog showing per-page translation details: languages + models used.
 */
@Composable
private fun TranslationInfoDialog(
    translationInfo: List<PageTranslationInfo>,
    loadError: String?,
    onDismiss: () -> Unit,
    onErrorShown: () -> Unit,
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Translation Details") },
        text = {
            if (loadError != null) {
                // DR-115: Show error message when loading fails
                Column {
                    Text(
                        text = "Failed to load translation details",
                        style = MaterialTheme.typography.titleMedium,
                        color = MaterialTheme.colorScheme.error,
                    )
                    Spacer(Modifier.height(8.dp))
                    Text(
                        text = loadError,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            } else if (translationInfo.isEmpty()) {
                Text("No translations found. Translate some pages first.")
            } else {
                Box(
                    Modifier
                        .fillMaxWidth()
                        .heightIn(max = 400.dp)
                        .verticalScroll(rememberScrollState())
                ) {
                    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text(
                            "${translationInfo.size} pages with translations",
                            style = MaterialTheme.typography.labelMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                        for (info in translationInfo) {
                            Card(
                                Modifier.fillMaxWidth(),
                                colors = CardDefaults.cardColors(
                                    containerColor = MaterialTheme.colorScheme.surfaceVariant,
                                ),
                            ) {
                                Column(Modifier.padding(8.dp)) {
                                    Text(
                                        "Page ${info.pageIndex}",
                                        style = MaterialTheme.typography.labelLarge,
                                    )
                                    for ((lang, text) in info.languages) {
                                        val model = info.models[lang]
                                        Text(
                                            buildString {
                                                append("$lang: ")
                                                append(text)
                                                if (model != null) append(" [$model]")
                                            },
                                            style = MaterialTheme.typography.bodySmall,
                                            maxLines = 2,
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            }
        },
        confirmButton = {
            TextButton(onClick = {
                if (loadError != null) onErrorShown()
                onDismiss()
            }) { Text("Close") }
        },
    )
}

@Composable
private fun SettingsSection(
    title: String,
    content: @Composable ColumnScope.() -> Unit,
) {
    Column {
        Text(
            title,
            style = MaterialTheme.typography.titleSmall,
            color = MaterialTheme.colorScheme.primary,
        )
        Spacer(Modifier.height(8.dp))
        content()
    }
}

/**
 * Developer debug panel — shown after tapping the version text 7 times.
 * Displays crash logs and recent logcat output for in-app debugging.
 */
@Composable
private fun DebugPanel(
    onDismiss: () -> Unit,
) {
    val context = LocalContext.current
    var debugLog by remember { mutableStateOf("Loading…") }

    LaunchedEffect(Unit) {
        withContext(Dispatchers.IO) {
            debugLog = buildString {
                // ── App info ──
                appendLine("=== Dual Reader Debug Info ===")
                appendLine("Version: ${com.dualreader.app.BuildConfig.VERSION_NAME} (${com.dualreader.app.BuildConfig.VERSION_CODE})")
                
                // DR-116: Show write failures if any
                val writeFailures = com.dualreader.app.util.AppLogger.getConsecutiveWriteFailures()
                if (writeFailures > 0) {
                    appendLine()
                    appendLine("⚠️  WARNING: Log file write failures detected")
                    appendLine("Consecutive failures: $writeFailures")
                    appendLine("Logs may be incomplete. Check storage permissions and disk space.")
                    appendLine("Falling back to Android Log (logcat).")
                }
                appendLine()

                // ── Last crash log ──
                val crashFile = File(context.filesDir, "last_crash.txt")
                if (crashFile.exists()) {
                    appendLine("=== Last Crash ===")
                    appendLine(crashFile.readText().take(3000))
                    appendLine()
                } else {
                    appendLine("=== No crash log ===")
                    appendLine()
                }

                // ── Recent app logs (from file, works on all devices) ──
                appendLine("=== App Logs ===")
                appendLine(com.dualreader.app.util.AppLogger.getRecentLogs(200))
            }
        }
    }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Debug Info") },
        text = {
            Box(
                Modifier
                    .fillMaxWidth()
                    .heightIn(max = 400.dp)
                    .verticalScroll(rememberScrollState())
            ) {
                SelectionContainer {
                    Text(
                        debugLog,
                        style = MaterialTheme.typography.bodySmall,
                        fontFamily = FontFamily.Monospace,
                    )
                }
            }
        },
        confirmButton = {
            Row {
                TextButton(onClick = {
                    // Copy to clipboard
                    val clipboard = context.getSystemService(android.content.Context.CLIPBOARD_SERVICE)
                        as android.content.ClipboardManager
                    clipboard.setPrimaryClip(
                        android.content.ClipData.newPlainText("Debug Log", debugLog)
                    )
                }) { Text("Copy") }
                TextButton(onClick = onDismiss) { Text("Close") }
            }
        },
    )
}
