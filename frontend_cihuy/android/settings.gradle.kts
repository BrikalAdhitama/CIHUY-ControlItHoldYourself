// android/settings.gradle.kts
pluginManagement {
    val flutterSdkPath =
        run {
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

    // Jika plugin di-apply via plugins { id("...") }, gunakan resolutionStrategy
    // untuk mengarahkan id plugin ke module/classpath yang benar.
    resolutionStrategy {
        eachPlugin {
            when (requested.id.id) {
                "com.google.gms.google-services" -> {
                    useModule("com.google.gms:google-services:4.4.0")
                }
                // kalau butuh plugin lain yg tidak tersedia di pluginPortal, tambahkan di sini
                // "com.google.firebase.crashlytics" -> useModule("com.google.firebase:firebase-crashlytics-gradle:2.9.6")
            }
        }
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.11.1" apply false
    id("org.jetbrains.kotlin.android") version "1.9.24" apply false
    // jangan tambahkan com.google.gms di sini (kita resolve melalui resolutionStrategy)
}

include(":app")
