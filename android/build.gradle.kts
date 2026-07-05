allprojects {
    repositories {
        // Local fallback for the Flutter engine artifacts (io.flutter:*_debug).
        // Lets offline builds resolve the ~180 MB engine jar from disk instead of
        // re-downloading it from download.flutter.io. See android/local-engine-repo.
        maven { url = uri("${rootProject.projectDir}/local-engine-repo") }
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// Part A — namespace back-fill + Java target. Applied in an afterEvaluate
// registered here during root configuration so it runs before AGP's own
// afterEvaluate variant creation.
//   1. AGP 8 requires every library module to declare a `namespace`; old
//      plugins (e.g. flutter_jailbreak_detection) still rely on the legacy
//      `package` attribute. We back-fill the namespace from that package.
//   2. Set the Java target to 17 via the android `compileOptions` (not the raw
//      JavaCompile task). AGP then compiles with -source/-target 17 while
//      keeping android.jar on the classpath. Setting it on the task directly
//      instead trips javac into `--release` mode, which drops the Android
//      bootclasspath and makes every android.* import fail to resolve.
subprojects {
    // Skip projects already evaluated (e.g. :app, force-evaluated by the
    // evaluationDependsOn block above) — they configured successfully and
    // already declare a namespace + consistent Java target.
    if (state.executed) return@subprojects
    afterEvaluate {
        val android = extensions.findByName("android") ?: return@afterEvaluate

        // 1. Namespace back-fill.
        val current = android.javaClass.methods
            .firstOrNull { it.name == "getNamespace" && it.parameterCount == 0 }
            ?.invoke(android) as? String
        if (current == null) {
            val manifest = file("src/main/AndroidManifest.xml")
            val pkg = if (manifest.exists()) {
                Regex("package=\"([^\"]+)\"")
                    .find(manifest.readText())?.groupValues?.get(1)
            } else null
            if (pkg != null) {
                android.javaClass.methods
                    .firstOrNull { it.name == "setNamespace" && it.parameterCount == 1 }
                    ?.invoke(android, pkg)
            }
        }

        // 2. Java compileOptions -> 17 (matches the Kotlin target forced below).
        val compileOptions = android.javaClass.methods
            .firstOrNull { it.name == "getCompileOptions" && it.parameterCount == 0 }
            ?.invoke(android)
        if (compileOptions != null) {
            fun setCompat(name: String) = compileOptions.javaClass.methods
                .firstOrNull {
                    it.name == name && it.parameterCount == 1 &&
                        (it.parameterTypes[0] == JavaVersion::class.java ||
                            it.parameterTypes[0] == Any::class.java)
                }
                ?.invoke(compileOptions, JavaVersion.VERSION_17)
            setCompat("setSourceCompatibility")
            setCompat("setTargetCompatibility")
        }
    }
}

// Part B — Kotlin target alignment. AGP 8 requires a module's Java and Kotlin
// compile tasks to target the same JVM. Java is pinned to 17 above; some
// plugins pin Kotlin to 1.8, overriding a config-time `configureEach`.
// Registering in `projectsEvaluated` (after every plugin has configured) makes
// this the LAST writer, so the Kotlin target is decisively 17 everywhere.
gradle.projectsEvaluated {
    subprojects {
        tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinJvmCompile>()
            .configureEach {
                compilerOptions {
                    jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
                }
            }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
