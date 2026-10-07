# FluxEUICC

**English** | [简体中文](README.zh-CN.md) | [繁體中文](README.zh-TW.md) | [日本語](README.ja.md) | [한국어](README.ko.md) | [العربية](README.ar.md) | [Français](README.fr.md) | [Deutsch](README.de.md) | [Español](README.es.md)

**Add, switch, and manage your eSIM profiles with ease.**

FluxEUICC is an Android app for managing removable eSIM cards, based on [OpenEUICC](https://gitea.angry.im/PeterCxy/OpenEUICC). It brings your profiles together in a clear interface for everyday downloads, switching, and management, without requiring root.

<p align="center">
  <img src="art/FluxEUICC-logo.png" alt="FluxEUICC" width="240" height="240">
</p>

> **Before you start**
>
> FluxEUICC only manages removable eSIM cards compatible with OpenEUICC. Installing this app alone does not add eSIM capability to a phone that lacks it. Before using the app, purchase a compatible removable eSIM card, such as eSTK or 9eSIM.

## Why choose FluxEUICC

- **A modern, clear interface**: profile cards, visible activation status, and simple menus keep common actions easy to find. Soft gradients, light and dark themes, and adaptive icons help the app fit your device.
- **More timely switching feedback**: optimized reconnection waits after profile changes and clear results reduce uncertainty during long waits.
- **Nine interface languages**: follow the system language by default or choose a supported language, making the app easier to use across regions.
- **Designed for modern Android devices**: adapted for Android 17, focused on 64-bit devices, with modern edge-to-edge layouts and back gesture support.

## What you can do

- Scan a QR code or enter an activation code to download a new eSIM profile.
- View installed profiles, enable or disable them, and switch the active profile.
- Rename profiles and delete those you no longer need to organize your eSIM list.
- View card information, check device compatibility, and manage cards through compatible USB CCID readers.

## Supported languages

English, Simplified Chinese, Traditional Chinese, Japanese, Korean, Arabic, French, German, and Spanish.

The interface falls back to English when the system language is not supported.

## Download and get started

Current version: **2.0.1**. Get the APK from the [download page](https://github.com/Stickmin522/FluxEUICC/releases/latest).

1. Install the app on a 64-bit ARM device running Android 9 or later.
2. Insert an OpenEUICC-compatible removable eSIM or connect a compatible USB reader.
3. Cards used in a phone's SIM slot must authorize FluxEUICC's signing certificate. View and copy the required fingerprint in the app's settings.
4. Add your profiles and choose the eSIM you want to enable.

Available features depend on phone, card, and reader compatibility. Network recovery time after switching depends on the card and phone system.

## Open source and license

FluxEUICC is based on OpenEUICC and distributed under the [GPL-3.0-only license](LICENSE), with upstream copyright notices preserved. Dependency licenses are included in their respective directories.
