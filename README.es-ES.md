<picture>
  <source media="(prefers-color-scheme: dark)" srcset="assets/screenshot-swiftui.png">
  <img alt="WiFi Lens analizador de espectro Wi-Fi para macOS" src="assets/screenshot-swiftui.png" width="800">
</picture>

# WiFi Lens

[![Swift CI](https://github.com/SHIINASAMA/wifi-lens/workflows/Swift%20CI/badge.svg)](https://github.com/SHIINASAMA/wifi-lens/actions?query=workflow%3A%22Swift+CI%22)
[![License](https://img.shields.io/badge/license-Apache%202.0-blue)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-lightgrey)](https://github.com/SHIINASAMA/wifi-lens/releases/latest)
[![X](https://img.shields.io/badge/X-@WiFiLens-1d9bf0)](https://x.com/WiFiLens)
[![Email](https://img.shields.io/badge/email-wifi--lens@outlook.com-0078d4)](mailto:wifi-lens@outlook.com)
[![Website](https://img.shields.io/badge/website-wifi--lens.shiinalabs.com-2563eb)](https://wifi-lens.shiinalabs.com)

🇺🇸 [English](README.md) | 🇩🇪 [Deutsch](README.de.md) | 🇪🇸 [Español](README.es-ES.md) | 🇨🇳 [简体中文](README.zh-Hans.md) | 🇯🇵 [日本語](README.ja.md)

**Una herramienta nativa de macOS para analizar y optimizar tus redes Wi-Fi.**

<p align="center">
  <a href="https://apps.apple.com/app/wifi-lens-pro/id6776590746">
    <img src="assets/appstore-badge-en.svg" alt="Descargar WiFi Lens Pro en el Mac App Store" width="240">
  </a>
</p>

---

## Acerca de WiFi Lens

WiFi Lens es un analizador nativo de Wi-Fi y Bluetooth para macOS, desarrollado con SwiftUI, CoreWLAN y CoreBluetooth. Muestra las redes inalámbricas y los dispositivos BLE cercanos en tiempo real para que puedas diagnosticar problemas de conectividad, elegir un canal menos congestionado y verificar el roaming entre puntos de acceso.

Este repositorio contiene la edición gratuita y de código abierto. WiFi Lens Pro es una edición de pago independiente con funciones adicionales.

**Casos de uso típicos:**

- 🏠 **Optimización de la red doméstica:** Identifica canales saturados y cambia el router a uno menos congestionado.
- 🏢 **Auditoría Wi-Fi de oficina:** Escanea las bandas de 2,4, 5 y 6 GHz para detectar zonas sin cobertura o puntos de acceso mal configurados.
- 🚶 **Validación de roaming:** Registra cada cambio de punto de acceso en una línea temporal mientras recorres un edificio.
- 🎧 **Diagnóstico de dispositivos BLE:** Sigue las tendencias de RSSI de periféricos Bluetooth e identifica problemas de alcance o interferencias.

---

## Funciones

| Categoría | Capacidad |
|----------|-----------|
| 📡 **Escaneo Wi-Fi** | Escaneo en tiempo real de las bandas de 2,4, 5 y 6 GHz con intensidad de señal por red |
| 📊 **Vista de Espectro** | Gráficos de curva de campana gaussiana que muestran la ocupación del canal al instante |
| 🎯 **Calidad del Canal** | Puntuaciones de congestión con recomendaciones basadas en región adaptadas a tu dominio regulatorio |
| 🔍 **Detalles de Red** | Generación PHY, ancho de canal, roaming 802.11k/r/v, WPA3, SSID oculto |
| 📶 **Información de Conexión** | IP, gateway, DNS, MAC, canal, tasa Tx y resumen de seguridad |
| 📈 **Gráficos de Tendencias** | Historial de señal por red a lo largo del tiempo con intervalo de escaneo configurable |
| 🔄 **Prueba de Roaming** | Monitoreo de transición AP con gráfico temporal, selector de rango y guardado/carga de sesión |
| 🗺️ **Mapa de Calor del Canal** | Mapa de calor de ocupación por banda para identificar patrones de congestión al instante |
| 🎧 **Escáner BLE** | Descubrimiento de dispositivos Bluetooth LE, análisis RSSI, gráficos de tendencias y seguimiento de dispositivos |
| 🎨 **Colores Inteligentes** | Asignación de color determinista basada en el SSID; la misma red conserva el mismo color |
| 🔒 **Privacidad Primero** | Sin telemetría ni analítica; los datos de escaneo Wi-Fi permanecen en tu Mac |
| 🌐 **Servidor MCP** | API HTTP embebida en `127.0.0.1:19840` para integración con herramientas externas |
| 🔄 **Actualizaciones Automáticas** | Comprobaciones opcionales mediante Sparkle en la edición de GitHub |
| 📤 **Exportar** | Guarda gráficos por banda como imágenes PNG o datos CSV |
| 🌍 **Localizado** | Inglés, alemán, español, japonés y chino simplificado |

---

## Diseño

**Interfaz nativa de macOS.** CoreWLAN se comunica directamente con el hardware Wi-Fi. SwiftUI proporciona controles y comportamiento de ventanas propios de macOS.

**Recomendaciones con contexto regulatorio.** WiFi Lens determina el dominio regulatorio mediante la región del sistema, las capacidades del hardware y los códigos de país de puntos de acceso cercanos. La aplicación filtra las recomendaciones según los requisitos DFS, de uso en interiores y AFC de 6 GHz.

**Vistas vinculadas.** Selecciona una red en la tabla para resaltarla en cada gráfico. Pasa el cursor sobre una curva de campana para identificar su SSID.

**Herramientas de la edición de código abierto.** Exporta archivos PNG y CSV o guarda y carga sesiones de roaming. El servidor MCP local conecta WiFi Lens con tus propias herramientas.

---

## Descargar

[![Descargar última versión](https://img.shields.io/github/v/release/SHIINASAMA/wifi-lens?label=Latest&color=2563eb)](https://github.com/SHIINASAMA/wifi-lens/releases/latest/)
[![Descargar WiFi Lens Pro en el Mac App Store](https://img.shields.io/badge/Download-Mac%20App%20Store-black?logo=apple)](https://apps.apple.com/app/wifi-lens-pro/id6776590746)

GitHub Releases ofrece la edición de código abierto. WiFi Lens Pro está disponible en el Mac App Store en las regiones compatibles.

Requiere macOS 14 (Sonoma) o posterior. Funciona en Macs Intel y Apple Silicon.

> 🌐 **Sitio web oficial:** [wifi-lens.shiinalabs.com](https://wifi-lens.shiinalabs.com) ofrece capturas de pantalla, una guía de funciones, flujos de trabajo de IA/MCP y preguntas frecuentes.

> [!IMPORTANT]
> En macOS 14 o posterior, los **Servicios de localización** deben estar activados para que la app lea los nombres SSID Wi-Fi.
> Ve a **Ajustes del Sistema → Privacidad y seguridad → Localización** y activa WiFi Lens cuando se solicite.

## Privacidad

WiFi Lens no recopila analítica de uso, telemetría de fallos ni datos de escaneo Wi-Fi.

- **Servicios de localización:** macOS necesita este permiso para mostrar los nombres SSID Wi-Fi. WiFi Lens no lee tu posición GPS.
- **Detección de región:** WiFi Lens usa la región del sistema, la lista de canales informada por el hardware y los códigos de país de puntos de acceso cercanos en el dispositivo.
- **Autodiagnóstico de red:** Cuando lo ejecutas, WiFi Lens resuelve `example.com` y puede comprobar si los endpoints de proxy configurados son accesibles.
- **Servidor MCP:** El servidor opcional se vincula a `127.0.0.1`. Las herramientas locales acceden a los datos de escaneo después de que lo habilites.
- **Comprobaciones de actualizaciones:** La edición de GitHub contacta con GitHub cuando solicitas una comprobación o habilitas las comprobaciones automáticas.

---

## Desarrollar

```sh
git clone https://github.com/SHIINASAMA/wifi-lens
cd wifi-lens
git submodule update --init ChartLens
cd WiFiLens

# Construir
xcodebuild -project WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' build

# Ejecutar tests
xcodebuild -project WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' -skipPackageUpdates test -only-testing:WiFiLensTests

# Abrir en Xcode
xed WiFiLens.xcodeproj
```

El nombre del producto es `WiFi Lens.app` (con espacio).

La documentación de arquitectura, pruebas y hoja de ruta se encuentra en [docs/](docs/).

---

## Contribuir

Los informes de errores y las propuestas de funciones son bienvenidos. Abre un [issue](https://github.com/SHIINASAMA/wifi-lens/issues) o inicia una [discussion](https://github.com/SHIINASAMA/wifi-lens/discussions).

Las pull requests deben seguir las convenciones de [.agents/references/project/ARCHITECTURE.md](.agents/references/project/ARCHITECTURE.md) e incluir pruebas cuando sea práctico. Si usas agentes de programación, consulta las directrices de [.agents/references/collaboration-rules.md](.agents/references/collaboration-rules.md).

---

## Agradecimientos

Este proyecto comenzó como una bifurcación de [tiny-wifi-analyzer](https://github.com/nolze/tiny-wifi-analyzer), creado por [nolze](https://github.com/nolze), autor del escáner Wi-Fi original basado en Python. Desde entonces, la app se ha reescrito por completo en Swift con SwiftUI y CoreWLAN y ha evolucionado hasta convertirse en una aplicación nativa de macOS.

---

## Licencia

Apache License 2.0 © 2020 nolze, 2026 SHIINASAMA. Ver [LICENSE](LICENSE) para texto completo.

---

**Topics:** `macos` `wifi` `network` `tool` `swift` `bluetooth` `analyzer` `swiftui` `corewlan` `corebluetooth` `open-source` `mcp`
