# Domain layer — keep all (used by Room, Hilt)
-keep class com.dualreader.app.domain.** { *; }

# Data models used by Moshi (Retrofit)
-keep class com.dualreader.app.data.translation.** { *; }

# Room — entities, DAOs, database, converters
-keep class com.dualreader.app.data.local.entity.** { *; }
-keep class com.dualreader.app.data.local.dao.** { *; }
-keep class com.dualreader.app.data.local.AppDatabase { *; }
-keep class com.dualreader.app.data.local.Converters { *; }

# ViewModels (Hilt creates these)
-keep class com.dualreader.app.ui.screens.** { *; }

# Repositories (Hilt)
-keep class com.dualreader.app.data.repository.** { *; }

# Use cases
-keep class com.dualreader.app.domain.usecases.** { *; }

# Data mappers (use Converters)
-keep class com.dualreader.app.data.local.mapper.** { *; }

# epub4j — keep parsing classes
-keep class nl.siegmann.epublib.** { *; }
-dontwarn org.jsoup.**
-dontwarn nl.siegmann.epublib.**

# Kotlin coroutines
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}

# Hilt
-dontwarn dagger.hilt.**

# ML Kit — uses reflection heavily, must keep internal classes
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.** { *; }
-dontwarn com.google.mlkit.**
-dontwarn com.google.android.gms.**

# AndroidX SplashScreen compat — theme installSplashScreen uses reflection
-keep class androidx.core.splashscreen.SplashScreen { *; }
-keep class androidx.core.splashscreen.SplashScreen$Companion { *; }
