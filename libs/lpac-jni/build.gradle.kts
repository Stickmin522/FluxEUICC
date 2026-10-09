import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
}

val emulatorBuild = providers.gradleProperty("fluxEmulator").orNull == "true"

android {
    namespace = "net.typeblog.lpac_jni"
    compileSdk = 37
    ndkVersion = "26.1.10909125"

    defaultConfig {
        minSdk = 27
        ndk {
            abiFilters += "arm64-v8a"
        }

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"

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

androidComponents {
    onVariants { variant ->
        variant.androidTest?.sources?.java?.addStaticSourceDirectory("src/test/java")
        val rust = tasks.register<BuildRustJni>("build${variant.name.replaceFirstChar { it.uppercase() }}RustJni") {
            cargoExecutable.set(providers.gradleProperty("cargoExecutable").orElse("cargo"))
            targets.set(if (variant.buildType == "debug" && emulatorBuild) listOf("arm64-v8a", "x86_64") else listOf("arm64-v8a"))
            crateDirectory.set(layout.projectDirectory.dir("rust"))
            ndkDirectory.set(sdkComponents.ndkDirectory)
            cargoBuildDirectory.set(layout.buildDirectory.dir("rust/${variant.name}"))
            outputDirectory.set(layout.buildDirectory.dir("generated/jniLibs/${variant.name}"))
            sources.from(fileTree("rust") { exclude("target/**") }, fileTree("src/main/jni") { include("**/*.c", "**/*.h") })
        }
        variant.sources.jniLibs?.addGeneratedSourceDirectory(rust, BuildRustJni::outputDirectory)
    }
}

kotlin {
    compilerOptions {
        jvmTarget = JvmTarget.JVM_11
    }
}

dependencies {
    implementation("androidx.core:core-ktx:1.19.0")
    implementation(platform("org.jetbrains.kotlin:kotlin-bom:1.8.22"))
    implementation("androidx.appcompat:appcompat:1.7.1")
    testImplementation("junit:junit:4.13.2")
    androidTestImplementation("androidx.test.ext:junit:1.1.5")
    androidTestImplementation("androidx.test.espresso:espresso-core:3.5.1")
}

tasks.withType<Test>().configureEach {
    providers.gradleProperty("hostNativeLibraryDirectory").orNull?.let {
        systemProperty("java.library.path", it)
        systemProperty("lpac.native.tests", "true")
        jvmArgs("-Xcheck:jni")
    }
}
