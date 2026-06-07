# Add project specific ProGuard rules here.
# EPUB parsing and translation logic should not be obfuscated.
-keep class com.dualreader.app.domain.** { *; }
-dontwarn org.jsoup.**
