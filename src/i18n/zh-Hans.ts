export const zhHans = {
  nav: {
    features: '功能',
    mcp: 'MCP',
    download: '下载',
    privacy: '隐私',
    docs: '文档',
  },
  hero: {
    badge: 'macOS 14+  ·  原生  ·  本地优先',
    title: 'WiFi Lens',
    subtitle: '一款 macOS 原生 Wi‑Fi 分析工具，帮助你实时发现信道拥塞、诊断连接质量并验证漫游行为。',
    cta: {
      oss: '免费下载',
      secondary: 'AI 工作流',
      proSoon: 'Mac App Store 即将推出',
    },
    hint: '本地优先  ·  开源  ·  无追踪',
  },
  features: {
    title: '深度洞察你的无线环境',
    scanning: {
      title: '三频频谱扫描',
      desc: '实时查看附近的 2.4 GHz、5 GHz 和 6 GHz 网络更新。支持缩放、冻结和比较信道重叠情况，同时保持全局视图。',
    },
    table: {
      title: '详细网络表格',
      desc: '在密集、可排序的表格中查看每个可见网络的 RSSI、信道、频段、安全性、厂商和能力详情。快速筛选，在表格行和频谱曲线之间跳转，更快地排查问题。',
    },
    roaming: {
      title: '带时间线的漫游测试',
      desc: '在移动过程中追踪接入点切换。回顾切换记录、信号变化和已保存的会话，确认漫游行为是否符合预期。',
    },
    quality: {
      title: '信道质量评分',
      desc: '一目了然地找到所有 Wi‑Fi 频段中更干净的信道。评分、等级和推荐帮助你决定下一步该切换到哪个信道。',
    },
    overview: {
      title: '连接诊断仪表盘',
      desc: '从你当前正在使用的连接开始。WiFi Lens 会高亮显示信号健康状况、信道质量、安全性以及最可能的故障原因。',
    },
    privacy: {
      title: '默认隐私保护',
      desc: '无分析、无遥测、无云端依赖。你的扫描数据保留在你的 Mac 上，即便是 MCP 访问也仅限于你的本机。',
    },
  },
  demo: {
    title: '查看应用实际操作',
    subtitle: '六个专注视图，用于排查 Wi‑Fi 性能、覆盖范围和信道使用情况。',
    items: [
      {
        title: '概览仪表盘',
        alt: '概览仪表盘，显示当前 Wi-Fi 健康状况、信号强度和信道推荐',
        desc: '首先检查当前连接的健康状况。概览页面会突出显示信号强度、信道质量、安全性以及最有用的下一步建议。',
        bullets: ['当前连接健康状况一览', '可操作的信道推荐', '查看哪个频段最繁忙'],
        image: '/screenshots/overview.png',
      },
      {
        title: '频谱扫描器',
        alt: '三频频谱扫描器，显示各 Wi-Fi 频段的网络曲线和信道占用情况',
        desc: '观察附近网络在所有主要 Wi‑Fi 频段上的实时频谱图。用它快速发现重叠、拥塞和嘈杂的信道组。',
        bullets: ['实时三频频谱视图', '快速发现拥挤信道', '缩放、冻结和查看细节'],
        image: '/screenshots/spectrum.png',
      },
      {
        title: '信道质量分析器',
        alt: '信道质量分析器，具备区域感知评分、DFS 检测和设备兼容性筛选功能',
        desc: '在更改网络设置之前比较信道评分。WiFi Lens 会提供更干净的选项，包含区域感知筛选、重叠上下文和设备兼容性检查。',
        bullets: ['每个信道的质量评分', '区域感知推荐', '更干净信道的建议'],
        image: '/screenshots/channels.png',
      },
      {
        title: '详细网络表格',
        alt: '可排序的网络表格，包含 RSSI、信道、频段、安全性、厂商和能力等 Wi-Fi 详细信息',
        desc: '通过高密度的原生表格深入了解所有可见网络的详细列表。每行展示信号强度、信道、频段、安全类型、厂商 OUI 和 802.11 能力标志。',
        bullets: ['RSSI、信道、频段和安全类型', '厂商 OUI 与能力标志', '按 SSID 或 BSSID 快速筛选'],
        image: '/screenshots/table.png',
      },
      {
        title: '漫游测试',
        alt: '漫游测试时间线，显示接入点切换、信号历史和切换详情',
        desc: '在携带笔记本走动时验证漫游行为。回顾切换、信号历史和已保存的会话，了解客户端如何在 AP 之间移动。',
        bullets: ['检测随时间推移的 AP 切换', '可视化移动中的信号下降', '保存和重新加载漫游会话'],
        image: '/screenshots/roaming.png',
      },
      {
        title: '网络接口',
        alt: '网络接口视图，显示连接详情和实时吞吐量监控',
        desc: '在一个地方检查 Wi‑Fi 和非 Wi‑Fi 接口。在高级状态、详细链路信息和实时吞吐量监控之间切换。',
        bullets: ['在快速状态和深度详情之间切换', '监控实时吞吐量', '检查 Wi‑Fi、以太网、VPN 和虚拟链路'],
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
    title: '让 AI 检查你的本地 Wi‑Fi 环境',
    subtitle: 'WiFi Lens 可以通过 MCP 将实时扫描数据暴露给 Claude Desktop 等工具，让你无需将数据发送到云端即可询问附近网络和信道使用情况。',
    endpoints: {
      title: '三个 JSON 端点',
      networks: '浏览附近网络，包含信号、频段、信道、安全性和能力详情。',
      detail: '通过 BSSID 深入检查单个网络，包含信道宽度信息。',
      occupancy: '检查每个信道的占用情况，了解各 Wi‑Fi 频段的拥塞程度。',
    },
    config: {
      title: '一个配置即可连接',
      desc: '在 WiFi Lens 中启用 MCP 服务器，在 Claude Desktop 中添加此配置，然后就可以问"哪个信道最不拥挤？"或"附近网络有什么值得注意的地方？"',
    },
    cta: {
      docs: '阅读文档',
      github: '在 GitHub 上查看',
    },
  },
  download: {
    title: '开始使用 WiFi Lens',
    oss: {
      title: 'WiFi Lens OSS',
      badge: '免费 & 开源',
      desc: '从 GitHub Releases 下载最新版本，开箱即用，支持 macOS 14 及以上版本。',
      features: [
        '实时三频频谱扫描',
        '详细的网络表格和筛选',
        '信道质量评分和推荐',
        '漫游时间线分析',
        '连接诊断仪表盘',
        'AI 工作流本地 MCP 服务器',
      ],
      cta: '从 GitHub 下载',
      url: 'https://github.com/SHIINASAMA/wifi-lens/releases/latest',
    },
    pro: {
      title: 'WiFi Lens PRO',
      badge: '即将在 Mac App Store 推出',
      desc: '计划在未来推出 Mac App Store 版本，为希望获得更简单安装方式的用户提供选择。',
      features: [
        '相同的核心分析体验',
        '更简单的安装流程',
        'Mac App Store 分发（筹备中）',
      ],
      cta: '筹备中',
    },
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
      body: 'Wi‑Fi — 核心功能：扫描和分析附近的无线网络。\n\n蓝牙 — 用于发现附近的蓝牙设备以进行共存分析。所有发现过程均在本地运行。\n\n定位服务 — macOS 要求任何读取 Wi‑Fi 网络名称（SSID）的应用获取此权限。WiFi Lens 绝不会访问你的 GPS 坐标，也不会记录你的位置。',
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
      body: '完整源代码以 Apache 2.0 许可证开放。本页面上的每一项声明均可由任何阅读代码的人独立验证。',
    },
    lastUpdated: '最后更新：2026年5月27日',
    contact: '有问题？在 GitHub 提交 Issue 或发送邮件至 wifi-lens@outlook.com',
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
