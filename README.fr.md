# FluxEUICC

[English](README.md) | [简体中文](README.zh-CN.md) | [繁體中文](README.zh-TW.md) | [日本語](README.ja.md) | [한국어](README.ko.md) | [العربية](README.ar.md) | **Français** | [Deutsch](README.de.md) | [Español](README.es.md)

**Ajoutez, changez et gérez vos profils eSIM en toute simplicité.**

FluxEUICC est une application Android de gestion des cartes eSIM amovibles, basée sur [OpenEUICC](https://gitea.angry.im/PeterCxy/OpenEUICC). Elle regroupe vos profils dans une interface claire pour les télécharger, les gérer et passer de l’un à l’autre au quotidien, sans accès root.

<p align="center">
  <img src="art/FluxEUICC-logo.png" alt="FluxEUICC" width="240" height="240">
</p>

> **Avant de commencer**
>
> FluxEUICC gère uniquement les cartes eSIM amovibles compatibles avec OpenEUICC. Installer cette application ne suffit pas à ajouter la prise en charge de l’eSIM à un téléphone qui en est dépourvu. Avant d’utiliser l’application, achetez une carte eSIM amovible compatible, telle qu’une carte eSTK ou 9eSIM.

## Pourquoi choisir FluxEUICC ?

- **Une interface moderne et claire** : des profils présentés sous forme de cartes, un état d’activation visible et des menus simples rendent les actions courantes faciles à trouver. Les couleurs du thème système et les icônes adaptatives permettent à l’application de s’intégrer à votre appareil.
- **Un retour d’information plus rapide** : l’attente de reconnexion après un changement de profil est optimisée, et les résultats sont clairement indiqués pour réduire l’incertitude pendant les longues attentes.
- **Une interface en neuf langues** : l’application suit la langue du système par défaut, ou vous laisse choisir une langue prise en charge.
- **Pensée pour les appareils Android modernes** : adaptée à Android 17 et aux appareils 64 bits, avec un affichage bord à bord et la prise en charge du geste de retour.

## Ce que vous pouvez faire

- Scanner un QR code ou saisir un code d’activation pour télécharger un nouveau profil eSIM.
- Consulter les profils installés, les activer ou les désactiver et changer de profil actif.
- Renommer les profils et supprimer ceux dont vous n’avez plus besoin pour organiser votre liste d’eSIM.
- Consulter les informations de la carte, vérifier la compatibilité de l’appareil et gérer les cartes avec des lecteurs USB CCID compatibles.

## Langues prises en charge

Anglais, chinois simplifié, chinois traditionnel, japonais, coréen, arabe, français, allemand et espagnol.

L’interface s’affiche en anglais lorsque la langue du système n’est pas prise en charge.

## Téléchargement et premiers pas

Version actuelle : **1.1.2**. Téléchargez l’APK sur la [page de téléchargement](https://github.com/Stickmin522/FluxEUICC/releases/latest).

1. Installez l’application sur un appareil ARM 64 bits équipé d’Android 9 ou d’une version ultérieure.
2. Insérez une eSIM amovible compatible avec OpenEUICC ou connectez un lecteur USB compatible.
3. Les cartes utilisées dans le logement SIM du téléphone doivent autoriser le certificat de signature de FluxEUICC. Vous pouvez consulter et copier l’empreinte requise dans les paramètres de l’application.
4. Ajoutez vos profils et choisissez l’eSIM à activer.

Les fonctionnalités disponibles dépendent de la compatibilité du téléphone, de la carte et du lecteur. Le délai de rétablissement du réseau après un changement de profil dépend de la carte et du système du téléphone.

## Code source et licence

FluxEUICC est basé sur OpenEUICC et distribué sous [licence GPL-3.0-only](LICENSE), avec conservation des mentions de droits d’auteur du projet d’origine. Les licences des dépendances figurent dans leurs répertoires respectifs.
