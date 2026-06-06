export const es = {
  nav: {
    features: 'Funciones',
    mcp: 'MCP',
    download: 'Descargar',
    privacy: 'Privacidad',
    docs: 'Documentación',
  },
  hero: {
    badge: 'macOS 14+ · Nativo · Local-first',
    title: 'WiFi Lens',
    subtitle: 'Un analizador de Wi‑Fi nativo para macOS que te ayuda a detectar congestión, diagnosticar calidad de conexión y verificar comportamiento de roaming en tiempo real.',
    cta: {
      oss: 'Descargar Gratis',
      secondary: 'Para flujos de trabajo con IA',
      proSoon: 'Mac App Store próximamente',
    },
    hint: 'Local-first · Open source · Sin tracking',
  },
  features: {
    title: 'Visión profunda de tu entorno inalámbrico',
    scanning: {
      title: 'Escaneo Tri-Banda en Espectro',
      desc: 'Observa redes 2.4 GHz, 5 GHz y 6 GHz cercanas actualizarse en tiempo real. Haz zoom, congela y compara superposición de canales sin perder la visión general.',
    },
    table: {
      title: 'Tabla de Red Completa',
      desc: 'Inspecciona RSSI, canal, banda, seguridad, proveedor y capacidades para cada red visible. Ordena, filtra y cruza filas con la vista de espectro mientras investigas.',
    },
    roaming: {
      title: 'Prueba de Roaming con Línea Temporal',
      desc: 'Rastrea cambios de punto de acceso al moverte por un espacio. Revisa transiciones, cambios de señal y sesiones guardadas para confirmar comportamiento de roaming.',
    },
    quality: {
      title: 'Puntuación de Calidad del Canal',
      desc: 'Encuentra canales más limpios en todas las bandas Wi‑Fi de un vistazo. Puntuaciones, niveles y recomendaciones te ayudan a decidir dónde moverte después.',
    },
    overview: {
      title: 'Panel de Diagnóstico de Conexión',
      desc: 'Comienza con la conexión que estás usando ahora mismo. WiFi Lens resalta salud de señal, calidad del canal, seguridad y la causa más probable del problema.',
    },
    privacy: {
      title: 'Privado por Defecto',
      desc: 'Sin analytics, sin telemetría y sin dependencia de la nube. Tus escaneos se quedan en tu Mac, e incluso el acceso MCP permanece local a tu máquina.',
    },
  },
  demo: {
    title: 'Mira la app en acción',
    subtitle: 'Seis vistas enfocadas para solucionar problemas de rendimiento Wi‑Fi, cobertura y uso de canales.',
    items: [
      {
        title: 'Panel de Diagnóstico',
        alt: 'Panel de diagnóstico mostrando salud actual de Wi-Fi, intensidad de señal y recomendaciones de canal',
        desc: 'Comienza revisando la salud de tu conexión actual. El panel destaca intensidad de señal, calidad del canal, seguridad y el siguiente paso más útil.',
        bullets: ['Salud de conexión actual de un vistazo', 'Recomendaciones de canal accionables', 'Ve qué banda está más ocupada'],
        image: '/screenshots/overview.png',
      },
      {
        title: 'Escáner de Espectro',
        alt: 'Escáner de espectro tri-banda mostrando curvas de red y ocupación de canales en bandas Wi-Fi',
        desc: 'Observa cómo las redes cercanas aparecen en gráficos de espectro en vivo en todas las principales bandas Wi‑Fi. Úsalo para detectar rápidamente superposición, congestión y grupos de canales ruidosos.',
        bullets: ['Vista de espectro tri-banda en vivo', 'Detecta canales congestionados rápidamente', 'Zoom, congela e inspecciona detalles'],
        image: '/screenshots/spectrum.png',
      },
      {
        title: 'Analizador de Calidad de Canal',
        alt: 'Analizador de calidad de canal con puntuación regional, detección DFS y filtrado de compatibilidad de dispositivos',
        desc: 'Compara puntuaciones de canales antes de cambiar la configuración de tu red. WiFi Lens muestra opciones más limpias con filtrado regional, contexto de superposición y verificación de compatibilidad de dispositivos.',
        bullets: ['Puntuaciones de calidad por canal', 'Recomendaciones basadas en región', 'Sugerencias de canales más limpios'],
        image: '/screenshots/channels.png',
      },
      {
        title: 'Tabla de Red Completa',
        alt: 'Tabla de red ordenable con detalles Wi-Fi incluyendo RSSI, canal, seguridad, proveedor y capacidades',
        desc: 'Explora la lista completa de redes visibles con una tabla nativa y densa. Cada fila expone intensidad de señal, canal, banda, tipo de seguridad, OUI del proveedor y capacidades 802.11.',
        bullets: ['RSSI, canal, banda y tipo de seguridad', 'OUI del proveedor y flags de capacidad', 'Filtra rápidamente por SSID o BSSID'],
        image: '/screenshots/table.png',
      },
      {
        title: 'Prueba de Roaming',
        alt: 'Línea temporal de prueba de roaming mostrando transiciones de punto de acceso, historial de señal y detalles de handoff',
        desc: 'Valida el comportamiento de roaming mientras caminas por un espacio con un portátil. Revisa handoffs, historial de señal y sesiones guardadas para entender cómo los clientes se mueven entre APs.',
        bullets: ['Detecta transiciones de AP en el tiempo', 'Visualiza caídas de señal durante el movimiento', 'Guarda y recarga sesiones de roaming'],
        image: '/screenshots/roaming.png',
      },
      {
        title: 'Interfaces de Red',
        alt: 'Vista de interfaces de red mostrando detalles de conexión y monitorización de throughput en vivo',
        desc: 'Inspecciona interfaces Wi‑Fi y no-Wi‑Fi desde un solo lugar. Cambia entre estado de alto nivel, información detallada de enlace y monitorización de throughput en vivo.',
        bullets: ['Cambia entre estado rápido y detalle profundo', 'Observa throughput en vivo a lo largo del tiempo', 'Inspecciona Wi‑Fi, Ethernet, VPN y enlaces virtuales'],
        image: '/screenshots/interfaces.png',
      },
    ],
  },
  specs: {
    title: 'Lo que lo hace útil',
    items: [
      { label: 'Escaneo en vivo', value: 'Actualizaciones en tiempo real a través de 2.4, 5 y 6 GHz — elige cualquier intervalo de 1 a 10 segundos' },
      { label: 'Gráficos de espectro', value: 'Visualizaciones suaves y responsivas que hacen fácil detectar superposición y congestión de canales' },
      { label: 'Exportar', value: 'Guarda capturas del espectro como PNG de alta resolución o exporta datos de red como hojas de cálculo CSV' },
      { label: 'Integración con IA', value: 'Deja que herramientas de IA compatibles inspeccionen tu entorno Wi‑Fi local sin enviar datos a la nube' },
      { label: 'Puntuación de canales', value: 'Recomendaciones inteligentes que ponderan intensidad de señal, superposición y ancho de banda juntos' },
      { label: 'Guardado de sesión', value: 'Guarda pruebas de roaming y reábrelos después para comparar resultados antes y después' },
    ],
  },
  mcp: {
    title: 'Deja que la IA inspeccione tu entorno Wi‑Fi local',
    subtitle: 'WiFi Lens puede exponer datos de escaneo en vivo a herramientas como Claude Desktop sobre MCP, así puedes hacer preguntas sobre redes cercanas y uso de canales sin enviar datos a la nube.',
    endpoints: {
      title: 'Tres endpoints JSON',
      networks: 'Navega por redes cercanas con señal, banda, canal, seguridad y detalles de capacidades.',
      detail: 'Inspecciona una red en profundidad por BSSID, incluyendo información de ancho de canal.',
      occupancy: 'Verifica ocupación por canal para entender congestión a través de cada banda Wi‑Fi.',
    },
    config: {
      title: 'Una configuración para conectar',
      desc: 'Habilita el servidor MCP en WiFi Lens, añade esta configuración en Claude Desktop, luego haz preguntas como "¿Qué canal parece menos congestionado?" o "¿Qué destaca en redes cercanas?"',
    },
    cta: {
      docs: 'Leer la documentación',
      github: 'Ver en GitHub',
    },
  },
  download: {
    title: 'Empieza con WiFi Lens',
    oss: {
      title: 'WiFi Lens OSS',
      badge: 'Gratis & Open Source',
      desc: 'Descarga la última versión desde GitHub Releases, lista para ejecutar en macOS 14 o posterior.',
      features: [
        'Escaneo tri-band en espectro en vivo',
        'Tabla de red detallada y filtrado',
        'Puntuación de calidad del canal y recomendaciones',
        'Análisis de línea temporal de roaming',
        'Panel de diagnóstico de conexión',
        'Servidor MCP local para flujos de trabajo con IA',
      ],
      cta: 'Descargar desde GitHub',
      url: 'https://github.com/SHIINASAMA/wifi-lens/releases/latest',
    },
    pro: {
      title: 'WiFi Lens PRO',
      badge: 'Planeado para Mac App Store',
      desc: 'Una futura versión de Mac App Store está planeada para personas que quieren un camino de instalación más simple.',
      features: [
        'Misma experiencia de analizador central',
        'Flujo de instalación más simple',
        'Distribución Mac App Store cuando esté disponible',
      ],
      cta: 'Planeado',
    },
  },
  privacy: {
    title: 'Tus datos se quedan en tu Mac. Siempre.',
    subtitle: 'WiFi Lens procesa todo localmente. Sin cuentas, sin nube, sin tracking.',
    noCollection: {
      heading: 'Sin Recolección de Datos Personales',
      body: 'WiFi Lens no recopila, almacena o transmite ninguna información personalmente identificable. La app no contiene cuentas de usuario, SDKs de analytics, redes publicitarias ni frameworks de telemetría. No operamos servidores backend para recibir tus datos — porque no tenemos interés en tenerlos.',
    },
    permissions: {
      heading: 'Por Qué Solicitamos Permisos',
      body: 'Wi‑Fi — Funcionalidad central: escaneo y análisis de redes inalámbricas cercanas.\n\nBluetooth — Opcionalmente usado para descubrir dispositivos BLE cercanos para análisis de coexistencia. Esta característica está deshabilitada por defecto y puede habilitarse en Ajustes. Todo el descubrimiento se ejecuta localmente en tu máquina.\n\nServicios de Ubicación — macOS requiere este permiso para cualquier app que lea nombres de red Wi‑Fi (SSIDs). WiFi Lens nunca accede a tus coordenadas GPS y nunca registra tu ubicación.\n\nRed Local — Opcionalmente usado cuando habilitas el servidor MCP en Ajustes. El servidor escucha solo en localhost (127.0.0.1) para que herramientas locales como Claude Desktop puedan leer datos de escaneo Wi‑Fi. Está desactivado por defecto, y ningún dato sale de tu Mac.',
    },
    localOnly: {
      heading: 'Todo se Queda en Tu Máquina',
      body: 'Todos los resultados de escaneo Wi‑Fi, datos de descubrimiento Bluetooth, recomendaciones de canal y detección de región regulatoria se ejecutan completamente en el dispositivo. Ningún dato de escaneo se sube nunca a un servidor remoto.\n\nLos informes de fallos y registros de diagnóstico se escriben en archivos en tu propio disco. Nada se transmite a menos que elijas explícitamente compartirlo.\n\nEl servidor MCP se vincula a 127.0.0.1 (solo localhost). Ningún dato de escaneo sale de tu máquina a través de MCP a menos que deliberadamente lo enrutes a otro lugar.',
    },
    distribution: {
      heading: 'Diferencias de Distribución',
      body: 'WiFi Lens está disponible a través de dos canales. Solo difieren en cómo se verifican las actualizaciones:\n\nMac App Store — Usa el mecanismo de actualización integrado de Apple. La app nunca contacta ningún servidor de terceros para verificaciones de versión o actualizaciones.\n\nGitHub / Descarga Directa — Usa el framework Sparkle para verificar nuevas versiones. Sparkle busca un único archivo appcast (un descriptor de versión) desde nuestro servidor de lanzamientos. Esta solicitud no transmite datos personales, análisis de uso ni información de diagnóstico — es puramente una comparación de versión.',
    },
    openSource: {
      heading: 'Open Source & Verificable',
      body: 'El código fuente completo está disponible bajo la licencia Apache 2.0. Cada afirmación en esta página puede ser verificada independientemente por cualquiera que lea el código.',
    },
    lastUpdated: 'Última actualización: 27 de mayo de 2026',
    contact: '¿Preguntas? Abre un GitHub Issue o contáctanos en wifi-lens@outlook.com',
  },
  footer: {
    copyright: '© 2026 WiFi Lens. Entiende tu Wi‑Fi.',
    x: '@WiFiLens',
    email: 'wifi-lens@outlook.com',
    privacy: 'Privacidad',
    support: 'Soporte',
    oss: 'GitHub',
    license: 'Apache 2.0',
  },
} as const
