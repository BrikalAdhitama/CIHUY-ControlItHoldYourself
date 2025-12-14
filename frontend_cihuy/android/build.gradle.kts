// android/build.gradle.kts (root)

import org.gradle.api.tasks.Delete
import org.gradle.api.file.Directory

buildscript {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
    dependencies {
        // Android Gradle Plugin (cocok dengan Gradle 8.6)
        classpath("com.android.tools.build:gradle:8.2.2")

        // Kotlin harus SAMA dengan settings.gradle.kts
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:1.9.24")

        // Google services plugin untuk FCM
        classpath("com.google.gms:google-services:4.4.0")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// OPTIONAL build output relocation
val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)

    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}