import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
}

android {
    namespace = "com.miasacco.appname"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    signingConfigs {
        create("release") {
            val props = Properties()
            val propsFile = rootProject.file("local.properties")
            if (propsFile.exists()) props.load(propsFile.inputStream())
            keyAlias    = props.getProperty("KEY_ALIAS",     System.getenv("KEY_ALIAS")    ?: "")
            keyPassword = props.getProperty("KEY_PASSWORD",  System.getenv("KEY_PASSWORD") ?: "")
            storeFile   = file(props.getProperty("STORE_FILE", System.getenv("STORE_FILE") ?: "release.keystore"))
            storePassword = props.getProperty("STORE_PASSWORD", System.getenv("STORE_PASSWORD") ?: "")
        }
    }

    defaultConfig {
        applicationId = "com.miasacco.appname"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("androidx.core:core-splashscreen:1.0.1")

    // Firebase BoM — manages all Firebase SDK versions consistently
    implementation(platform("com.google.firebase:firebase-bom:34.14.0"))
    implementation("com.google.firebase:firebase-analytics")
    implementation("com.google.firebase:firebase-messaging")
    implementation("com.google.firebase:firebase-crashlytics")
}
