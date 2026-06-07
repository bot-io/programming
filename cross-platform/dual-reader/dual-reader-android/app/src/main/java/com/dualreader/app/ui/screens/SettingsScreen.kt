package com.dualreader.app.ui.screens

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.dualreader.app.domain.entities.ReaderTheme
import com.dualreader.app.domain.entities.ReadingSettings
import com.dualreader.app.domain.entities.TranslationProvider

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(
    settings: ReadingSettings,
    onSettingsChanged: (ReadingSettings) -> Unit,
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
                        value = settings.fontSize,
                        onValueChange = { onSettingsChanged(settings.copy(fontSize = it)) },
                        valueRange = 12f..32f,
                        steps = 9,
                        modifier = Modifier.weight(1f).padding(horizontal = 8.dp),
                    )
                    Text("A", fontSize = 24.sp, fontFamily = FontFamily.Serif)
                }
                Text(
                    "${settings.fontSize.toInt()} sp",
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }

            // ── Line Height ──────────────────────────────────────────
            SettingsSection("Line Spacing") {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text("Compact")
                    Slider(
                        value = settings.lineHeight,
                        onValueChange = { onSettingsChanged(settings.copy(lineHeight = it)) },
                        valueRange = 1.0f..2.5f,
                        steps = 5,
                        modifier = Modifier.weight(1f).padding(horizontal = 8.dp),
                    )
                    Text("Relaxed")
                }
                Text(
                    String.format("%.1fx", settings.lineHeight),
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }

            // ── Margins ──────────────────────────────────────────────
            SettingsSection("Page Margins") {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text("Narrow")
                    Slider(
                        value = settings.margins.toFloat(),
                        onValueChange = { onSettingsChanged(settings.copy(margins = it.toInt())) },
                        valueRange = 0f..48f,
                        modifier = Modifier.weight(1f).padding(horizontal = 8.dp),
                    )
                    Text("Wide")
                }
                Text(
                    "${settings.margins} dp",
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

            // ── Translation Provider ─────────────────────────────────
            SettingsSection("Translation Provider") {
                Column {
                    TranslationProvider.entries.forEach { provider ->
                        Row(
                            Modifier
                                .fillMaxWidth()
                                .clickable {
                                    onSettingsChanged(settings.copy(translationProvider = provider))
                                }
                                .padding(vertical = 8.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            RadioButton(
                                selected = settings.translationProvider == provider,
                                onClick = {
                                    onSettingsChanged(settings.copy(translationProvider = provider))
                                },
                            )
                            Spacer(Modifier.width(8.dp))
                            Column(Modifier.weight(1f)) {
                                Text(
                                    provider.displayName,
                                    style = MaterialTheme.typography.bodyLarge,
                                )
                                Text(
                                    "${provider.costPerBook}/book • ${if (provider.requiresNetwork) "Online" else "Offline"}",
                                    style = MaterialTheme.typography.bodySmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                )
                            }
                        }
                    }
                }
            }

            // ── Target Language ──────────────────────────────────────
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

            Spacer(Modifier.height(32.dp))
        }
    }
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
