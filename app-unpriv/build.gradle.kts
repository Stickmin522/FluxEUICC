import im.angry.openeuicc.build.*
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

signingKeystoreProperties {
    keyAliasField = "unprivKeyAlias"
    keyPasswordField = "unprivKeyPassword"
}

apply {
    plugin<MySigningPlugin>()
}

val emulatorBuild = providers.gradleProperty("fluxEmulator").orNull == "true"

android {
    namespace = "im.angry.easyeuicc"
    compileSdk = 37
    ndkVersion = "26.1.10909125"

    defaultConfig {
        applicationId = "dev.codex.esimmanager17"
        versionCode = 1790685450
        versionName = "1.1.2"
        minSdk = 28
        targetSdk = 37
        ndk {
            abiFilters += "arm64-v8a"
        }
    }

    buildFeatures {
        buildConfig = true
    }

    buildTypes {
        debug {
            if (emulatorBuild) {
                ndk {
                    abiFilters += "x86_64"
                }
            }
        }
        release {
            isMinifyEnabled = false
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = JvmTarget.JVM_11
    }
}

dependencies {
    implementation(project(":app-common"))
    testImplementation("junit:junit:4.13.2")
}
