plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

import java.util.Properties
import java.io.FileInputStream

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "me.orbitium.akademiz"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

compileOptions {
        // --- CHANGE 1: Enable Desugaring ---
        isCoreLibraryDesugaringEnabled = true  // <--- ADD THIS LINE
        
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "me.orbitium.akademiz"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            val alias = keystoreProperties.getProperty("keyAlias")?.trim()
            val keyPass = keystoreProperties.getProperty("keyPassword")?.trim()
            val storePass = keystoreProperties.getProperty("storePassword")?.trim()
            val storeFilePath = keystoreProperties.getProperty("storeFile")?.trim()

            if (alias != null && keyPass != null && storePass != null && storeFilePath != null) {
                keyAlias = alias
                keyPassword = keyPass
                storeFile = file(storeFilePath)
                storePassword = storePass
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}

// --- CHANGE 2: Add Dependencies Block ---
dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}