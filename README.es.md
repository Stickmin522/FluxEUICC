# FluxEUICC

[English](README.md) | [简体中文](README.zh-CN.md) | [繁體中文](README.zh-TW.md) | [日本語](README.ja.md) | [한국어](README.ko.md) | [العربية](README.ar.md) | [Français](README.fr.md) | [Deutsch](README.de.md) | **Español**

**Añade, cambia y administra tus perfiles eSIM con facilidad.**

FluxEUICC es una aplicación Android para administrar tarjetas eSIM extraíbles, basada en [OpenEUICC](https://gitea.angry.im/PeterCxy/OpenEUICC). Reúne tus perfiles en una interfaz clara para descargarlos, gestionarlos y cambiar entre ellos en el día a día, sin necesidad de acceso root.

<p align="center">
  <img src="art/FluxEUICC-logo.png" alt="FluxEUICC" width="240" height="240">
</p>

## ¿Por qué elegir FluxEUICC?

- **Una interfaz moderna y clara**: los perfiles se muestran como tarjetas, con un estado de activación visible y menús sencillos que facilitan encontrar las acciones habituales. Los colores del tema del sistema y los iconos adaptativos ayudan a integrar la aplicación con tu dispositivo.
- **Resultados más rápidos al cambiar de perfil**: la espera de reconexión tras un cambio está optimizada y los resultados se muestran con claridad, reduciendo la incertidumbre durante las esperas largas.
- **Una interfaz en nueve idiomas**: sigue el idioma del sistema de forma predeterminada o permite elegir uno de los idiomas compatibles.
- **Diseñada para dispositivos Android modernos**: adaptada a Android 17 y centrada en dispositivos de 64 bits, con una interfaz de borde a borde y compatibilidad con el gesto de volver.

## Qué puedes hacer

- Escanear un código QR o introducir un código de activación para descargar un nuevo perfil eSIM.
- Ver los perfiles instalados, activarlos o desactivarlos y cambiar el perfil activo.
- Cambiar el nombre de los perfiles y eliminar los que ya no necesitas para organizar tu lista de eSIM.
- Consultar la información de la tarjeta, comprobar la compatibilidad del dispositivo y administrar tarjetas mediante lectores USB CCID compatibles.

## Idiomas compatibles

Inglés, chino simplificado, chino tradicional, japonés, coreano, árabe, francés, alemán y español.

La interfaz se muestra en inglés cuando el idioma del sistema no está disponible.

## Descarga y primeros pasos

Versión actual: **1.1.2**. Descarga el APK desde la [página de descargas](https://github.com/Stickmin522/FluxEUICC/releases/latest).

1. Instala la aplicación en un dispositivo ARM de 64 bits con Android 9 o posterior.
2. Inserta una eSIM extraíble compatible con OpenEUICC o conecta un lector USB compatible.
3. Las tarjetas utilizadas en la ranura SIM del teléfono deben autorizar el certificado de firma de FluxEUICC. Puedes consultar y copiar la huella necesaria en los ajustes de la aplicación; las instrucciones de la versión incluyen los detalles de configuración.
4. Añade tus perfiles y elige la eSIM que quieres activar.

Las funciones disponibles dependen de la compatibilidad del teléfono, la tarjeta y el lector. El tiempo de recuperación de la red tras un cambio depende de la tarjeta y del sistema del teléfono.

## Código abierto y licencia

FluxEUICC está basada en OpenEUICC y se distribuye bajo la [licencia GPL-3.0-only](LICENSE), conservando los avisos de derechos de autor del proyecto original. Las licencias de las dependencias se incluyen en sus respectivos directorios.
