plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
    // Uploads the mapping files that turn crash stack traces back into
    // readable Dart/Kotlin frames on the Crashlytics dashboard.
    id("com.google.firebase.crashlytics")
}

android {
    namespace = "com.serviciosdomicilio.mvp"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.serviciosdomicilio.mvp"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Two backends, one codebase:
    //   prod → servicios-domicilio-mvp, the project real users and the
    //          user test run on. Build: flutter build apk --flavor prod
    //   dev  → servitec-dev, where unreleased flows are tested without
    //          touching prod. Build: flutter build apk --flavor dev
    // Each flavor reads its own src/<flavor>/google-services.json, and the
    // Dart side picks matching FirebaseOptions from `appFlavor` (see
    // firebase_options.dart). The dev app has its own package name so both
    // can be installed on one phone.
    flavorDimensions += "env"
    productFlavors {
        create("prod") {
            dimension = "env"
            resValue("string", "app_name", "servitec_app")
        }
        create("dev") {
            dimension = "env"
            applicationIdSuffix = ".dev"
            versionNameSuffix = "-dev"
            resValue("string", "app_name", "ServiTec DEV")
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
