#!/usr/bin/env bash
#
# setup_android.sh
# Configures the Android project (Kotlin DSL) for Firebase after `flutter create`.
#
# Usage (from the project root):
#   flutter create --platforms=android .
#   flutter pub get
#   bash scripts/setup_android.sh
#   # then place google-services.json into android/app/
#   flutter run
#
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ANDROID_DIR="$ROOT_DIR/android"
APP_ID="com.codeskate.crm"

if [ ! -d "$ANDROID_DIR" ]; then
  echo "ERROR: android/ folder not found. Run 'flutter create --platforms=android .' first."
  exit 1
fi

echo "==> Removing any legacy Groovy Gradle files (to avoid conflicts)..."
rm -f "$ANDROID_DIR/build.gradle" "$ANDROID_DIR/settings.gradle" "$ANDROID_DIR/app/build.gradle"

echo "==> Writing android/settings.gradle.kts ..."
cat > "$ANDROID_DIR/settings.gradle.kts" << 'EOF'
pluginManagement {
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        file("local.properties").inputStream().use { properties.load(it) }
        val flutterSdkPath = properties.getProperty("flutter.sdk")
        require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
        flutterSdkPath
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.10.0" apply false
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
    id("com.google.gms.google-services") version "4.4.2" apply false
}

include(":app")
EOF

echo "==> Writing android/app/build.gradle.kts ..."
cat > "$ANDROID_DIR/app/build.gradle.kts" << 'EOF'
plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.codeskate.crm"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.codeskate.crm"
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation(platform("com.google.firebase:firebase-bom:32.7.0"))
    implementation("com.google.firebase:firebase-analytics")
}
EOF

echo "==> Writing android/gradle.properties ..."
cat > "$ANDROID_DIR/gradle.properties" << 'EOF'
org.gradle.jvmargs=-Xmx4G
android.useAndroidX=true
android.enableJetifier=false
EOF

echo "==> Fixing MainActivity package to $APP_ID ..."
KOTLIN_BASE="$ANDROID_DIR/app/src/main/kotlin"
mkdir -p "$KOTLIN_BASE/com/codeskate/crm"
cat > "$KOTLIN_BASE/com/codeskate/crm/MainActivity.kt" << 'EOF'
package com.codeskate.crm

import io.flutter.embedding.android.FlutterActivity

class MainActivity: FlutterActivity()
EOF
# Remove any other MainActivity.kt generated under a different package path
find "$KOTLIN_BASE" -name "MainActivity.kt" ! -path "*com/codeskate/crm/*" -delete 2>/dev/null || true
# Clean up now-empty default package dirs (e.g. com/example/...)
find "$KOTLIN_BASE" -type d -empty -delete 2>/dev/null || true

echo ""
echo "=========================================================="
echo " Android Firebase setup complete."
echo " NEXT STEPS:"
echo "   1. Put google-services.json into: android/app/google-services.json"
echo "   2. From project root, run: flutter run"
echo "=========================================================="
