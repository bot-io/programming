package com.dualreader.app.ui.theme

import android.os.Build
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import com.dualreader.app.domain.entities.ReaderTheme

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

val OceanColorScheme = darkColorScheme(
    primary = Color(0xFF3D5A80),
    onPrimary = Color.White,
    secondary = Color(0xFF98C1D9),
    background = Color(0xFF0D1B2A),
    onBackground = Color(0xFFE0FBFC),
    surface = Color(0xFF1B2838),
    onSurface = Color(0xFFE0FBFC),
    surfaceVariant = Color(0xFF1B3A4B),
    onSurfaceVariant = Color(0xFF98C1D9),
)

val ForestColorScheme = darkColorScheme(
    primary = Color(0xFF6B8F6B),
    onPrimary = Color.White,
    secondary = Color(0xFF99B88F),
    background = Color(0xFF1B2D1B),
    onBackground = Color(0xFFD4E7C5),
    surface = Color(0xFF243624),
    onSurface = Color(0xFFD4E7C5),
    surfaceVariant = Color(0xFF2D4A2D),
    onSurfaceVariant = Color(0xFF99B88F),
)

val MidnightColorScheme = darkColorScheme(
    primary = Color(0xFF5858B0),
    onPrimary = Color.White,
    secondary = Color(0xFF8080A0),
    background = Color(0xFF0A0A1A),
    onBackground = Color(0xFFD0D0E0),
    surface = Color(0xFF0F0F2A),
    onSurface = Color(0xFFD0D0E0),
    surfaceVariant = Color(0xFF1A1A3A),
    onSurfaceVariant = Color(0xFF8080A0),
)

/** Night (OLED) theme — true black background for maximum contrast on OLED screens. */
val NightColorScheme = darkColorScheme(
    primary = Color(0xFF6C63FF),
    onPrimary = Color.White,
    primaryContainer = Color(0xFF1A1A1A),
    onPrimaryContainer = Color(0xFFE8E6FF),
    secondary = Color(0xFF03DAC6),
    background = Color(0xFF000000),
    onBackground = Color(0xFFE0E0E0),
    surface = Color(0xFF0A0A0A),
    onSurface = Color(0xFFE0E0E0),
    surfaceVariant = Color(0xFF1A1A1A),
    onSurfaceVariant = Color(0xFFB0B0B0),
    error = Color(0xFFCF6679),
    onError = Color.Black,
)

/**
 * Maps a [ReaderTheme] to its matching Material 3 [ColorScheme].
 * Non-dark themes (Light, Sepia) use their own scheme;
 * dark variants map to the appropriate dark scheme.
 */
fun colorSchemeForTheme(theme: ReaderTheme): ColorScheme = when (theme) {
    ReaderTheme.DARK -> DarkColorScheme
    ReaderTheme.LIGHT -> LightColorScheme
    ReaderTheme.SEPIA -> SepiaColorScheme
    ReaderTheme.OCEAN -> OceanColorScheme
    ReaderTheme.FOREST -> ForestColorScheme
    ReaderTheme.MIDNIGHT -> MidnightColorScheme
    ReaderTheme.NIGHT -> NightColorScheme
}

@Composable
fun DualReaderTheme(
    theme: ReaderTheme = ReaderTheme.DARK,
    content: @Composable () -> Unit,
) {
    MaterialTheme(
        colorScheme = colorSchemeForTheme(theme),
        typography = Typography(),
        content = content,
    )
}
