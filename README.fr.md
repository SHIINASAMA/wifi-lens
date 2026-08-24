# WiFi Lens

**Une application native open source de diagnostic réseau pour macOS avec analyse Wi-Fi intégrée.**

Diagnostiquez les problèmes de connectivité, analysez la congestion des canaux Wi-Fi et validez le comportement de roaming — avec des résultats traités localement sur votre Mac.

[![Latest release](https://img.shields.io/github/v/release/SHIINASAMA/wifi-lens?label=Latest&color=2563eb)](https://github.com/SHIINASAMA/wifi-lens/releases/latest)
[![macOS](https://img.shields.io/badge/platform-macOS%2014%2B-lightgrey)](https://github.com/SHIINASAMA/wifi-lens/releases/latest)
[![License](https://img.shields.io/badge/license-Apache%202.0-blue)](LICENSE)
[![Swift CI](https://github.com/SHIINASAMA/wifi-lens/workflows/Swift%20CI/badge.svg)](https://github.com/SHIINASAMA/wifi-lens/actions?query=workflow%3A%22Swift+CI%22)

<p align="center"><img alt="WiFi Lens analyse spectrale sur macOS" src="assets/screenshot-hero.webp" width="800"></p>

<p align="center">
  <a href="https://github.com/SHIINASAMA/wifi-lens/releases/latest"><strong>Télécharger l'édition open source</strong></a>
  &nbsp;·&nbsp;
  <a href="https://apps.apple.com/app/wifi-lens-pro/id6776590746"><strong>Obtenir WiFi Lens Pro</strong></a>
  &nbsp;·&nbsp;
  <a href="https://wifi-lens.shiinalabs.com">Site web officiel</a>
</p>

<p align="center">macOS 14+ &nbsp;·&nbsp; Intel &amp; Apple Silicon &nbsp;·&nbsp; Sans télémétrie</p>

<p align="center">
  🔒 <strong>Confidentialité locale</strong> — Pas de compte, pas de cloud, pas de télémétrie<br>
  🩺 <strong>Diagnostic fondé sur des preuves</strong> — Vérifications chemin, DNS, HTTPS et proxy<br>
  🤖 <strong>MCP pour les workflows IA</strong> — Connectez Claude Desktop aux données Wi-Fi en direct
</p>

---

<p align="center">
  <a href="README.md">🇺🇸 English</a> · <a href="README.de.md">🇩🇪 Deutsch</a> · <a href="README.es-ES.md">🇪🇸 Español</a> · 🇫🇷 Français · <a href="README.zh-Hans.md">🇨🇳 简体中文</a> · <a href="README.ja.md">🇯🇵 日本語</a>
</p>
<p align="center">
  <a href="#fonctionnalités">Fonctionnalités</a> · <a href="#éditions">Éditions</a> · <a href="#ia--mcp-intégration">IA / MCP</a> · <a href="#confidentialité">Confidentialité</a> · <a href="#installation">Installation</a> · <a href="#développement">Développement</a> · <a href="#contribuer">Contribuer</a> · <a href="#licence">Licence</a>
</p>

---

## Fonctionnalités

### Cœur · OSS & Pro

| Fonctionnalité | Description | Statut |
|---------------|-------------|--------|
| 📡 Scan Wi-Fi | Scan en temps réel des bandes 2,4 / 5 / 6 GHz | Stable |
| 📊 Vue Spectre | Courbes gaussiennes d'occupation des canaux | Stable |
| 🎯 Qualité du canal | Scores de congestion avec recommandations régionales | Stable |
| 🔍 Détails du réseau | Génération PHY, largeur de canal, 802.11k/r/v, WPA3 | Stable |
| 📶 Informations de connexion | IP, passerelle, DNS, MAC, débit Tx, sécurité | Stable |
| 🚶 Test de roaming | Suivi des transitions AP avec gestion des sessions | Stable |
| 🗺️ Carte de chaleur des canaux | Carte de chaleur d'occupation par bande | Stable |
| 🎧 Scanner BLE | Découverte Bluetooth LE, analyse RSSI, suivi | Stable |
| 🎨 Coloration intelligente | Attribution déterministe basée sur le SSID | Stable |
| 🌐 Serveur MCP | API HTTP intégrée pour les outils d'IA | Stable |
| 📤 Export | Enregistrez les graphiques en PNG ou CSV | Stable |
| 🔒 Confidentialité d'abord | Pas de télémétrie ; données locales | Stable |
| ⬆️ Mises à jour automatiques | Sparkle (GitHub) ou Mac App Store | Stable |
| 🌍 Localisé | Anglais, allemand, espagnol, japonais, chinois | Stable |
| 🩺 Auto-diagnostic réseau | Diagnostic chemin, DNS, HTTPS et proxy en un clic | Aperçu |
| 📻 Radar AP | Suivi d'un point d'accès par impulsions audio | Aperçu |

### Exclusif Pro

| Fonctionnalité | Description | Statut |
|---------------|-------------|--------|
| 📈 Chronologie des événements | Historique des événements — roaming, déconnexions, changements de signal | Aperçu |
| 📋 Statistiques | Analyse de l'historique chronologique avec comparaison de périodes | Aperçu |
| 💡 Perspectives | Conclusions explicables liées aux preuves | Aperçu |
| 🎬 Enregistrement spectral | Capturez et relisez l'évolution du spectre | Stable |
| 📱 Barre de menus | Accès rapide depuis la barre de menus macOS | Stable |

---

## Éditions

| | Open Source | WiFi Lens Pro |
|--|------------|--------------|
| Prix | Gratuit | Achat unique |
| Source | [GitHub Releases](https://github.com/SHIINASAMA/wifi-lens/releases/latest) | [Mac App Store](https://apps.apple.com/app/wifi-lens-pro/id6776590746) |
| Analyse principale | ✅ Toutes les fonctionnalités ci-dessus | ✅ Tout le contenu OSS |
| Outils exclusifs | — | Chronologie · Statistiques · Perspectives · Enregistrement · Menu |
| Mises à jour | Sparkle auto-update | Mac App Store |

> Les deux éditions partagent le même moteur d'analyse. Pro ajoute des workflows de surveillance professionnels.

---

## IA / MCP Intégration

WiFi Lens inclut un serveur MCP intégré permettant aux assistants IA de lire vos données Wi-Fi locales. Activez-le dans les réglages, puis ajoutez-le à Claude Desktop :

```json
{
  "mcpServers": {
    "wifi-lens": {
      "url": "http://127.0.0.1:19840"
    }
  }
}
```

Une fois connecté, demandez à Claude : _« Quels canaux sont congestionnés près de moi ? »_ ou _« Ma passerelle est-elle accessible ? »_. Le serveur se lie uniquement à `127.0.0.1` — rien ne quitte votre machine sauf si vous l'acheminez délibérément ailleurs.

Consultez le [guide des flux IA](https://wifi-lens.shiinalabs.com/ai-mcp/) pour plus d'exemples.

---

<table>
<tr>
<td width="50%" align="center"><img alt="Vue de l'auto-diagnostic réseau" src="assets/screenshot-selfcheck.webp" width="100%"><sub>Auto-diagnostic réseau</sub></td>
<td width="50%" align="center"><img alt="Chronologie montrant l'historique de connexion" src="assets/screenshot-timeline.webp" width="100%"><sub>Chronologie (Pro)</sub></td>
</tr>
</table>

---

## Confidentialité

WiFi Lens ne collecte aucune analytique d'utilisation, télémétrie de plantage ni donnée de scan Wi-Fi.

- **Services de localisation :** macOS exige cette autorisation pour exposer les noms SSID Wi-Fi. WiFi Lens ne lit pas la position GPS.
- **Détection de région :** Utilise la langue du système, la liste des canaux du matériel et les codes pays des AP voisins sur l'appareil.
- **Auto-diagnostic réseau :** Résout des endpoints publics (`www.apple.com`, `www.msftconnecttest.com`) et peut tester l'accessibilité des proxies configurés.
- **Serveur MCP :** Se lie uniquement à `127.0.0.1`. Les outils locaux accèdent aux données après activation.
- **Vérifications de mises à jour :** L'édition GitHub contacte GitHub lors des vérifications de mises à jour.

📋 [Politique de sécurité](SECURITY.md) · 📝 [Changelog](https://github.com/SHIINASAMA/wifi-lens/releases) · ❓ [FAQ](https://wifi-lens.shiinalabs.com/faq/) · 🌐 [Politique de confidentialité complète](https://wifi-lens.shiinalabs.com/privacy/)

---

## Installation

Nécessite **macOS 14 (Sonoma) ou ultérieur**. Fonctionne sur Mac Intel et Apple Silicon. Le scan 6 GHz nécessite un matériel Wi-Fi 6E/7.

- **Édition open source** — [GitHub Releases](https://github.com/SHIINASAMA/wifi-lens/releases/latest) (gratuit, Sparkle auto-updates)
- **WiFi Lens Pro** — [Mac App Store](https://apps.apple.com/app/wifi-lens-pro/id6776590746)

> [!IMPORTANT]
> Sur macOS 14+, les **Services de localisation** doivent être activés pour lire les noms SSID Wi-Fi. Allez dans **Réglages Système → Confidentialité et sécurité → Localisation**.

---

## Développement

```sh
git clone https://github.com/SHIINASAMA/wifi-lens
cd wifi-lens
git submodule update --init ChartLens
cd WiFiLens

xcodebuild -project WiFiLens.xcodeproj -scheme "WiFi Lens" \
  -configuration Debug -destination 'platform=macOS' build
```

Documentation d'architecture dans [docs/](docs/).

---

## Contribuer

Les rapports de bugs et idées de fonctionnalités sont bienvenus. Consultez les [Directives de contribution](.github/CONTRIBUTING.md) pour la configuration et les conventions. Les contributeurs majeurs peuvent recevoir un code promo Pro — voir [Reconnaissance des contributeurs](.github/CONTRIBUTING.md#contributor-recognition).

**Contact :** [@WiFiLens sur X](https://x.com/WiFiLens) · [wifi-lens@shiinalabs.com](mailto:wifi-lens@shiinalabs.com)

---

Forked from [tiny-wifi-analyzer](https://github.com/nolze/tiny-wifi-analyzer). Données de fabricants MAC de l'[IEEE Registration Authority](https://standards.ieee.org/products-programs/regauth/) — voir [Mentions tierces](docs/THIRD-PARTY-NOTICES.md).

Apache License 2.0 © 2020 nolze, 2026 SHIINASAMA — voir [LICENSE](LICENSE).
