package com.dualreader.app.ui.theme

import android.os.Build
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext

// Dark theme colors (default for a reader app)
val DarkColorScheme = darkColorScheme(
    primary = Color(0xFF6C63FF),
    onPrimary = Color.White,
    primaryContainer = Color(0xFF2D2B55),
    onPrimaryContainer = Color(0xFFE8E6FF),
    secondary = Color(0xFF03DAC6),
    background = Color(0xFF1A1A2E),
    onBackground = Color(0xFFE0E0E0),
    surface = Color(0xFF16213E),
    onSurface = Color(0xFFE0E0E0),
    surfaceVariant = Color(0xFF0F3460),
    onSurfaceVariant = Color(0xFFB0B0B0),
)

val LightColorScheme = lightColorScheme(
    primary = Color(0xFF5C56E0),
    onPrimary = Color.White,
    secondary = Color(0xFF018786),
    background = Color(0xFFFFFBFE),
    surface = Color(0xFFFFFBFE),
)

val SepiaColorScheme = darkColorScheme(
    primary = Color(0xFFD4A574),
    onPrimary = Color(0xFF2C1810),
    background = Color(0xFFF4E8D1),
    onBackground = Color(0xFF3E2723),
    surface = Color(0xFFF0E0C8),
    onSurface = Color(0xFF3E2723),
)

@Composable
fun DualReaderTheme(
    content: @Composable () -> Unit,
) {
    // Default to dark theme for reader app
    MaterialTheme(
        colorScheme = DarkColorScheme,
        typography = Typography(),
        content = content,
    )
}
