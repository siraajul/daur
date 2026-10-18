import java.util.Base64
import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Family builds keep the installed testers' key. Production is an explicit opt-in:
// DAUR_PRODUCTION_RELEASE=true flutter build appbundle --release
// Credentials come from android/key.properties or DAUR_SIGNING_* environment variables.
val productionRelease = providers.gradleProperty("daurProductionRelease")
    .orElse(providers.environmentVariable("DAUR_PRODUCTION_RELEASE"))
    .map { it.toBooleanStrict() }.getOrElse(false)
// One build flag drives both Dart Firebase options and the Android identity.
val dartValues = providers.gradleProperty("dart-defines").getOrElse("")
    .split(',').filter { it.isNotBlank() }
    .map { String(Base64.getDecoder().decode(it)) }
val previewRelease = dartValues.contains("DAUR_PREVIEW=true")
require(!(productionRelease && previewRelease)) { "Preview is an internal Family build, not a production bundle" }

val releaseKeys = Properties().apply {
    val keyFile = rootProject.file("key.properties")
    if (keyFile.exists()) keyFile.inputStream().use { load(it) }
}
fun signingValue(name: String, env: String): String =
    System.getenv(env)?.takeIf { it.isNotBlank() }
        ?: releaseKeys.getProperty(name)?.takeIf { it.isNotBlank() }
        ?: error("Production signing requires $name in android/key.properties or $env")

if (productionRelease) {
    // Do not accidentally ship App Check's debug provider in a production artifact.
    val dartDefines = providers.gradleProperty("dart-defines").getOrElse("")
    require(dartDefines.split(',').filter { it.isNotBlank() }.none {
        String(Base64.getDecoder().decode(it)).startsWith("APPCHECK_DEBUG_TOKEN=")
    }) { "Production builds must omit APPCHECK_DEBUG_TOKEN; use production App Check attestation." }
}

android {
    namespace = "com.siraj.daur"
    compileSdk = 37 // permission_handler_android needs 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true // flutter_local_notifications
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = if (previewRelease) "com.siraj.daur.preview" else "com.siraj.daur"
        manifestPlaceholders["daurAppLabel"] = if (previewRelease) "Daur Preview" else "Daur"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 26 // Health Connect needs Android 8+
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        // Name this explicitly: AGP's implicit debug signing can use a different
        // preferences directory on CI and silently generate a fresh certificate.
        create("family") {
            storeFile = file(System.getenv("DAUR_FAMILY_KEYSTORE")
                ?: "${System.getProperty("user.home")}/.android/debug.keystore")
            storePassword = "android"
            keyAlias = "androiddebugkey"
            keyPassword = "android"
        }
        if (productionRelease) {
            create("production") {
                storeFile = rootProject.file(signingValue("storeFile", "DAUR_SIGNING_STORE_FILE"))
                require(storeFile!!.isFile) { "Production signing keystore does not exist" }
                storePassword = signingValue("storePassword", "DAUR_SIGNING_STORE_PASSWORD")
                keyAlias = signingValue("keyAlias", "DAUR_SIGNING_KEY_ALIAS")
                keyPassword = signingValue("keyPassword", "DAUR_SIGNING_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName(if (productionRelease) "production" else "family")
            // Keep all resources: notification icons are named only from Dart, which the shrinker
            // can't see, so it stripped ic_stat_daur and every reminder failed in release builds.
            isShrinkResources = false
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
