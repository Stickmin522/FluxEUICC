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
        versionCode = 2000000000
        versionName = "2.0"
        minSdk = 28
        targetSdk = 37
        ndk {
            abiFilters += "arm64-v8a"
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
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
        jvmTarget = JvmTarget.JVM_17
    }
}

dependencies {
    implementation(project(":app-common"))
    implementation(project(":flutter"))
    testImplementation("junit:junit:4.13.2")
}
