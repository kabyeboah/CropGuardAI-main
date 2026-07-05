# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.embedding.** { *; }

# Dart VM entry points used by WorkManager background isolate
-keep @interface androidx.annotation.Keep
-keep @androidx.annotation.Keep class * { *; }

# WorkManager — BackgroundWorker is instantiated via reflection by WorkManager
-keep class dev.fluttercommunity.workmanager.** { *; }
-keepnames class dev.fluttercommunity.workmanager.** { *; }
-keepclassmembers class dev.fluttercommunity.workmanager.** { *; }

# WorkManager uses Room internally. R8 strips WorkDatabase_Impl's no-arg constructor
# which is called via reflection during WorkManagerInitializer (ContentProvider startup).
# This is the root cause of the "NoSuchMethodException: WorkDatabase_Impl.<init> []" crash.
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
-keep class * extends androidx.room.RoomDatabase { *; }
-keepclassmembers class * extends androidx.room.RoomDatabase {
    <init>();
}
-keep class androidx.work.** { *; }
-keep class * extends androidx.work.Worker { *; }
-keep class * extends androidx.work.InputMerger { *; }
-keep public class * extends androidx.work.ListenableWorker {
    public <init>(android.content.Context,androidx.work.WorkerParameters);
}
-keep class androidx.work.WorkerParameters { *; }

# TensorFlow Lite
-keep class org.tensorflow.** { *; }
-keep class org.tensorflow.lite.** { *; }
-dontwarn org.tensorflow.**

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Firebase Crashlytics
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception

# Firebase App Check / Play Integrity
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# Google Maps
-keep class com.google.android.gms.maps.** { *; }

# Kotlin coroutines
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}
-keepclassmembernames class kotlinx.** {
    volatile <fields>;
}

# Kotlin
-keep class kotlin.** { *; }
-keep class kotlin.Metadata { *; }
-keepattributes *Annotation*, Signature, InnerClasses, EnclosingMethod
-keepattributes RuntimeVisibleAnnotations, RuntimeVisibleParameterAnnotations

# Speech recognition — system API, not subject to R8 but kept for safety
-keep class android.speech.** { *; }

# Jailbreak detection (rootbeer)
-dontwarn appmire.be.**
-keep class appmire.be.** { *; }

# Cloudinary
-dontwarn com.cloudinary.**
-keep class com.cloudinary.** { *; }
