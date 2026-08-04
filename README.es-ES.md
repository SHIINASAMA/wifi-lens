# WiFi Lens

**Una aplicación nativa de código abierto de diagnóstico de red para macOS con análisis Wi-Fi integrado.**

Diagnostica problemas de conectividad, analiza la congestión de canales Wi-Fi y valida el comportamiento de roaming — con los resultados procesados localmente en tu Mac.

[![Última versión](https://img.shields.io/github/v/release/SHIINASAMA/wifi-lens?label=Latest&color=2563eb)](https://github.com/SHIINASAMA/wifi-lens/releases/latest)
[![macOS](https://img.shields.io/badge/platform-macOS%2014%2B-lightgrey)](https://github.com/SHIINASAMA/wifi-lens/releases/latest)
[![Licencia](https://img.shields.io/badge/license-Apache%202.0-blue)](LICENSE)
[![Swift CI](https://github.com/SHIINASAMA/wifi-lens/workflows/Swift%20CI/badge.svg)](https://github.com/SHIINASAMA/wifi-lens/actions?query=workflow%3A%22Swift+CI%22)

<p align="center">
  <a href="https://github.com/SHIINASAMA/wifi-lens/releases/latest"><strong>Descargar edición de código abierto</strong></a>
  ·
  <a href="https://apps.apple.com/app/wifi-lens-pro/id6776590746"><strong>Obtener WiFi Lens Pro</strong></a>
  ·
  <a href="https://wifi-lens.shiinalabs.com">Sitio web oficial</a>
</p>

macOS 14+ · Intel y Apple Silicon · Sin telemetría

<img alt="WiFi Lens mostrando análisis de espectro Wi-Fi en macOS" src="assets/screenshot-swiftui.png" width="800">

## ¿Código abierto o Pro?

| Edición de código abierto | WiFi Lens Pro |
|---|---|
| Gratuita y de código abierto — [GitHub Releases](https://github.com/SHIINASAMA/wifi-lens/releases/latest) | Edición de pago de un solo pago en Mac App Store — [Mac App Store](https://apps.apple.com/app/wifi-lens-pro/id6776590746) |
| Escaneo Wi-Fi de tres bandas y análisis de espectro | Flujos de trabajo de monitorización profesional sobre el mismo motor de análisis principal |
| Calidad del canal, detalles de red, pruebas de roaming | Grabación de sesiones de espectro — captura y reproducción a lo largo del tiempo |
| Autodiagnóstico de red, escáner BLE, servidor MCP | Flujos de trabajo profesionales adicionales |
| Exportar PNG/CSV · Actualizaciones Sparkle | Barra de menús persistente · Línea temporal de eventos · Actualizaciones de Mac App Store |

> Ambas ediciones comparten las mismas capacidades de análisis principal de Wi-Fi. Pro añade grabación de espectro, barra de menús persistente y línea temporal de eventos para flujos de trabajo profesionales.

🇺🇸 [English](README.md) | 🇩🇪 [Deutsch](README.de.md) | 🇪🇸 [Español](README.es-ES.md) | 🇨🇳 [简体中文](README.zh-Hans.md) | 🇯🇵 [日本語](README.ja.md)

---

## Acerca de WiFi Lens

WiFi Lens es una aplicación nativa de diagnóstico de red para macOS, desarrollada con SwiftUI, CoreWLAN y CoreBluetooth. Te ayuda a solucionar problemas de conectividad mediante autodiagnósticos de red, escaneo Wi-Fi, análisis de congestión de canales y validación de roaming. El escáner BLE integrado proporciona visibilidad adicional de los dispositivos inalámbricos cercanos.

Este repositorio contiene la edición gratuita y de código abierto. WiFi Lens Pro es una edición de pago independiente que añade grabación de espectro, barra de menús persistente y línea temporal de eventos.

**Casos de uso típicos:**

- 🏠 **Optimización de la red doméstica:** Identifica canales saturados y cambia el router a uno menos congestionado.
- 🏢 **Auditoría Wi-Fi de oficina:** Escanea las bandas de 2,4, 5 y 6 GHz para detectar zonas sin cobertura o puntos de acceso mal configurados.
- 🚶 **Validación de roaming:** Registra cada cambio de punto de acceso en una línea temporal mientras recorres un edificio.
- 🎧 **Diagnóstico de dispositivos BLE:** Sigue las tendencias de RSSI de periféricos Bluetooth e identifica problemas de alcance o interferencias.

---

## Funciones

| Categoría | Capacidad | Edición |
|----------|-----------|---------|
| 📡 **Escaneo Wi-Fi** | Escaneo en tiempo real de las bandas de 2,4, 5 y 6 GHz con intensidad de señal por red | OSS & Pro |
| 📊 **Vista de Espectro** | Gráficos de curva de campana gaussiana que muestran la ocupación del canal al instante | OSS & Pro |
| 🎯 **Calidad del Canal** | Puntuaciones de congestión con recomendaciones basadas en región adaptadas a tu dominio regulatorio | OSS & Pro |
| 🔍 **Detalles de Red** | Generación PHY, ancho de canal, roaming 802.11k/r/v, WPA3, SSID oculto | OSS & Pro |
| 📶 **Información de Conexión** | IP, gateway, DNS, MAC, canal, tasa Tx y resumen de seguridad | OSS & Pro |
| 🩺 **Autodiagnóstico de red** | Diagnóstico de conexión con un clic — ruta, DNS, HTTPS y accesibilidad del proxy, con conclusiones basadas en evidencia | OSS & Pro |
| 📈 **Línea temporal de eventos** | Historial de eventos de conexión — roaming, cambios de canal, desconexiones y caídas de señal | Solo Pro |
| 🔄 **Prueba de Roaming** | Monitoreo de transición AP con gráfico temporal, selector de rango y guardado/carga de sesión | OSS & Pro |
| 🗺️ **Mapa de Calor del Canal** | Mapa de calor de ocupación por banda para identificar patrones de congestión al instante | OSS & Pro |
| 🎬 **Grabación de espectro** | Captura y reproduce cambios del espectro a lo largo del tiempo | Solo Pro |
| 🎧 **Escáner BLE** | Descubrimiento de dispositivos Bluetooth LE, análisis RSSI, gráficos de tendencias y seguimiento de dispositivos | OSS & Pro |
| 🎨 **Colores Inteligentes** | Asignación de color determinista basada en el SSID; la misma red conserva el mismo color | OSS & Pro |
| 📍 **Barra de menús** | Vive en tu barra de menús — haz clic en el icono para abrir el analizador en cualquier momento | Solo Pro |
| 🔒 **Privacidad Primero** | Sin telemetría ni analítica; los datos de escaneo Wi-Fi permanecen en tu Mac | OSS & Pro |
| 🌐 **Servidor MCP** | API HTTP embebida en `127.0.0.1:19840` para integración con herramientas externas | OSS & Pro |
| 🔄 **Actualizaciones Automáticas** | Actualizaciones Sparkle en la edición de GitHub; actualizaciones de Mac App Store en Pro | OSS & Pro |
| 📤 **Exportar** | Guarda gráficos por banda como imágenes PNG o datos CSV | OSS & Pro |
| 🌍 **Localizado** | Inglés, alemán, español, japonés y chino simplificado | OSS & Pro |

Todas las funciones están incluidas en la edición de código abierto, salvo las marcadas **Solo Pro**. Pro incluye todas las funciones de código abierto más las herramientas de grabación, barra de menús y línea temporal de eventos.

---

## Diseño

**Interfaz nativa de macOS.** CoreWLAN se comunica directamente con el hardware Wi-Fi. SwiftUI proporciona controles y comportamiento de ventanas propios de macOS.

**Recomendaciones con contexto regulatorio.** WiFi Lens determina el dominio regulatorio mediante la región del sistema, las capacidades del hardware y los códigos de país de puntos de acceso cercanos. La aplicación filtra las recomendaciones según los requisitos DFS, de uso en interiores y AFC de 6 GHz.

**Vistas vinculadas.** Selecciona una red en la tabla para resaltarla en cada gráfico. Pasa el cursor sobre una curva de campana para identificar su SSID.

**Herramientas de la edición de código abierto.** Exporta archivos PNG y CSV o guarda y carga sesiones de roaming. El servidor MCP local conecta WiFi Lens con tus propias herramientas.

---

## Descargar

Requiere **macOS 14 (Sonoma) o posterior**. Funciona en Macs Intel y Apple Silicon. El escaneo de la banda de 6 GHz requiere hardware Wi-Fi 6E/7.

- **Edición de código abierto** — [GitHub Releases](https://github.com/SHIINASAMA/wifi-lens/releases/latest) (gratuita, con comprobaciones opcionales mediante Sparkle)
- **WiFi Lens Pro** — [Mac App Store](https://apps.apple.com/app/wifi-lens-pro/id6776590746) (regiones compatibles)

> [!IMPORTANT]
> En macOS 14 o posterior, los **Servicios de localización** deben estar activados para que la app lea los nombres SSID Wi-Fi.
> Ve a **Ajustes del Sistema → Privacidad y seguridad → Localización** y activa WiFi Lens cuando se solicite.

> 🌐 **Sitio web oficial:** [wifi-lens.shiinalabs.com](https://wifi-lens.shiinalabs.com) ofrece capturas de pantalla, una guía de funciones, flujos de trabajo de IA/MCP y preguntas frecuentes.

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

Consulta las [pautas de contribución](.github/CONTRIBUTING.md) para la configuración de desarrollo, convenciones de pull requests y requisitos de localización. Si usas agentes de programación, consulta también las directrices de [.agents/references/collaboration-rules.md](.agents/references/collaboration-rules.md).

El mantenedor puede reconocer contribuciones sustanciales a WiFi Lens con un código promocional de WiFi Lens Pro emitido por Apple. Consulta [Reconocimiento de contribuyentes](.github/CONTRIBUTING.md#contributor-recognition) para más detalles.

**Contacto:** [@WiFiLens en X](https://x.com/WiFiLens) · [wifi-lens@shiinalabs.com](mailto:wifi-lens@shiinalabs.com)

---

## Agradecimientos

Este proyecto comenzó como una bifurcación de [tiny-wifi-analyzer](https://github.com/nolze/tiny-wifi-analyzer), creado por [nolze](https://github.com/nolze), autor del escáner Wi-Fi original basado en Python. Desde entonces, la app se ha reescrito por completo en Swift con SwiftUI y CoreWLAN y ha evolucionado hasta convertirse en una aplicación nativa de macOS.

---

## Licencia

Apache License 2.0 © 2020 nolze, 2026 SHIINASAMA. Ver [LICENSE](LICENSE) para texto completo.
