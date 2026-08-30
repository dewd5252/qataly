# Flutter / Dart ProGuard rules
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.**

# Supabase & HTTP
-keep class io.github.jan.supabase.** { *; }
-dontwarn io.github.jan.supabase.**
-keep class okhttp3.** { *; }
-dontwarn okhttp3.**

# Google Fonts
-keep class com.google.fonts.** { *; }
-dontwarn com.google.fonts.**

# Kotlin serialization
-keepattributes *Annotation*, InnerClasses
-dontnote kotlinx.serialization.AnnotationsKt

# Keep app model classes
-keep class com.qataly.qataly.** { *; }
