plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "mg.majichrono.majichrono"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Requis par flutter_local_notifications et drift sur API 26 (EXI-P09).
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "mg.majichrono"
        // Android 8.0 minimum, impose par le §2.1 du cahier des charges :
        // c'est le plancher du parc d'entree de gamme malgache (§4.4).
        minSdk = 26
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Un seul APK par ABI en production pour tenir le budget EXI-P03 (< 25 Mo).
        ndk {
            abiFilters += listOf("armeabi-v7a", "arm64-v8a", "x86_64")
        }
    }

    buildTypes {
        debug {
            applicationIdSuffix = ".debug"
            versionNameSuffix = "-debug"
        }
        release {
            // TODO(lot 6) : cle de signature de production.
            signingConfig = signingConfigs.getByName("debug")
            // EXI-SEC09 : obfuscation et minification actives en production.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }

    packaging {
        resources {
            excludes += setOf("/META-INF/{AL2.0,LGPL2.1}")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // Flutter's deferred-component embedding references the Play Core API.
    implementation("com.google.android.play:core:1.10.3")
}

flutter {
    source = "../.."
}
