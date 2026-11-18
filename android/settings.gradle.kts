runCatching {
    val processEnvClass = Class.forName("java.lang.ProcessEnvironment")
    runCatching {
        val envField = processEnvClass.getDeclaredField("theEnvironment")
        envField.isAccessible = true
        (envField.get(null) as? MutableMap<Any, Any>)?.remove("ANDROID_PREFS_ROOT")
    }
    runCatching {
        val ciEnvField = processEnvClass.getDeclaredField("theCaseInsensitiveEnvironment")
        ciEnvField.isAccessible = true
        (ciEnvField.get(null) as? MutableMap<Any, Any>)?.remove("ANDROID_PREFS_ROOT")
    }
}
System.clearProperty("ANDROID_PREFS_ROOT")

pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "9.1.1" apply false
    // START: FlutterFire Configuration
    id("com.google.gms.google-services") version("4.4.4") apply false
    // END: FlutterFire Configuration
    id("org.jetbrains.kotlin.android") version "2.4.10" apply false
}

include(":app")
