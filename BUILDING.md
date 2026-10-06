# Building FluxEUICC

## Requirements

- Flutter 3.47.6 stable
- JDK 17 or newer
- Android SDK platform 37 and NDK 26.1.10909125

Clone with submodules, then prepare the Flutter module:

```sh
git submodule update --init --recursive
cd flutter_ui
flutter pub get
cd ..
```

Set `sdk.dir` in the root `local.properties` to your Android SDK location. Flutter generates its own Android integration files when running `flutter pub get`; do not edit or commit `flutter_ui/.android`.

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
```

Interface text is stored in `flutter_ui/assets/i18n/`. To regenerate it from the Android string resources, run `python tools/export_localizations.py`.
