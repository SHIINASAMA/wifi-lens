export const zhHans = {
  a11y: {
    skipLink: '跳到主内容',
    menu: '菜单',
    backToTop: '回到顶部',
    selectLanguage: '选择语言',
  },
  meta: {
    title: 'WiFi Lens — macOS Wi‑Fi 频谱分析仪',
    description: 'WiFi Lens — 一款 macOS 原生 Wi‑Fi 频谱分析工具，扫描、诊断、自信漫游。',
  },
  nav: {
    home: '首页',
    features: '功能',
    mcp: 'AI 工作流',
    download: '下载',
    changelog: '更新日志',
    faq: '常见问题',
    privacy: '隐私说明',
    docs: '文档',
  },
  hero: {
    badge: 'macOS 14+  ·  原生  ·  本地优先',
    title: 'WiFi Lens',
    subtitle: '一款 macOS 原生 Wi‑Fi 分析工具，帮你看看家里的 Wi‑Fi 哪里出了问题、附近信道是否拥挤、设备漫游是否正常。',
    cta: {
      oss: '下载',
      secondary: 'AI 工作流',
      proSoon: 'Mac App Store 已上线',
    },
    hint: '本地优先  ·  开源  ·  无追踪',
    tagline: 'macOS 原生 Wi‑Fi 可视化工具。',
  },
  stats: [
    { value: '全频段', label: '2.4/5/6 GHz' },
    { value: '实时', label: '频谱扫描' },
    { value: 'macOS', label: '原生应用' },
    { value: '完全', label: '本地离线' },
  ],
  features: {
    title: '深度洞察你的无线环境',
    scanning: {
      title: '三频频谱扫描',
      desc: '看看附近都有谁的 Wi‑Fi，覆盖 2.4GHz / 5GHz / 6GHz 三个频段。支持放大缩小、暂停观察，一眼就能找到最拥挤的信道。',
    },
    table: {
      title: '详细的网络列表',
      desc: '把周围所有 Wi‑Fi 网络列成一张表——信号强度、使用的信道、安全类型、设备厂家，一目了然。快速筛选，更快找到问题。',
    },
    roaming: {
      title: '带时间线的漫游测试',
      desc: '在家里走一圈，看看 Wi‑Fi 信号在哪儿变弱、设备什么时候切换了路由器。保存记录，以后还能回看变化。',
    },
    quality: {
      title: '信道质量评分',
      desc: '给你的 Wi‑Fi 频道打个分。哪条信道最干净、干扰最少——评分和推荐帮你选出最好的那个。',
    },
    overview: {
      title: '连接诊断仪表盘',
      desc: '从你正在用的网络开始。WiFi Lens 告诉你信号好不好、信道是否拥堵、安全设置有没有问题，并给出明确的改善建议。',
    },
    privacy: {
      title: '默认隐私保护',
      desc: '不收集隐私、不上传云端。所有数据都在你的 Mac 上本地处理，即便是 AI 功能也只访问本机，数据绝不离线。',
    },
  },
  demo: {
    title: '查看应用实际操作',
    subtitle: '用于排查 Wi‑Fi 性能、覆盖范围和信道使用情况的专注视图。',
    items: [
      {
        title: '概览仪表盘',
        alt: '概览仪表盘，显示当前 Wi-Fi 健康状况、信号强度和信道推荐',
        desc: '首先检查当前连接的健康状况。概览页面会突出显示信号强度、信道质量、安全性以及最有用的下一步建议。',
        bullets: ['当前连接健康状况一览', '可操作的信道建议', '看看哪个频段最忙'],
        image: '/screenshots/overview.png',
      },
      {
        title: '频谱扫描器',
        alt: '三频频谱扫描器，显示各 Wi-Fi 频段的网络曲线和信道占用情况',
        desc: '看看附近网络在所有 Wi‑Fi 频段上的实时活动。用它快速发现哪儿最热闹、哪些信道堵得不行。',
        bullets: ['实时三频频谱视图', '一眼发现拥挤信道', '放大、暂停、查看细节'],
        image: '/screenshots/spectrum.png',
      },
      {
        title: '信道质量分析器',
        alt: '信道质量分析器，具备区域感知评分、DFS 检测和设备兼容性筛选功能',
        desc: '在改路由器设置之前，先比比哪个信道最干净。WiFi Lens 会根据你的地区和环境给出更合适的建议，还检查设备兼容性。',
        bullets: ['每条信道都有质量评分', '根据你所在地区推荐', '告诉你哪些信道更干净'],
        image: '/screenshots/channels.png',
      },
      {
        title: '详细网络表格',
        alt: '可排序的网络表格，包含 RSSI、信道、频段、安全性、厂商和能力等 Wi-Fi 详细信息',
        desc: '深入了解所有可见网络的详细参数。每行包含信号强度、信道、频段、安全类型和厂家信息，适合需要进阶排查的用户。',
        bullets: ['信号强度、信道、频段、安全类型', '设备厂家与能力标识', '按网络名称或设备地址快速筛选'],
        image: '/screenshots/table.png',
      },
      {
        title: '漫游测试',
        alt: '漫游测试时间线，显示接入点切换、信号历史和切换详情',
        desc: '拿着笔记本在家里走动，看看设备在路由器之间切换的表现。回顾切换记录、信号变化，了解 Wi‑Fi 覆盖的真实效果。',
        bullets: ['看设备何时切换到另一个 AP', '边走边看信号变化', '保存和回看漫游记录'],
        image: '/screenshots/roaming.png',
      },
      {
        title: '网络接口',
        alt: '网络接口视图，显示连接详情和实时吞吐量监控',
        desc: '一个页面查看所有网络接口——Wi‑Fi、有线、VPN 一应俱全。看看详细的链路信息，监控实时速度。',
        bullets: ['快速状态和深度详情一键切换', '实时监控网速', '查看 Wi‑Fi、以太网、VPN 等所有接口'],
        image: '/screenshots/interfaces.png',
      },
    ],
  },
  specs: {
    title: '为什么实用',
    items: [
      { label: '实时扫描', value: '2.4、5、6 GHz 全频段实时更新，扫描间隔可在 1 至 10 秒之间调整' },
      { label: '频谱图表', value: '流畅、灵敏的可视化效果，让信道重叠和拥塞一目了然' },
      { label: '数据导出', value: '将频谱截图保存为高分辨率 PNG，或将网络数据导出为 CSV 电子表格' },
      { label: 'AI 集成', value: '让兼容的 AI 工具检查你的本地 Wi‑Fi 环境，数据不会上传到云端' },
      { label: '信道评分', value: '综合信号强度、重叠程度和频段宽度的智能推荐' },
      { label: '会话保存', value: '保存漫游测试会话，随时重新打开对比前后变化' },
    ],
  },
  mcp: {
    title: '像聊天一样问 Wi‑Fi',
    subtitle: 'WiFi Lens 可以接入 MCP，让 Claude Desktop 等 AI 工具直接读取 Wi‑Fi 数据——数据不上传云端，全程在你电脑上完成。问问"哪个信道最不拥挤？"或"附近网络有什么值得注意的？"',
    metaDescription: '通过 MCP 将 WiFi Lens 连接到 AI 工具。让 Claude Desktop 读取本地 Wi‑Fi 扫描数据，无需上传任何内容。',
    endpoints: {
      title: '三个 JSON 端点',
      networks: '浏览附近所有 Wi‑Fi 网络，包含信号强度、频段、信道、安全性等信息。',
      detail: '按设备地址查看单个网络的详细信息，包含信道宽度等进阶数据。',
      occupancy: '检查每个信道的占用情况，了解各 Wi‑Fi 频段的拥塞程度。',
    },
    config: {
      title: '一个配置即可连接',
      desc: '在 WiFi Lens 中开启 MCP 服务器，把下面这段配置加到 Claude Desktop 里，然后就能直接跟 AI 聊你的 Wi‑Fi 环境了。',
    },
    cta: {
      docs: '阅读文档',
      github: '在 GitHub 上查看',
    },
  },
  download: {
    title: '开始使用 WiFi Lens',
    subtitle: '选择适合你的版本。两个版本共享相同的核心 Wi‑Fi 分析能力。',
    metaDescription: '下载 WiFi Lens，支持 macOS 14+。GitHub 免费开源版或 Mac App Store Pro 版，含频谱录制功能。',
    oss: {
      title: 'WiFi Lens OSS',
      badge: '免费 & 开源',
      desc: '从 GitHub Releases 下载最新版本，开箱即用，支持 macOS 14 及以上版本。',
      cta: '从 GitHub 下载',
      url: 'https://github.com/SHIINASAMA/wifi-lens/releases/latest',
    },
    pro: {
      title: '支持 WiFi Lens',
      badge: '赞助 & 体验升级',
      desc: 'WiFi Lens 是一个主要由个人开发维护的工具。通过 App Store 购买 Pro 版，既是支持我们继续改进，也解锁频谱会话录制等进阶功能。',
      cta: '在 Mac App Store 下载',
      url: 'https://apps.apple.com/app/id6776590746',
    },
    comparison: {
      rows: [
        { feature: '实时三频频谱扫描', oss: true, pro: true },
        { feature: '详细的网络表格和筛选', oss: true, pro: true },
        { feature: '信道质量评分和推荐', oss: true, pro: true },
        { feature: '漫游时间线分析', oss: true, pro: true },
        { feature: '连接诊断仪表盘', oss: true, pro: true },
        { feature: 'AI 工作流本地 MCP 服务器', oss: true, pro: true },
        { feature: '频谱会话录制与回放', oss: false, pro: true },
        { feature: '跨时间段的频谱并排比较', oss: false, pro: true },
        { feature: '导出录制数据用于离线分析', oss: false, pro: true },
        { feature: '方便的安装与自动更新', oss: false, pro: true },
        { feature: '支持独立开发者持续维护', oss: false, pro: true },
      ],
    },
  },
  changelog: {
    title: '更新日志',
    subtitle: 'WiFi Lens 的变更、改进与修复记录。',
    metaDescription: 'WiFi Lens 版本历史——查看每个版本的新功能、改进和修复，包括 MCP 集成和频谱录制等。',
    categories: {
      added: '新增',
      improved: '改进',
      fixed: '修复',
      changed: '变更',
    },
    releases: [
      {
        version: 'v1.4.3',
        date: '2026-06-29',
        sections: [
          { type: 'improved' as const, items: ['OSS 版本与当前 App Store 版本对齐', 'UI 细节优化和行为调整'] },
          { type: 'fixed' as const, items: ['若干小问题修复和稳定性改进'] },
        ],
      },
      {
        version: 'v1.4.2',
        date: '2026-06-21',
        sections: [
          { type: 'added' as const, items: ['反事实信道推荐', '应用内 Mac App Store 链接'] },
          { type: 'improved' as const, items: ['频谱调试图表拆分为独立导航', '辅助导航移至窗口工具栏'] },
          { type: 'fixed' as const, items: ['图表注释渲染', '频谱段边界检测'] },
        ],
      },
      {
        version: 'v1.4.1',
        date: '2026-06-14',
        sections: [
          { type: 'improved' as const, items: ['App Store 上架所需的无障碍改进'] },
        ],
      },
      {
        version: 'v1.4.0',
        date: '2026-06-05',
        sections: [
          { type: 'added' as const, items: ['频谱会话录制与回放', '跨时间段的频谱并列对比'] },
          { type: 'improved' as const, items: ['频谱分析器 UI 和操作'] },
        ],
      },
      {
        version: 'v1.3.0',
        date: '2026-05-28',
        sections: [
          { type: 'added' as const, items: ['用于 AI 工具集成的 MCP 服务器', '网络数据、详情和占用率的本地 JSON 端点'] },
          { type: 'improved' as const, items: ['信道质量评分算法'] },
        ],
      },
      {
        version: 'v1.2.0',
        date: '2026-05-24',
        sections: [
          { type: 'added' as const, items: ['带时间线可视化的漫游测试', '漫游测试的会话保存与回放'] },
          { type: 'improved' as const, items: ['网络表格排序和筛选'] },
        ],
      },
      {
        version: 'v1.1.0',
        date: '2026-05-20',
        sections: [
          { type: 'added' as const, items: ['连接诊断仪表盘', '信道质量评分和推荐'] },
          { type: 'improved' as const, items: ['三频频谱扫描器性能'] },
        ],
      },
      {
        version: 'v1.0.0',
        date: '2026-05-18',
        sections: [
          { type: 'added' as const, items: ['三频频谱扫描（2.4 / 5 / 6 GHz）', '带筛选功能的详细网络表格', '高分辨率频谱截图导出', '网络数据 CSV 导出'] },
        ],
      },
    ],
  },
  faq: {
    title: '常见问题',
    metaDescription: 'WiFi Lens 常见问题——价格、macOS 要求、数据隐私、Pro 与 OSS 区别、6 GHz 支持等。',
    items: [
      { q: 'WiFi Lens 免费吗？', a: '当然。WiFi Lens OSS 是开源且完全免费的，你可以在 GitHub 上自由下载和使用。Pro 版通过 App Store 提供，是一次性的赞助方式，解锁了几个录播相关的进阶功能。核心 Wi‑Fi 分析能力在两个版本上是一致的。' },
      { q: 'Pro 版和 OSS 版功能差在哪？', a: 'OSS 版涵盖频谱扫描、网络表格、信道评分、漫游测试、MCP AI 集成等全部核心功能。Pro 版额外提供频谱会话录制（可以将一段时间内的频谱变化录下来并回放），以及跨时间段的频谱对比。不需要录制回放的话，OSS 版完全够用。' },
      { q: '我的数据会被上传到云端吗？', a: '绝对不会。WiFi Lens 没有任何后端服务器，所有数据在你 Mac 上本地处理。即便是 MCP AI 集成，数据也只走你本机的接口，不会发送到任何远程服务器。我们可以很明确地说：我们不收集任何东西。' },
      { q: '需要什么版本的 macOS？', a: 'WiFi Lens 需要 macOS 14 (Sonoma) 或更高版本。支持 Apple Silicon 和 Intel 芯片。小提示：6GHz 频段扫描需要你的 Mac 硬件本身支持 Wi‑Fi 6E 或 Wi‑Fi 7（较新的 Apple Silicon 机型才具备）。老款 Intel Mac 或非 6E 机型仍可正常使用 2.4GHz 和 5GHz 的全部功能。' },
      { q: '为什么有些 6GHz 网络没有显示 6GHz 标签？', a: '这是 macOS 系统接口本身的限制。当前 macOS 提供给应用的无线扫描接口并不会始终明确标识某个网络属于 6GHz 频段——对于支持 Wi‑Fi 6E 的网络，系统通常只通过信道号或中心频率来体现其实际工作频段，而不是直接返回一个「6GHz」标签。因此部分 6GHz 网络在扫描结果中可能仅显示为 5GHz 或未标注具体频段。这属于系统层面的行为，不代表设备没有连接或使用 6GHz 网络。' },
      { q: '能在 Windows 或 Linux 上使用吗？', a: 'WiFi Lens 是 macOS 原生应用，暂不支持 Windows 或 Linux。它依赖 macOS CoreWLAN 框架来读取 Wi‑Fi 数据，这个框架在其他系统上没有对应物。' },
      { q: '为什么要求定位权限？', a: '这不是我们的要求，是 macOS 的规定。Apple 要求任何能读取 Wi‑Fi 网络名称（SSID）的 App 都必须获得定位权限。WiFi Lens 绝不会访问你的 GPS 坐标，也绝不记录你的位置信息。' },
    ],
  },
  privacy: {
    title: '你的数据始终留在你的 Mac 上。',
    subtitle: 'WiFi Lens 完全在本地处理所有数据。无需账户、无需云端、无追踪。',
    noCollection: {
      heading: '不收集个人数据',
      body: 'WiFi Lens 不会收集、存储或传输任何个人身份信息。应用中不包含用户账户、无分析 SDK、无广告网络、无遥测框架。我们没有后端服务器来接收你的数据——因为我们对拥有这些数据毫无兴趣。',
    },
    permissions: {
      heading: '我们为何请求权限',
      body: 'Wi‑Fi — 核心功能：扫描和分析附近的无线网络。\n\n蓝牙 — 可选择性用于发现附近的蓝牙设备以进行共存分析。此功能默认关闭，可在设置中开启。所有发现过程均在本地运行。\n\n定位服务 — macOS 要求任何读取 Wi‑Fi 网络名称（SSID）的应用获取此权限。WiFi Lens 绝不会访问你的 GPS 坐标，也不会记录你的位置。\n\n本地网络 — 仅在设置中开启 MCP 服务器后使用。服务器仅监听 localhost（127.0.0.1），以便 Claude Desktop 等本地工具读取 Wi‑Fi 扫描数据。默认关闭，数据不会离开你的 Mac。',
    },
    localOnly: {
      heading: '所有数据留在你的设备上',
      body: '所有 Wi‑Fi 扫描结果、蓝牙发现数据、信道推荐和监管区域检测完全在设备上运行。不会将任何扫描数据上传到远程服务器。\n\n崩溃报告和诊断日志以文件形式保存在你自己的磁盘上。除非你明确选择分享，否则不会传输任何内容。\n\nMCP 服务器绑定到 127.0.0.1（仅限本地）。除非你主动将其路由到其他地方，否则扫描数据不会通过 MCP 离开你的机器。',
    },
    distribution: {
      heading: '分发渠道差异',
      body: 'WiFi Lens 通过两个渠道提供。它们仅在更新检查方式上有所不同：\n\nMac App Store — 使用 Apple 内置的更新机制。该版本绝不会联系任何第三方服务器进行版本检查或更新。\n\nGitHub / 官网直装 — 使用 Sparkle 框架检查新版本。Sparkle 从我们的发布服务器获取一个 appcast 文件（版本描述文件）。此请求不传输个人数据、使用分析或诊断信息——仅仅是版本比对。',
    },
    openSource: {
      heading: '开源 & 可验证',
      body: 'WiFi Lens OSS 的完整源代码以 Apache 2.0 许可证开放。本页面上的每一项声明均可由任何阅读代码的人独立验证。',
    },
    lastUpdated: '最后更新：2026年5月27日',
    contact: '有问题？在 GitHub 提交 Issue 或发送邮件至 wifi-lens@outlook.com',
  },
  home: {
    exploreFeatures: '探索功能',
    featuresTitle: '更简洁的首页，更清晰的产品故事。',
    featuresSub: '从产品本身开始，需要深入了解时再深入。',
    exploreLabel: '探索',
    exploreTitle: '从匹配你问题的页面开始',
    exploreSub: '保持首页简短。需要具体内容时，去对应的详细页面。',
    viewPage: '查看页面',
  },
  notFound: {
    title: '404 — 页面未找到',
    heading: '这个页面不存在。',
    desc: '你要找的页面可能已被移动或不再存在。',
    backHome: '返回首页',
  },
  footer: {
    copyright: '© 2026 WiFi Lens — 洞悉你的 Wi‑Fi。',
    x: '@WiFiLens',
    email: 'wifi-lens@outlook.com',
    privacy: '隐私',
    support: '支持',
    oss: 'GitHub',
    license: 'Apache 2.0',
  },
} as const
