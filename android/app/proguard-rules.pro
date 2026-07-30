-keep class io.flutter.** { *; }
-keep class com.miasacco.appname.** { *; }

# Flutter Play Store split (not used in direct APK/AAB builds)
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
