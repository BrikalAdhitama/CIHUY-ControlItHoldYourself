plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    // Flutter plugin app (INI yang bener di sini)
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.cihuy.app"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.cihuy.app"
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = 1
        versionName = "1.0"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "11"
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
