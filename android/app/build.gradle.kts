import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Gitignored, per-machine. Never committed — see SHIP.md §3/§8 for how to
// generate the keystore this points at.
val keyProperties = Properties()
val keyPropertiesFile = rootProject.file("key.properties")
val hasKeyProperties = keyPropertiesFile.exists()
if (hasKeyProperties) {
    keyPropertiesFile.inputStream().use { keyProperties.load(it) }
}

android {
    namespace = "app.dryrun"
    // flutter_secure_storage 11.0.0's own android/build.gradle compiles
    // against SDK 37 unconditionally; a lower compileSdk here than a
    // dependency's is a hard Gradle failure (AGP requires every module in
    // the build to compile against at least the highest SDK any module
    // needs), not merely a warning, so this can't stay at
    // flutter.compileSdkVersion (36 on this Flutter release).
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications (T141, FR-048a-c) requires this.
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "app.dryrun"
        // minSdk 24 (Android 7.0) is the highest any plugin needs (flutter_local_notifications,
        // flutter_secure_storage, shared_preferences, url_launcher). It was 31 while voice relied
        // on the on-device recognizer, which needs API 31; the app now binds the default
        // recognition service (recognition_service_impl.dart, onDevice: false), so it doesn't.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (hasKeyProperties) {
                storeFile = file(keyProperties.getProperty("storeFile"))
                storePassword = keyProperties.getProperty("storePassword")
                keyAlias = keyProperties.getProperty("keyAlias")
                keyPassword = keyProperties.getProperty("keyPassword")
            }
        }
    }

    // Two installable apps from one codebase. `prod` is the published
    // identity and must never change. `dev` installs beside it. Which
    // relay a build talks to is NOT decided here; that is
    // --dart-define-from-file=config/{dev,prod}.json (lib/core/config/flavor.dart).
    flavorDimensions += "app"
    productFlavors {
        create("dev") {
            dimension = "app"
            applicationIdSuffix = ".dev"
            manifestPlaceholders["deepLinkScheme"] = "dryrun-dev"
            // Every dev build type, release included, is debug-signed, so
            // the upload key can never sign an app.dryrun.dev APK.
            signingConfig = signingConfigs.getByName("debug")
        }
        create("prod") {
            dimension = "app"
            manifestPlaceholders["deepLinkScheme"] = "dryrun"
            // Build-type signingConfig wins over the flavor's, and the
            // debug build type keeps debug signing, so only prodRelease
            // uses this.
            signingConfig = signingConfigs.getByName("release")
        }
    }

    buildTypes {
        release {
            // Release signing is set on the `prod` flavor above, not here: a
            // build-type signingConfig would also sign devRelease with the upload
            // key. The gradle.taskGraph.whenReady guard below fails prodRelease
            // without android/key.properties (FR-023).
        }
    }
}

gradle.taskGraph.whenReady {
    // Match the tasks that build or package prodRelease, not every task whose
    // name contains "ProdRelease": AGP's lifecycle task preProdReleaseBuild is
    // in the graph of every release build, devRelease included.
    val buildsProdRelease = allTasks.any {
        it.name.endsWith("ProdRelease") &&
            (it.name.startsWith("assemble") || it.name.startsWith("bundle") || it.name.startsWith("package"))
    }
    if (!hasKeyProperties && buildsProdRelease) {
        throw GradleException(
            "prod release build requires android/key.properties (storeFile, storePassword, keyAlias, " +
                "keyPassword) — FR-023. Generate a keystore and create that file (SHIP.md §3/§8); " +
                "a release build must never silently fall back to debug signing. " +
                "(dev release builds are debug-signed and need no keystore.)"
        )
    }
}

dependencies {
    // TrustedTimeChannel (research.md R-003) — first-party channel over Play Services TrustedTime.
    implementation("com.google.android.gms:play-services-time:16.0.1")
    // Required by flutter_local_notifications alongside isCoreLibraryDesugaringEnabled above.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}

flutter {
    source = "../.."
}
