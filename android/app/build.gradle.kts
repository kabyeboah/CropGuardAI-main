import java.util.Properties
import org.gradle.api.GradleException

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
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
    namespace = "com.cropguard.ai.app"
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
        applicationId = "com.cropguard.ai.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        ndk {
            abiFilters += listOf("armeabi-v7a", "arm64-v8a", "x86_64")
        }
    }

    packagingOptions {
        jniLibs {
            pickFirsts += setOf(
                "**/libtensorflowlite.so",
                "**/libtensorflowlite_jni.so",
            )
        }
    }

    buildTypes {
        debug {
            // Use the default Android debug keystore for debug builds.
            // Do NOT apply the release signing config here — mixing signing certs
            // causes "App not installed as package conflicts with an existing package"
            // when the device already has a version of the app with a different cert.
            signingConfig = signingConfigs.getByName("debug")
        }
        release {
            val hasKeystore = keystorePropertiesFile.exists() || System.getenv("STORE_FILE") != null
            if (!hasKeystore) {
                throw GradleException("Release keystore not found. Provide keystore via key.properties or environment variables.")
            }
            signingConfig = signingConfigs.getByName("release")
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
}

// Crashlytics mapping-file upload requires a network call to
// firebasecrashlyticssymbols.googleapis.com. Disable it for local builds
// so the APK can be produced offline. Re-enable for CI/CD release pipelines.
tasks.configureEach {
    if (name.startsWith("uploadCrashlytics") && name.contains("Release")) {
        enabled = false
    }
}
