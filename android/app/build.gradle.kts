plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

import java.util.Properties

val keystorePropertiesFile = rootProject.file("key.properties")
val releaseSigning: Properties? = if (keystorePropertiesFile.exists()) {
    Properties().apply { keystorePropertiesFile.inputStream().use { load(it) } }
} else null

android {
    namespace = "com.codeskate.crm"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Required by flutter_local_notifications.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.codeskate.crm"
        // Firebase + Razorpay need API 23+.
        minSdk = maxOf(23, flutter.minSdkVersion)
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    signingConfigs {
        if (releaseSigning != null) {
            create("release") {
                keyAlias = releaseSigning["keyAlias"] as String
                keyPassword = releaseSigning["keyPassword"] as String
                storeFile = file(releaseSigning["storeFile"] as String)
                storePassword = releaseSigning["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Uses android/key.properties when present (Play Store upload key),
            // otherwise falls back to the debug key so `--release` still installs.
            signingConfig = if (releaseSigning != null) signingConfigs.getByName("release") else signingConfigs.getByName("debug")
            // R8 stays off: pinput's smart_auth references removed Play Services
            // credential classes, which breaks R8 with "Missing class" errors.
            isMinifyEnabled = false
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
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
