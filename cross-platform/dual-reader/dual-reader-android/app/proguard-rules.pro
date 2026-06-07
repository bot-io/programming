# Domain layer — keep all (used by Room, Hilt)
-keep class com.dualreader.app.domain.** { *; }

# Data models used by Moshi (Retrofit)
-keep class com.dualreader.app.data.translation.** { *; }

# Room entities
-keep class com.dualreader.app.data.local.entity.** { *; }

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
