plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android plugin.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.rpg_runner"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Only the prod flavor uses this unsuffixed Play identity.
        applicationId = "com.example.rpg_runner"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        for (environment in listOf("staging", "prod")) {
            create(environment) {
                val prefix = "LOTHRINGEN_${environment.uppercase()}_"
                storeFile = System.getenv("${prefix}KEYSTORE")?.let { file(it) }
                storePassword = System.getenv("${prefix}STORE_PASSWORD")
                keyAlias = System.getenv("${prefix}KEY_ALIAS")
                keyPassword = System.getenv("${prefix}KEY_PASSWORD")
            }
        }
    }

    flavorDimensions += "environment"
    productFlavors {
        create("dev") {
            dimension = "environment"
            applicationIdSuffix = ".dev"
            versionNameSuffix = "-dev"
            signingConfig = signingConfigs.getByName("debug")
        }
        create("staging") {
            dimension = "environment"
            applicationId = "com.lothringen.longrun.staging"
            versionNameSuffix = "-staging"
            signingConfig = signingConfigs.getByName("staging")
        }
        create("prod") {
            dimension = "environment"
            signingConfig = signingConfigs.getByName("prod")
        }
    }

    buildTypes {
        debug {
            versionNameSuffix = "-debug"
        }
        release {
            // Flavor-owned signing; no debug-key fallback for beta/player apps.
            signingConfig = null
        }
    }
}

androidComponents {
    beforeVariants(selector().all()) { variant ->
        val environment = variant.productFlavors.firstOrNull { it.first == "environment" }?.second
        // Debug/profile experiments belong to dev. Test candidates use their
        // signed release artifact and the same attestation path as players.
        if (environment != "dev" && variant.buildType != "release") {
            variant.enable = false
        }
    }
}

for (environment in listOf("staging", "prod")) {
    val title = environment.replaceFirstChar { it.uppercase() }
    val verifySigning = tasks.register("verify${title}ReleaseSigning") {
        doLast {
            val prefix = "LOTHRINGEN_${environment.uppercase()}_"
            for (suffix in listOf("KEYSTORE", "STORE_PASSWORD", "KEY_ALIAS", "KEY_PASSWORD")) {
                require(!System.getenv("$prefix$suffix").isNullOrBlank()) {
                    "Missing $prefix$suffix. Load protected $environment upload-signing inputs."
                }
            }
            require(file(System.getenv("${prefix}KEYSTORE")).isFile) {
                "The protected $environment upload keystore does not exist."
            }
        }
    }
    tasks.matching { it.name == "pre${title}ReleaseBuild" }.configureEach {
        dependsOn(verifySigning)
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
    // Required by Play Games Services v2 sign-in.
    implementation("com.google.android.gms:play-services-games-v2:21.0.0")
}
