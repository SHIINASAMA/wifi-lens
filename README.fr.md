# WiFi Lens

**Une application native open source de diagnostic réseau pour macOS avec analyse Wi-Fi intégrée.**

Diagnostiquez les problèmes de connectivité, analysez la congestion des canaux Wi-Fi et validez le comportement de roaming — les résultats sont traités localement sur votre Mac.

[![Dernière version](https://img.shields.io/github/v/release/SHIINASAMA/wifi-lens?label=Latest&color=2563eb)](https://github.com/SHIINASAMA/wifi-lens/releases/latest)
[![macOS](https://img.shields.io/badge/platform-macOS%2014%2B-lightgrey)](https://github.com/SHIINASAMA/wifi-lens/releases/latest)
[![Licence](https://img.shields.io/badge/license-Apache%202.0-blue)](LICENSE)
[![Swift CI](https://github.com/SHIINASAMA/wifi-lens/workflows/Swift%20CI/badge.svg)](https://github.com/SHIINASAMA/wifi-lens/actions?query=workflow%3A%22Swift+CI%22)

<p align="center">
  <a href="https://github.com/SHIINASAMA/wifi-lens/releases/latest"><strong>Télécharger l'édition open source</strong></a>
  ·
  <a href="https://apps.apple.com/app/wifi-lens-pro/id6776590746"><strong>Obtenir WiFi Lens Pro</strong></a>
  ·
  <a href="https://wifi-lens.shiinalabs.com">Site web officiel</a>
</p>

macOS 14+ · Intel & Apple Silicon · Sans télémétrie

<img alt="WiFi Lens affichant l'analyse du spectre Wi-Fi sur macOS" src="assets/screenshot-swiftui.png" width="800">

## Open source ou Pro ?

| Édition open source | WiFi Lens Pro |
|---|---|
| Gratuite et open source — [GitHub Releases](https://github.com/SHIINASAMA/wifi-lens/releases/latest) | Édition payante unique sur le Mac App Store — [Mac App Store](https://apps.apple.com/app/wifi-lens-pro/id6776590746) |
| Scan Wi-Fi tri-bande et analyse du spectre | Flux de travail de surveillance professionnels basés sur le même moteur d'analyse principal |
| Qualité des canaux, détails réseau, tests de roaming | Enregistrement de sessions spectrales — capture et relecture dans le temps |
| Auto-diagnostic réseau, scanner BLE, serveur MCP | Flux de travail professionnels supplémentaires |
| Export PNG/CSV · Mises à jour Sparkle | Barre de menus persistante · Chronologie des événements · Mises à jour Mac App Store |

> Les deux éditions partagent les mêmes capacités d'analyse Wi-Fi principales. Pro ajoute l'enregistrement spectral, la barre de menus persistante et la chronologie des événements pour les flux de travail professionnels.

🇺🇸 [English](README.md) | 🇩🇪 [Deutsch](README.de.md) | 🇪🇸 [Español](README.es-ES.md) | 🇫🇷 [Français](README.fr.md) | 🇨🇳 [简体中文](README.zh-Hans.md) | 🇯🇵 [日本語](README.ja.md)

---

## À propos de WiFi Lens

WiFi Lens est une application macOS native de diagnostic réseau, développée avec SwiftUI, CoreWLAN et CoreBluetooth. Elle vous aide à résoudre les problèmes de connectivité grâce à l'auto-diagnostic réseau, au scan Wi-Fi, à l'analyse de la congestion des canaux et à la validation du roaming. Le scanner BLE intégré offre une visibilité supplémentaire sur les appareils sans fil à proximité.

Ce dépôt contient l'édition gratuite et open source. WiFi Lens Pro est une édition payante distincte qui ajoute l'enregistrement spectral, la barre de menus persistante et la chronologie des événements.

**Cas d'utilisation typiques :**

- 🏠 **Optimisation du réseau domestique :** Trouvez les canaux saturés par vos voisins et déplacez votre routeur vers un canal plus calme.
- 🏢 **Audit Wi-Fi de bureau :** Scannez les trois bandes (2,4, 5 et 6 GHz) pour repérer les zones mortes ou les points d'accès mal configurés.
- 🚶 **Validation du roaming :** Parcourez un bâtiment et enregistrez chaque transition de point d'accès avec un graphique chronologique pour vérifier la fluidité du passage.
- 🎧 **Dépannage d'appareils BLE :** Suivez les tendances RSSI des périphériques Bluetooth et identifiez les problèmes de portée ou d'interférences.

---

## Fonctionnalités

| Catégorie | Capacité | Édition |
|----------|-----------|---------|
| 📡 **Scan Wi-Fi** | Scan en temps réel des bandes 2,4, 5 et 6 GHz avec l'intensité du signal par réseau | OSS & Pro |
| 📊 **Vue Spectre** | Courbes en cloche gaussiennes montrant l'occupation des canaux en un coup d'œil | OSS & Pro |
| 🎯 **Qualité du canal** | Scores de congestion avec recommandations adaptées à votre région, tenant compte de la réglementation | OSS & Pro |
| 🔍 **Détails du réseau** | Génération PHY, largeur de canal, roaming 802.11k/r/v, WPA3, SSID masqué | OSS & Pro |
| 📶 **Informations de connexion** | IP, passerelle, DNS, MAC, canal, débit Tx et résumé de sécurité | OSS & Pro |
| 🩺 **Auto-diagnostic réseau** | Diagnostic de connexion en un clic — chemin, DNS, HTTPS et accessibilité du proxy, avec des conclusions fondées sur des preuves | OSS & Pro |
| 📈 **Chronologie des événements** | Historique des événements de connexion — roaming, changements de canal, déconnexions et chutes de signal | Pro uniquement |
| 🔄 **Test de roaming** | Suivi des transitions entre points d'accès avec graphique chronologique, sélecteur de plage et sauvegarde/chargement de session | OSS & Pro |
| 🗺️ **Carte de chaleur des canaux** | Carte de chaleur d'occupation par bande pour repérer instantanément les schémas de congestion | OSS & Pro |
| 🎬 **Enregistrement spectral** | Capturez et relisez l'évolution du spectre dans le temps | Pro uniquement |
| 🎧 **Scanner BLE** | Découverte d'appareils Bluetooth LE, analyse RSSI, graphiques de tendance et suivi des appareils | OSS & Pro |
| 🎨 **Coloration intelligente** | Attribution déterministe des couleurs basée sur le SSID ; le même réseau conserve la même couleur | OSS & Pro |
| 📍 **Barre de menus** | Vit dans votre barre de menus — cliquez sur l'icône pour ouvrir l'analyseur à tout moment | Pro uniquement |
| 🔒 **Confidentialité d'abord** | Pas de télémétrie ni d'analytique ; les données de scan Wi-Fi restent sur votre Mac | OSS & Pro |
| 🌐 **Serveur MCP** | API HTTP intégrée sur `127.0.0.1:19840` pour l'intégration d'outils externes | OSS & Pro |
| 🔄 **Mises à jour automatiques** | Mises à jour Sparkle dans l'édition GitHub ; mises à jour Mac App Store dans Pro | OSS & Pro |
| 📤 **Export** | Enregistrez les graphiques par bande en images PNG ou en données CSV | OSS & Pro |
| 🌍 **Localisé** | Anglais, allemand, espagnol, japonais et chinois simplifié | OSS & Pro |

Toutes les fonctionnalités sont incluses dans l'édition open source, sauf indication **Pro uniquement**. Pro inclut toutes les fonctionnalités open source ainsi que les outils d'enregistrement, de barre de menus et de chronologie des événements.

---

## Conception

**Interface macOS native.** CoreWLAN communique directement avec le matériel Wi-Fi, et SwiftUI fournit des contrôles et un comportement de fenêtres natifs pour Mac.

**Recommandations tenant compte de la réglementation.** WiFi Lens déduit votre domaine réglementaire à partir des paramètres régionaux du système, des capacités matérielles et des codes pays des points d'accès à proximité. Il filtre les recommandations selon les exigences DFS, d'usage intérieur uniquement et d'AFC pour la bande 6 GHz.

**Vues liées.** Sélectionnez un réseau dans le tableau pour le mettre en évidence sur chaque graphique. Survolez une courbe en cloche pour identifier son SSID.

**Outils de l'édition open source.** Exportez des fichiers PNG et CSV ou enregistrez et chargez des sessions de roaming. Le serveur MCP local connecte WiFi Lens à vos propres outils.

---

## Téléchargement

Nécessite **macOS 14 (Sonoma) ou version ultérieure**. Fonctionne sur les Mac Intel et Apple Silicon. Le scan de la bande 6 GHz nécessite du matériel Wi-Fi 6E/7.

- **Édition open source** — [GitHub Releases](https://github.com/SHIINASAMA/wifi-lens/releases/latest) (gratuite, avec mises à jour automatiques Sparkle en option)
- **WiFi Lens Pro** — [Mac App Store](https://apps.apple.com/app/wifi-lens-pro/id6776590746) (régions prises en charge)

> [!IMPORTANT]
> Sur macOS 14+, les **Services de localisation** doivent être activés pour que l'application puisse lire les noms de SSID Wi-Fi.
> Ouvrez **Réglages Système → Confidentialité et sécurité → Localisation** et activez WiFi Lens lorsque vous y êtes invité.

> 🌐 **Site web officiel :** [wifi-lens.shiinalabs.com](https://wifi-lens.shiinalabs.com) propose des captures d'écran, une visite guidée des fonctionnalités, des flux de travail IA/MCP et une FAQ.

## Confidentialité

WiFi Lens ne collecte aucune donnée d'utilisation, aucune télémétrie de plantage ni aucune donnée de scan Wi-Fi.

- **Services de localisation :** macOS exige cette autorisation pour exposer les noms de SSID Wi-Fi. WiFi Lens ne lit pas votre position GPS.
- **Détection de la région :** WiFi Lens utilise les paramètres régionaux du système, la liste des canaux signalée par le matériel et les codes pays des points d'accès à proximité, sur l'appareil.
- **Auto-diagnostic réseau :** Lorsque vous l'exécutez, WiFi Lens résout des points de terminaison publics (`www.apple.com`, `www.microsoft.com`, `www.msftconnecttest.com`) et peut tester l'accessibilité de vos points de terminaison proxy configurés.
- **Serveur MCP :** Le serveur facultatif se lie à `127.0.0.1`. Les outils locaux ne peuvent accéder aux données de scan qu'après l'avoir activé.
- **Vérification des mises à jour :** L'édition GitHub contacte GitHub lorsque vous demandez une vérification des mises à jour ou activez les vérifications automatiques.

---

## Développement

```sh
git clone https://github.com/SHIINASAMA/wifi-lens
cd wifi-lens
git submodule update --init ChartLens
cd WiFiLens

# Compiler
xcodebuild -project WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' build

# Exécuter les tests
xcodebuild -project WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test -only-testing:WiFiLensTests

# Ouvrir dans Xcode
xed WiFiLens.xcodeproj
```

Le nom du produit est `WiFi Lens.app` (avec un espace).

La documentation sur l'architecture, les tests et la feuille de route se trouve dans [docs/](docs/).

---

## Contribuer

Les signalements de bogues et les idées de fonctionnalités sont les bienvenus. Ouvrez une [issue](https://github.com/SHIINASAMA/wifi-lens/issues) ou lancez une [discussion](https://github.com/SHIINASAMA/wifi-lens/discussions).

Consultez les [règles de contribution](.github/CONTRIBUTING.md) pour la configuration de développement, les conventions des pull requests et les exigences de localisation. Si vous utilisez des agents de programmation, consultez également [.agents/references/collaboration-rules.md](.agents/references/collaboration-rules.md) pour les recommandations destinées aux assistants IA.

À sa discrétion, le mainteneur peut reconnaître les contributions substantielles à WiFi Lens avec un code promotionnel WiFi Lens Pro émis par Apple. Voir [Reconnaissance des contributeurs](.github/CONTRIBUTING.md#contributor-recognition) pour plus de détails.

**Contact :** [@WiFiLens sur X](https://x.com/WiFiLens) · [wifi-lens@shiinalabs.com](mailto:wifi-lens@shiinalabs.com)

---

## Remerciements

Bifurqué de [tiny-wifi-analyzer](https://github.com/nolze/tiny-wifi-analyzer) par [nolze](https://github.com/nolze), qui a créé le scanner Wi-Fi original basé sur Python. Depuis, l'application a été entièrement réécrite en Swift avec SwiftUI et CoreWLAN, pour devenir l'application macOS native qu'elle est aujourd'hui.

---

## Licence

Apache License 2.0 © 2020 nolze, 2026 SHIINASAMA. Voir [LICENSE](LICENSE) pour le texte complet.
