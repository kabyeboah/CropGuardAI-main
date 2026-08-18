import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
}

// Load signing credentials from key.properties (local) or environment variables (CI).
// Create android/key.properties with keyAlias, keyPassword, storeFile, storePassword
// before running a release build. The file is gitignored.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { stream -> keystoreProperties.load(stream) }
}

android {
    namespace = "com.crop.guard.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties.getProperty("keyAlias") ?: System.getenv("KEY_ALIAS") ?: ""
            keyPassword = keystoreProperties.getProperty("keyPassword") ?: System.getenv("KEY_PASSWORD") ?: ""
            storeFile = (keystoreProperties.getProperty("storeFile") ?: System.getenv("STORE_FILE"))
                ?.let { file(it) }
            storePassword = keystoreProperties.getProperty("storePassword") ?: System.getenv("STORE_PASSWORD") ?: ""
        }
    }

    defaultConfig {
        applicationId = "com.crop.guard.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        ndk {
            abiFilters += listOf("armeabi-v7a", "arm64-v8a", "x86_64")
        }
    }

    // Ensure TFLite/LiteRT native .so files don't conflict when both
    // tflite_flutter (bundles libtensorflowlite_jni.so via litert) and
    // tensorflow-lite-select-tf-ops are on the classpath.
    packagingOptions {
        jniLibs {
            pickFirsts += setOf(
                "**/libtensorflowlite_flex.so",
                "**/libtensorflowlite.so",
                "**/libtensorflowlite_jni.so",
            )
        }
    }



    buildTypes {
        release {
            val hasKeystore = keystorePropertiesFile.exists() || System.getenv("STORE_FILE") != null
            signingConfig = if (hasKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    // Flex / select-TF-ops delegate — needed for any custom TF ops the model uses.
    // We DO NOT also add org.tensorflow:tensorflow-lite here because tflite_flutter
    // already pulls in com.google.ai.edge.litert:litert (Google's rebrand of
    // tensorflow-lite). Adding both causes a duplicate-class build error.
    // Instead we exclude the redundant tensorflow-lite core from select-tf-ops'
    // own transitive graph so only litert's copy of those classes is on the
    // runtime classpath.
    implementation("org.tensorflow:tensorflow-lite-select-tf-ops:2.16.1") {
        exclude(group = "org.tensorflow", module = "tensorflow-lite")
        exclude(group = "org.tensorflow", module = "tensorflow-lite-api")
    }
}

// Crashlytics mapping-file upload requires a network call to
// firebasecrashlyticssymbols.googleapis.com. Disable it for local builds
// so the APK can be produced offline. Re-enable for CI/CD release pipelines.
tasks.configureEach {
    if (name.startsWith("uploadCrashlytics") && name.contains("Release")) {
        enabled = false
    }
}
