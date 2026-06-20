<picture>
  <source media="(prefers-color-scheme: dark)" srcset="assets/screenshot-swiftui.png">
  <img alt="WiFi Lens — macOS Wi-Fi spectrum analyzer" src="assets/screenshot-swiftui.png" width="800">
</picture>

# WiFi Lens

[![Swift CI](https://github.com/SHIINASAMA/wifi-lens/workflows/Swift%20CI/badge.svg)](https://github.com/SHIINASAMA/wifi-lens/actions?query=workflow%3A%22Swift+CI%22)
[![License](https://img.shields.io/badge/license-Apache%202.0-blue)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-lightgrey)](https://github.com/SHIINASAMA/wifi-lens/releases/latest)
[![X](https://img.shields.io/badge/X-@WiFiLens-1d9bf0)](https://x.com/WiFiLens)
[![Email](https://img.shields.io/badge/email-wifi--lens@outlook.com-0078d4)](mailto:wifi-lens@outlook.com)

**Una herramienta nativa de macOS para analizar y optimizar tus redes Wi-Fi.**

<p align="center">
  <a href="https://apps.apple.com/app/id6776590746">
    <img src="assets/appstore-badge-en.svg" alt="Descargar en el Mac App Store" width="240">
  </a>
</p>

---

## ¿Qué es WiFi Lens?

WiFi Lens es un analizador de Wi-Fi y Bluetooth gratuito y de código abierto, construido completamente con frameworks nativos de macOS — SwiftUI, CoreWLAN y CoreBluetooth. Te ofrece un mapa visual en tiempo real de todas las redes inalámbricas y dispositivos BLE a tu alrededor, para que puedas diagnosticar problemas de conectividad, elegir el canal menos congestionado y verificar el comportamiento de roaming entre puntos de acceso.

A diferencia de los escáneres basados en web o las aplicaciones multiplataforma de Electron, WiFi Lens se ejecuta con cero sobrecarga, respeta tu privacidad y se integra perfectamente en tu Mac.

**Casos de uso típicos:**
- 🏠 **Optimización del hogar** — Descubre qué canal están saturando tus vecinos y mueve tu router a uno más tranquilo.
- 🏢 **Auditoría Wi-Fi empresarial** — Escanea los tres bandas (2.4, 5 y 6 GHz) para detectar zonas muertas o APs mal configurados.
- 🚶 **Validación de roaming** — Camina por un edificio y registra cada cambio de AP con un gráfico de línea temporal para verificar la transición fluida.
- 🎧 **Solución de problemas BLE** — Rastrea las tendencias de RSSI de periféricos Bluetooth e identifica problemas de rango o interferencia.

---

## Funciones

| Categoría | Capacidad |
|----------|-----------|
| 📡 **Escaneo Wi-Fi** | Escaneo en tiempo real a través de bandas 2.4, 5 y 6 GHz con intensidad de señal por red |
| 📊 **Vista de Espectro** | Gráficos de curva de campana gaussiana que muestran la ocupación del canal al instante |
| 🎯 **Calidad del Canal** | Puntuaciones de congestión con recomendaciones basadas en región adaptadas a tu dominio regulatorio |
| 🔍 **Detalles de Red** | Generación PHY, ancho de canal, roaming 802.11k/r/v, WPA3, SSID oculto |
| 📶 **Información de Conexión** | IP, gateway, DNS, MAC, canal, tasa Tx y resumen de seguridad |
| 📈 **Gráficos de Tendencias** | Historial de señal por red a lo largo del tiempo con intervalo de escaneo configurable |
| 🔄 **Prueba de Roaming** | Monitoreo de transición AP con gráfico temporal, selector de rango y guardado/carga de sesión |
| 🗺️ **Mapa de Calor del Canal** | Mapa de calor de ocupación por banda para identificar patrones de congestión al instante |
| 🎧 **Escáner BLE** | Descubrimiento de dispositivos Bluetooth LE, análisis RSSI, gráficos de tendencias y seguimiento de dispositivos |
| 🎨 **Colores Inteligentes** | Asignación de color determinista basada en SSID — la misma red siempre obtiene el mismo color |
| 🔒 **Privacidad Primero** | Sin telemetría, sin análisis, sin recolección de datos — todo se queda en tu Mac |
| 🌐 **Servidor MCP** | API HTTP embebida en `127.0.0.1:19840` para integración con herramientas externas |
| 🔄 **Actualizaciones Automáticas** | Soporte de actualización Sparkle integrado para que siempre ejecutes la última versión |
| 📤 **Exportar** | Guarda gráficos por banda como imágenes PNG o datos CSV |
| 🌍 **Localizado** | Soporte completo para inglés, 日本語，简体中文 y español |

---

## Lo que hace diferente a WiFi Lens

**Rendimiento nativo, no un envoltorio web.** CoreWLAN habla directamente con el hardware Wi-Fi — sin middleware, sin puente JavaScript, sin ciclos de CPU desperdiciados. Escanear cientos de redes por pasada en Apple Silicon moderno es effortless.

**Inteligencia regulatoria integrada.** La mayoría de las herramientas muestran números de canal crudos y listo. WiFi Lens infiere tu dominio regulatorio desde el locale del sistema, la capacidad del hardware y los códigos de país de APs cercanos, luego recomienda canales que realmente puedes usar — respetando reglas DFS, indoor-only y 6 GHz AFC.

**Todo está conectado.** Haz clic en una red en la tabla y se resalta en todos los gráficos. Pasa el cursor sobre una curva de campana y el SSID aparece. Congela una banda mientras las otras siguen escaneando. Está diseñado como un cockpit, no como un dashboard.

**Espacio para usuarios avanzados.** Exporta PNG/CSV, ejecuta una prueba de roaming con guardado/carga de sesión o integra tus propias herramientas mediante el servidor HTTP MCP incorporado — todo sin muros de pago ocultos.

---

## Descargar

[![Descargar última versión](https://img.shields.io/github/v/release/SHIINASAMA/wifi-lens?label=Latest&color=2563eb)](https://github.com/SHIINASAMA/wifi-lens/releases/latest/)
[![Descargar en el Mac App Store](https://img.shields.io/badge/Download-Mac%20App%20Store-black?logo=apple)](https://apps.apple.com/app/id6776590746)

Requiere macOS 14 (Sonoma) o posterior. Funciona en Macs Intel y Apple Silicon.

> [!IMPORTANT]
> En macOS 14+, **Location Services** debe estar habilitado para que la app lea nombres SSID Wi-Fi.
> Ve a **System Settings → Privacy & Security → Location Services** y habilita WiFi Lens cuando se solicite.

### Solución de Gatekeeper

La app está completamente firmada y notarizada por Apple.

- Normalmente se abre directamente; o
- Si aparece un bloqueo: **clic derecho** en la app → **Open** → confirmar en el diálogo

---

## Privacidad

WiFi Lens **no recopila nada**. Sin análisis de uso, sin telemetría de crash, sin tráfico de red a servidores externos.

- **Location Services** — Requerido por macOS para exponer nombres SSID Wi-Fi. WiFi Lens nunca lee tu posición GPS.
- **Detección de región** — Usa locale del sistema, lista de canales reportada por hardware y códigos de país de APs cercanos. Se ejecuta completamente en el dispositivo.
- **Servidor MCP** — Vinculado solo a `127.0.0.1`. Los datos de escaneo no salen de tu máquina a menos que los routes explícitamente.

---

## Desarrollar

```sh
git clone https://github.com/SHIINASAMA/wifi-lens
cd wifi-lens/WiFiLens

# Construir
xcodebuild -project WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' build

# Ejecutar tests
xcodebuild -project WiFiLens.xcodeproj -scheme "WiFi Lens" -configuration Debug -destination 'platform=macOS' test

# Abrir en Xcode
xed WiFiLens.xcodeproj
```

El nombre del producto es `WiFi Lens.app` (con espacio).

### Website

La landing page está construida con Vite y Tailwind CSS, outputting a `_site/`.

```sh
cd wifi-lens          # repo root
npm ci
npm run dev           # dev server at localhost:5173/wifi-lens/
npm run build         # production build
npm run preview       # preview production build
```

Architectura, testing y roadmap docs viven en [docs/](docs/).

---

## Contribuir

Los reportes de bugs e ideas de funciones son bienvenidos — abre un [issue](https://github.com/SHIINASAMA/wifi-lens/issues) o inicia una [discussion](https://github.com/SHIINASAMA/wifi-lens/discussions).

Las pull requests deben seguir las convenciones en [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) e incluir cobertura de tests donde sea práctico. Consulta [docs/COLLABORATION_RULES.md](docs/COLLABORATION_RULES.md) para guías de asistentes de código si usas agentes de codificación.

---

## Agradecimientos

Forked from [tiny-wifi-analyzer](https://github.com/nolze/tiny-wifi-analyzer) por [nolze](https://github.com/nolze), quien construyó el escáner Wi-Fi basado en Python original. Desde entonces la app ha sido completamente reescrita en Swift con SwiftUI y CoreWLAN, evolucionando a la aplicación nativa de macOS que es hoy.

---

## Licencia

Apache License 2.0 © 2020 nolze, 2026 SHIINASAMA. Ver [LICENSE](LICENSE) para texto completo.

---

**Topics:** `macos` `wifi` `network` `tool` `swift` `bluetooth` `analyzer` `swiftui` `corewlan` `corebluetooth` `open-source` `mcp`
