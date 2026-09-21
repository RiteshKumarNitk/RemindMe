import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Reads google-services.json for Firebase (see README section 9).
    id("com.google.gms.google-services")
    // Uploads native (Kotlin/Java) crash symbols for Crashlytics; the Dart
    // side is wired in lib/main.dart via the firebase_crashlytics package.
    id("com.google.firebase.crashlytics")
}

// Release signing: create android/key.properties (git-ignored) with
//   storeFile=/absolute/path/to/upload-keystore.jks
//   storePassword=...
//   keyAlias=upload
//   keyPassword=...
// If the file is absent, release falls back to debug signing (for local runs).
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.family.medireminder"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        // Required by flutter_local_notifications (java.time APIs).
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.family.medireminder"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                // Fallback so `flutter run --release` still works without a keystore.
                signingConfigs.getByName("debug")
            }
            // Minification/shrinking is intentionally OFF for now (larger but
            // safer APK/AAB) — see proguard-rules.pro's header comment for
            // why, and what must happen before it's turned on.
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    // Firebase BoM — manages all Firebase SDK versions centrally.
    // Analytics is intentionally omitted: the app collects no analytics, which
    // keeps the Play "Data safety" declaration minimal. Crashlytics DOES
    // collect crash/diagnostic data (device model, OS version, stack traces)
    // — this must be added to the Play "Data safety" form before release
    // (see PLAY_STORE_RELEASE.md).
    implementation(platform("com.google.firebase:firebase-bom:34.18.0"))
    implementation("com.google.firebase:firebase-auth")
    implementation("com.google.firebase:firebase-firestore")
    implementation("com.google.firebase:firebase-messaging")
    implementation("com.google.firebase:firebase-crashlytics")
}

flutter {
    source = "../.."
}
