export const es = {
  a11y: {
    skipLink: 'Saltar al contenido principal',
    menu: 'Menú',
    backToTop: 'Volver arriba',
    selectLanguage: 'Seleccionar idioma',
  },
  meta: {
    title: 'WiFi Lens — Analizador de Espectro Wi‑Fi para macOS',
    description: 'WiFi Lens — Un analizador de espectro Wi‑Fi nativo para macOS. Escanea, diagnostica y navega con confianza.',
  },
  nav: {
    home: 'Inicio',
    features: 'Funciones',
    mcp: 'AI Workflows',
    download: 'Descargar',
    changelog: 'Registro de cambios',
    faq: 'FAQ',
    privacy: 'Privacidad',
    docs: 'Documentación',
  },
  hero: {
    badge: 'macOS 14+ · Nativo · Local-first',
    title: 'WiFi Lens',
    subtitle: 'Un analizador de Wi‑Fi nativo para macOS que te ayuda a ver dónde falla tu Wi‑Fi, si los canales están saturados y si tus dispositivos roaming funcionan correctamente.',
    cta: {
      oss: 'Descargar',
      secondary: 'Flujos de trabajo con IA',
      proSoon: 'Mac App Store ya disponible',
    },
    hint: 'Local-first · Open source · Sin tracking',
    tagline: 'Visibilidad Wi‑Fi nativa para macOS.',
  },
  stats: [
    { value: 'Todas las bandas', label: '2.4/5/6 GHz' },
    { value: 'En tiempo real', label: 'Escaneo' },
    { value: 'macOS', label: 'App Nativa' },
    { value: 'Totalmente', label: 'Local & Offline' },
  ],
  features: {
    title: 'Visión profunda de tu entorno inalámbrico',
    scanning: {
      title: 'Escaneo Tri-Banda en Espectro',
      desc: 'Ve todas las redes Wi‑Fi cercanas en 2.4 GHz, 5 GHz y 6 GHz. Haz zoom, pausa y encuentra los canales más saturados al instante.',
    },
    table: {
      title: 'Tabla de Red Completa',
      desc: 'Enumera todas las redes Wi‑Fi cercanas en una tabla — intensidad de señal, canal, tipo de seguridad y fabricante de un vistazo. Filtra rápido para encontrar problemas.',
    },
    roaming: {
      title: 'Prueba de Roaming con Línea Temporal',
      desc: 'Camina por tu casa y observa dónde se debilita la señal Wi‑Fi y cuándo tu dispositivo cambia de Router. Guarda sesiones para revisar los cambios después.',
    },
    quality: {
      title: 'Puntuación de Calidad del Canal',
      desc: 'Puntúa tus canales Wi‑Fi. Cuál es el más limpio y con menos interferencias — las puntuaciones y recomendaciones te ayudan a elegir el mejor.',
    },
    overview: {
      title: 'Panel de Diagnóstico de Conexión',
      desc: 'Empieza por la red que estás usando ahora. WiFi Lens comprueba la calidad de la señal, la saturación del canal y la configuración de seguridad, y da sugerencias claras de mejora.',
    },
    privacy: {
      title: 'Privado por Defecto',
      desc: 'No recopila privacidad, no sube a la nube. Todos los datos se procesan localmente en tu Mac — incluso las funciones de IA solo acceden a tu máquina local.',
    },
  },
  demo: {
    title: 'Mira la app en acción',
    subtitle: 'Vistas enfocadas para solucionar problemas de rendimiento Wi‑Fi, cobertura y uso de canales.',
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
        desc: 'Ve la actividad en vivo de las redes cercanas en todas las bandas Wi‑Fi. Descubre rápidamente dónde hay más actividad y qué canales están saturados.',
        bullets: ['Vista de espectro tri-banda en vivo', 'Detecta canales congestionados rápidamente', 'Zoom, congela e inspecciona detalles'],
        image: '/screenshots/spectrum.png',
      },
      {
        title: 'Analizador de Calidad de Canal',
        alt: 'Analizador de calidad de canal con puntuación regional, detección DFS y filtrado de compatibilidad de dispositivos',
        desc: 'Compara las puntuaciones de los canales antes de cambiar la configuración de tu Router. WiFi Lens sugiere opciones más adecuadas según tu región y entorno, y comprueba la compatibilidad de dispositivos.',
        bullets: ['Puntuaciones de calidad por canal', 'Recomendaciones basadas en región', 'Sugerencias de canales más limpios'],
        image: '/screenshots/channels.png',
      },
      {
        title: 'Tabla de Red Completa',
        alt: 'Tabla de red ordenable con detalles Wi-Fi incluyendo RSSI, canal, seguridad, proveedor y capacidades',
        desc: 'Profundiza en la lista completa de redes visibles con parámetros detallados. Cada fila muestra intensidad de señal, canal, banda, tipo de seguridad y fabricante — para quienes necesitan un análisis más avanzado.',
        bullets: ['Intensidad de señal, canal, banda, tipo de seguridad', 'Fabricante e indicadores de capacidad', 'Filtra rápido por nombre de red o dirección de dispositivo'],
        image: '/screenshots/table.png',
      },
      {
        title: 'Prueba de Roaming',
        alt: 'Línea temporal de prueba de roaming mostrando transiciones de punto de acceso, historial de señal y detalles de handoff',
        desc: 'Camina con tu portátil por casa y verifica cómo tus dispositivos cambian entre puntos de acceso. Revisa handoffs, historial de señal y sesiones guardadas para entender la cobertura Wi‑Fi real.',
        bullets: ['Ve cuándo los dispositivos cambian a otro AP', 'Observa cambios de señal mientras te mueves', 'Guarda y reproduce sesiones de roaming'],
        image: '/screenshots/roaming.png',
      },
      {
        title: 'Interfaces de Red',
        alt: 'Vista de interfaces de red mostrando detalles de conexión y monitorización de throughput en vivo',
        desc: 'Todas tus interfaces de red en un solo lugar — Wi‑Fi, cable, VPN y más. Consulta información detallada del enlace y monitoriza la velocidad en tiempo real.',
        bullets: ['Cambia entre estado rápido y detalle profundo con un clic', 'Monitoriza velocidad en tiempo real', 'Muestra Wi‑Fi, Ethernet, VPN y más'],
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
    title: 'Pregunta sobre tu Wi‑Fi como en una charla',
    subtitle: 'WiFi Lens puede exponer datos de escaneo en vivo a herramientas como Claude Desktop sobre MCP, así puedes hacer preguntas sobre redes cercanas y uso de canales sin enviar datos a la nube.',
    metaDescription: 'Conecta WiFi Lens a herramientas de IA mediante MCP. Claude Desktop lee datos de escaneo Wi‑Fi locales — redes, canales y ocupación — sin subir nada.',
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
    subtitle: 'Elige la versión que se adapte a tus necesidades. Ambas comparten las mismas capacidades básicas de análisis Wi‑Fi.',
    metaDescription: 'Descarga WiFi Lens para macOS 14+. Versión open-source gratis en GitHub o versión Pro en la Mac App Store con grabación de espectro.',
    oss: {
      title: 'WiFi Lens OSS',
      badge: 'Gratis & Open Source',
      desc: 'Descarga la última versión desde GitHub Releases, lista para ejecutar en macOS 14 o posterior.',
      cta: 'Descargar desde GitHub',
      url: 'https://github.com/SHIINASAMA/wifi-lens/releases/latest',
    },
    pro: {
      title: 'Apoyar WiFi Lens',
      badge: 'Patrocinio & Actualización',
      desc: 'WiFi Lens es mantenido principalmente por un desarrollador independiente. Al comprar la versión Pro en la App Store, apoyas la mejora continua y desbloqueas funciones avanzadas como la grabación de sesiones de espectro.',
      cta: 'Descargar en el Mac App Store',
      url: 'https://apps.apple.com/app/id6776590746',
    },
    comparison: {
      rows: [
        { feature: 'Escaneo tri-band en espectro en vivo', oss: true, pro: true },
        { feature: 'Tabla de red detallada y filtrado', oss: true, pro: true },
        { feature: 'Puntuación de calidad del canal y recomendaciones', oss: true, pro: true },
        { feature: 'Análisis de línea temporal de roaming', oss: true, pro: true },
        { feature: 'Panel de diagnóstico de conexión', oss: true, pro: true },
        { feature: 'Servidor MCP local para flujos de trabajo con IA', oss: true, pro: true },
        { feature: 'Grabación y reproducción de sesiones del espectro', oss: false, pro: true },
        { feature: 'Comparación lado a lado del espectro entre períodos', oss: false, pro: true },
        { feature: 'Exportar grabaciones para análisis sin conexión', oss: false, pro: true },
        { feature: 'Instalación sencilla con actualizaciones automáticas', oss: false, pro: true },
        { feature: 'Apoya el mantenimiento continuo del desarrollador independiente', oss: false, pro: true },
      ],
    },
  },
  changelog: {
    title: 'Registro de cambios',
    subtitle: 'Un historial de cambios, mejoras y correcciones en WiFi Lens.',
    metaDescription: 'Historial de versiones de WiFi Lens — nuevas funciones como integración MCP y grabación de espectro, correcciones y mejoras.',
    categories: {
      added: 'Añadido',
      improved: 'Mejorado',
      fixed: 'Corregido',
      changed: 'Cambiado',
    },
    releases: [
      {
        version: 'v1.4.3',
        date: '2026-06-29',
        sections: [
          { type: 'improved' as const, items: ['Versión OSS alineada con la versión actual de App Store', 'Refinamientos de UI y actualizaciones de comportamiento'] },
          { type: 'fixed' as const, items: ['Correcciones menores y mejoras de estabilidad'] },
        ],
      },
      {
        version: 'v1.4.2',
        date: '2026-06-21',
        sections: [
          { type: 'added' as const, items: ['Recomendación contrafactual de canal', 'Enlace al Mac App Store en la app'] },
          { type: 'improved' as const, items: ['Gráfico de depuración de espectro dividido en navegación separada', 'Navegación secundaria movida a la barra de herramientas de la ventana'] },
          { type: 'fixed' as const, items: ['Renderizado de anotaciones en gráficos', 'Detección de límites de secciones de espectro'] },
        ],
      },
      {
        version: 'v1.4.1',
        date: '2026-06-14',
        sections: [
          { type: 'improved' as const, items: ['Mejoras de accesibilidad para preparación del App Store'] },
        ],
      },
      {
        version: 'v1.4.0',
        date: '2026-06-05',
        sections: [
          { type: 'added' as const, items: ['Grabación y reproducción de sesiones de espectro', 'Comparación lado a lado del espectro entre períodos'] },
          { type: 'improved' as const, items: ['UI y controles del analizador de espectro'] },
        ],
      },
      {
        version: 'v1.3.0',
        date: '2026-05-28',
        sections: [
          { type: 'added' as const, items: ['Servidor MCP para integración con herramientas de IA', 'Endpoints JSON locales para datos de red, detalle y ocupación'] },
          { type: 'improved' as const, items: ['Algoritmo de puntuación de calidad de canal'] },
        ],
      },
      {
        version: 'v1.2.0',
        date: '2026-05-24',
        sections: [
          { type: 'added' as const, items: ['Prueba de roaming con visualización de línea de tiempo', 'Guardado y reproducción de sesiones de prueba de roaming'] },
          { type: 'improved' as const, items: ['Ordenamiento y filtrado de la tabla de redes'] },
        ],
      },
      {
        version: 'v1.1.0',
        date: '2026-05-20',
        sections: [
          { type: 'added' as const, items: ['Panel de diagnóstico de conexión', 'Puntuación y recomendaciones de calidad de canal'] },
          { type: 'improved' as const, items: ['Rendimiento del escáner de espectro tri-band'] },
        ],
      },
      {
        version: 'v1.0.0',
        date: '2026-05-18',
        sections: [
          { type: 'added' as const, items: ['Escaneo de espectro tri-band (2.4 / 5 / 6 GHz)', 'Tabla de redes detallada con filtrado', 'Exportación de capturas de espectro en alta resolución', 'Exportación CSV de datos de red'] },
        ],
      },
    ],
  },
  faq: {
    title: 'Preguntas frecuentes',
    metaDescription: 'Preguntas frecuentes sobre WiFi Lens — precios, requisitos de macOS, privacidad de datos, diferencias entre Pro y OSS, compatibilidad con 6 GHz.',
    items: [
      { q: '¿Es WiFi Lens gratis?', a: 'Absolutamente. WiFi Lens OSS es de código abierto y completamente gratuito — puedes descargarlo y usarlo desde GitHub sin restricciones. La versión Pro es un patrocinio único a través de la App Store que desbloquea algunas funciones avanzadas relacionadas con la grabación. Las capacidades principales de análisis Wi‑Fi son idénticas en ambas versiones.' },
      { q: '¿Cuál es la diferencia entre Pro y OSS?', a: 'La versión OSS cubre todas las funciones principales: escaneo de espectro, tabla de redes, puntuación de canales, pruebas de roaming e integración MCP con IA. La versión Pro añade grabación de sesiones de espectro (capturar y reproducir cambios en el espectro a lo largo del tiempo) y comparación lado a lado del espectro entre períodos. Si no necesitas grabación y reproducción, la versión OSS tiene todo lo que necesitas.' },
      { q: '¿Se suben mis datos a la nube?', a: 'Absolutamente no. WiFi Lens no tiene servidores backend de ningún tipo. Todos los datos se procesan localmente en tu Mac. Incluso la integración MCP con IA solo se comunica a través de la interfaz local de tu máquina — nada se envía a ningún servidor remoto. Para ser claros: no recopilamos nada.' },
      { q: '¿Qué versión de macOS necesito?', a: 'WiFi Lens requiere macOS 14 (Sonoma) o posterior. Es compatible con Macs Apple Silicon e Intel. Una nota rápida: el escaneo de la banda de 6 GHz requiere que tu hardware Mac soporte Wi‑Fi 6E o Wi‑Fi 7 (disponible en modelos Apple Silicon más recientes). Los Macs Intel más antiguos o modelos sin 6E pueden usar todas las funciones de 2.4 GHz y 5 GHz sin limitación.' },
      { q: '¿Por qué algunas redes de 6 GHz no muestran la etiqueta 6 GHz?', a: 'Esta es una limitación a nivel del sistema macOS. Las APIs de escaneo inalámbrico que macOS proporciona a las aplicaciones no siempre marcan explícitamente una red como perteneciente a la banda de 6 GHz. Para redes Wi‑Fi 6E, el sistema típicamente codifica la información de banda a través del número de canal o la frecuencia central en lugar de devolver una etiqueta "6 GHz" directamente. Como resultado, algunas redes de 6 GHz pueden aparecer como 5 GHz o sin una etiqueta de banda específica en los resultados del escaneo. Esto es comportamiento del sistema, no un error — no significa que el dispositivo no esté usando una red de 6 GHz.' },
      { q: '¿Funciona en Windows o Linux?', a: 'WiFi Lens es una aplicación nativa de macOS y no es compatible con Windows o Linux. Depende del framework CoreWLAN de macOS para leer datos Wi‑Fi, y no existe un framework equivalente en otros sistemas operativos.' },
      { q: '¿Por qué pide permiso de ubicación?', a: 'No es un requisito nuestro — es una política de macOS. Apple exige que cualquier aplicación capaz de leer nombres de redes Wi‑Fi (SSIDs) debe obtener permiso de ubicación. WiFi Lens nunca accede a tus coordenadas GPS y nunca registra tu ubicación.' },
    ],
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
      body: 'Wi‑Fi — Funcionalidad central: escaneo y análisis de redes inalámbricas cercanas.\n\nBluetooth — Opcional: descubre dispositivos Bluetooth cercanos para análisis de coexistencia. Desactivado por defecto, se puede activar en Ajustes. Esta característica está deshabilitada por defecto y puede habilitarse en Ajustes. Todo el descubrimiento se ejecuta localmente en tu máquina.\n\nServicios de Ubicación — macOS requiere este permiso para cualquier app que lea nombres de red Wi‑Fi (SSIDs). WiFi Lens nunca accede a tus coordenadas GPS y nunca registra tu ubicación.\n\nRed Local — Opcionalmente usado cuando habilitas el servidor MCP en Ajustes. El servidor escucha solo en localhost (127.0.0.1) para que herramientas locales como Claude Desktop puedan leer datos de escaneo Wi‑Fi. Está desactivado por defecto, y ningún dato sale de tu Mac.',
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
  home: {
    exploreFeatures: 'Explorar funciones',
    featuresTitle: 'Una página de inicio más limpia. Una historia de producto más clara.',
    featuresSub: 'Empieza por el producto en sí, y profundiza solo donde lo necesites.',
    exploreLabel: 'Explorar',
    exploreTitle: 'Empieza en la página que responde tu pregunta',
    exploreSub: 'Mantén la homepage corta. Usa las páginas profundas cuando necesites detalles.',
    viewPage: 'Ver página',
  },
  notFound: {
    title: '404 — Página no encontrada',
    heading: 'Esta página no existe.',
    desc: 'La página que buscas puede haber sido movida o ya no existe.',
    backHome: 'Volver al inicio',
  },
  footer: {
    copyright: '© 2026 WiFi Lens — Comprende a fondo tu Wi‑Fi.',
    x: '@WiFiLens',
    email: 'wifi-lens@outlook.com',
    privacy: 'Privacidad',
    support: 'Soporte',
    oss: 'GitHub',
    license: 'Apache 2.0',
  },
} as const
