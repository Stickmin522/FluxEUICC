# Building FluxEUICC

## Requirements

- Flutter 3.47.6 stable
- JDK 17 or newer
- Android SDK platform 37 and NDK 26.1.10909125
- Rust 1.99 or newer, Cargo, and libclang (for bindgen)

Install the Android Rust targets and prepare the Flutter module:

```sh
rustup target add aarch64-linux-android x86_64-linux-android
cd flutter_ui
flutter pub get
cd ..
```

Set `sdk.dir` in the root `local.properties` to your Android SDK location. Flutter generates its own Android integration files when running `flutter pub get`; do not edit or commit `flutter_ui/.android`.

Set `LIBCLANG_PATH` to the directory containing `libclang.so`, `libclang.dylib`, or `libclang.dll` if it is not found automatically. Cargo must be on `PATH`, or pass `-PcargoExecutable=/path/to/cargo` to Gradle. The Gradle task uses the configured NDK to build libeuicc and the Rust JNI adapter together.

## Build

```sh
./gradlew :app-unpriv:assembleRelease
```

On Windows, use `gradlew.bat`. The APK is written to `app-unpriv/build/outputs/apk/release/` and includes only `arm64-v8a` native libraries.

For an x86_64 emulator, use a debug build:

```sh
./gradlew :app-unpriv:assembleDebug -PfluxEmulator=true
```

The emulator flag only affects debug builds.

Signing uses the existing Gradle signing configuration. Keep signing keys and `keystore.properties` outside source control. A SIM-slot card must authorize the signing certificate in ARA-M before the app can manage it.

## Checks

```sh
cd flutter_ui
flutter analyze
flutter test
cd ..
./gradlew :app-common:testDebugUnitTest :libs:lpac-jni:testDebugUnitTest
cd libs/lpac-jni/rust
cargo test --locked
```

The JNI integration tests can run on a desktop JVM against a host build of the adapter. Build with `cargo build --locked`, copy the resulting library to the platform name `liblpac-jni.so`, `liblpac-jni.dylib`, or `lpac-jni.dll`, then run:

```sh
./gradlew :libs:lpac-jni:testDebugUnitTest -PhostNativeLibraryDirectory=/path/to/library
```

On Windows, the host C build needs clang-cl and Visual Studio C tools; set `CC` to clang-cl. These tests use simulated APDU and HTTP transports with the actual libeuicc implementation. Card authorization, modem refresh, and successful profile downloads still require an Android device and a compatible card.

Interface text is stored in `flutter_ui/assets/i18n/`. To regenerate it from the Android string resources, run `python tools/export_localizations.py`.
