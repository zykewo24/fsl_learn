import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.signcorrect.fsl_learn"
    compileSdk = 36

    ndkVersion = flutter.ndkVersion

    defaultConfig {
        applicationId = "com.signcorrect.fsl_learn"

        minSdk = 26
        targetSdk = 36

        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlin {
        jvmToolchain(17)
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = keystoreProperties["storeFile"]?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    buildTypes {
        release {
            // R8 (run by the Flutter Gradle plugin for release builds) obfuscates
            // the MediaPipe Task SDK classes that the hand-landmarker `.task`
            // graph resolves by name at runtime, silently breaking live-stream
            // detection results. Keep all classes untouched for release builds.
            isMinifyEnabled = false
            isShrinkResources = false

            // Falls back to the debug keystore on machines without key.properties
            // (fresh clones, CI), so local builds keep working out of the box.
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {

    // CameraX
    implementation("androidx.camera:camera-camera2:1.4.2")
    implementation("androidx.camera:camera-lifecycle:1.4.2")
    implementation("androidx.camera:camera-view:1.4.2")

    // Lifecycle
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.9.1")

    // MediaPipe Tasks Vision
    implementation("com.google.mediapipe:tasks-vision:0.10.35")
}