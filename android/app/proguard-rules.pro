# R8/ProGuard keep rules for the FitForge release build.
# Most plugins ship their own consumer rules; these are defensive additions.

# --- Flutter ---
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugin.** { *; }
-dontwarn io.flutter.**

# --- Firebase / Google Play Services ---
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# --- Firebase Crashlytics: keep line numbers / source info for readable stacks ---
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception

# --- flutter_local_notifications (uses Gson + reflection) ---
-keep class com.dexterous.** { *; }
-keep class com.google.gson.** { *; }
-keepattributes Signature
-keepattributes *Annotation*

# --- Keep annotations used by various plugins ---
-keepattributes RuntimeVisibleAnnotations,RuntimeVisibleParameterAnnotations
