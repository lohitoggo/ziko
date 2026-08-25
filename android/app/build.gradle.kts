plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.ziko.ziko"
    compileSdk = 36
    buildToolsVersion = "36.0.0"
    ndkVersion = flutter.ndkVersion

    java {
        toolchain {
            languageVersion.set(JavaLanguageVersion.of(17))
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.ziko.ziko"
        // Gemini requires at least 21
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }

    dependencies {
        implementation("com.onesignal:OneSignal:5.1.1")
        implementation("org.jetbrains.kotlin:kotlin-stdlib")
        implementation("androidx.core:core-ktx:1.13.1")
    }
}

flutter {
    source = "../.."
}
