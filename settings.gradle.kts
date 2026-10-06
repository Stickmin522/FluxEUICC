pluginManagement {
    repositories {
        gradlePluginPortal()
        google()
        mavenCentral()
    }
}
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.PREFER_SETTINGS)
    repositories {
        google()
        mavenCentral()
        maven("https://storage.googleapis.com/download.flutter.io")
    }
}

buildscript {
    repositories {
        maven("https://raw.githubusercontent.com/lineage-next/gradle-generatebp/4356136ecccc68cf6796a5dcd2388c66b80e0c11/.m2")
    }

    dependencies {
        classpath("org.lineageos:gradle-generatebp:1.4")
    }
}

rootProject.name = "OpenEUICC"
include(":libs:lpac-jni")
include(":app-common")
include(":app-unpriv")
include(":app-deps")

apply(from = File(settingsDir, "flutter_ui/.android/include_flutter.groovy"))
