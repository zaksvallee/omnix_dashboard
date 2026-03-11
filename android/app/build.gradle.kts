plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

fun String.escapeForBuildConfig(): String = replace("\\", "\\\\").replace("\"", "\\\"")
fun optionalTrimmedProperty(name: String): String? =
    (project.findProperty(name) as String?)
        ?.trim()
        ?.takeIf { it.isNotEmpty() }

fun optionalExistingFileProperty(name: String): File? {
    val raw = optionalTrimmedProperty(name) ?: return null
    val candidate = project.file(raw)
    if (!candidate.exists()) {
        logger.warn("ONYX: property $name points to missing file: $candidate")
        return null
    }
    logger.lifecycle("ONYX: enabling vendor SDK artifact from $name -> $candidate")
    return candidate
}

val useLiveFskSdk = (project.findProperty("ONYX_USE_LIVE_FSK_SDK") as String?)
    ?.trim()
    ?.lowercase() == "true"
val fskSdkHeartbeatAction = (project.findProperty("ONYX_FSK_SDK_HEARTBEAT_ACTION") as String?)
    ?.trim()
    ?.takeIf { it.isNotEmpty() }
    ?: "com.onyx.fsk.SDK_HEARTBEAT"
val fskSdkPayloadAdapter = (project.findProperty("ONYX_FSK_SDK_PAYLOAD_ADAPTER") as String?)
    ?.trim()
    ?.lowercase()
    ?.takeIf { it == "standard" || it == "legacy_ptt" || it == "hikvision_guardlink" }
    ?: "standard"
val fskSdkConnectorClass = (project.findProperty("ONYX_FSK_SDK_CONNECTOR_CLASS") as String?)
    ?.trim()
    ?: ""
val fskSdkArtifact = optionalExistingFileProperty("ONYX_FSK_SDK_ARTIFACT")
val fskSdkMavenCoordinate = optionalTrimmedProperty("ONYX_FSK_SDK_MAVEN_COORD")
val useLiveHikvisionSdk = (project.findProperty("ONYX_USE_LIVE_HIKVISION_SDK") as String?)
    ?.trim()
    ?.lowercase() == "true"
val hikvisionSdkHeartbeatAction =
    (project.findProperty("ONYX_HIKVISION_SDK_HEARTBEAT_ACTION") as String?)
        ?.trim()
        ?.takeIf { it.isNotEmpty() }
        ?: "com.onyx.hikvision.SDK_HEARTBEAT"
val hikvisionSdkPayloadAdapter =
    (project.findProperty("ONYX_HIKVISION_SDK_PAYLOAD_ADAPTER") as String?)
        ?.trim()
        ?.lowercase()
        ?.takeIf { it == "standard" || it == "legacy_ptt" || it == "hikvision_guardlink" }
        ?: "hikvision_guardlink"
val hikvisionSdkConnectorClass =
    (project.findProperty("ONYX_HIKVISION_SDK_CONNECTOR_CLASS") as String?)
        ?.trim()
        ?: ""
val hikvisionSdkArtifact = optionalExistingFileProperty("ONYX_HIKVISION_SDK_ARTIFACT")
val hikvisionSdkMavenCoordinate = optionalTrimmedProperty("ONYX_HIKVISION_SDK_MAVEN_COORD")

android {
    namespace = "com.example.omnix_dashboard"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    buildFeatures {
        buildConfig = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.omnix_dashboard"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        buildConfigField("boolean", "USE_LIVE_FSK_SDK", useLiveFskSdk.toString())
        buildConfigField(
            "String",
            "FSK_SDK_HEARTBEAT_ACTION",
            "\"${fskSdkHeartbeatAction.escapeForBuildConfig()}\"",
        )
        buildConfigField(
            "String",
            "FSK_SDK_PAYLOAD_ADAPTER",
            "\"${fskSdkPayloadAdapter.escapeForBuildConfig()}\"",
        )
        buildConfigField(
            "String",
            "FSK_SDK_CONNECTOR_CLASS",
            "\"${fskSdkConnectorClass.escapeForBuildConfig()}\"",
        )
        buildConfigField(
            "boolean",
            "USE_LIVE_HIKVISION_SDK",
            useLiveHikvisionSdk.toString(),
        )
        buildConfigField(
            "String",
            "HIKVISION_SDK_HEARTBEAT_ACTION",
            "\"${hikvisionSdkHeartbeatAction.escapeForBuildConfig()}\"",
        )
        buildConfigField(
            "String",
            "HIKVISION_SDK_PAYLOAD_ADAPTER",
            "\"${hikvisionSdkPayloadAdapter.escapeForBuildConfig()}\"",
        )
        buildConfigField(
            "String",
            "HIKVISION_SDK_CONNECTOR_CLASS",
            "\"${hikvisionSdkConnectorClass.escapeForBuildConfig()}\"",
        )
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Optional local drop-in SDK artifacts (android/app/libs/*.aar|*.jar).
    implementation(fileTree(mapOf("dir" to "libs", "include" to listOf("*.jar", "*.aar"))))

    fskSdkArtifact?.let { implementation(files(it)) }
    hikvisionSdkArtifact?.let { implementation(files(it)) }

    fskSdkMavenCoordinate?.let {
        logger.lifecycle("ONYX: enabling vendor SDK dependency ONYX_FSK_SDK_MAVEN_COORD -> $it")
        implementation(it)
    }
    hikvisionSdkMavenCoordinate?.let {
        logger.lifecycle("ONYX: enabling vendor SDK dependency ONYX_HIKVISION_SDK_MAVEN_COORD -> $it")
        implementation(it)
    }
}
