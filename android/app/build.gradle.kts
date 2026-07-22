import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use(keystoreProperties::load)
}
val hasReleaseSigning = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
    .all { !keystoreProperties.getProperty(it).isNullOrBlank() }
val hasGoogleServices = file("google-services.json").exists() ||
    file("src/release/google-services.json").exists() ||
    file("src/debug/google-services.json").exists()

if (hasGoogleServices) {
    apply(plugin = "com.google.gms.google-services")
} else {
    logger.warn(
        "google-services.json not found. Firebase Android resources will not be generated " +
            "until the file is added under android/app/."
    )
}

android {
    namespace = "cat.eespunes.thrive"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications requires core library desugaring.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "cat.eespunes.thrive"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (hasReleaseSigning) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = rootProject.file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
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
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

tasks.register("verifyProductionConfig") {
    doLast {
        if (!hasGoogleServices) {
            throw GradleException(
                "Missing google-services.json. Download it from Firebase console and place it in android/app/."
            )
        }
        if (!hasReleaseSigning) {
            throw GradleException(
                "Missing release signing config. Create android/key.properties (see android/key.properties.example)."
            )
        }
    }
}

tasks.matching { it.name in setOf("assembleRelease", "bundleRelease") }.configureEach {
    dependsOn("verifyProductionConfig")
}
