import './style.css'
import { en as t } from './i18n'
import { createElement, Star, ChartColumn, CheckCircle, Table, Activity, Layers, Terminal, Lock, Download, Zap, LayoutDashboard, Store } from 'lucide'

const BASE = import.meta.env.BASE_URL

// Map demo item title → lucide icon
const lucideIcons: Record<string, string> = {
  'overview-dashboard':       'layout-dashboard',
  'spectrum-scanner':         'chart-column',
  'channel-quality-analyzer': 'check-circle',
  '18-column-network-table':  'table',
  'roaming-test':             'activity',
  'network-interfaces':       'layers',
}

const iconMap: Record<string, typeof Star> = {
  star: Star, 'layout-dashboard': LayoutDashboard, 'chart-column': ChartColumn,
  'check-circle': CheckCircle, table: Table, activity: Activity, layers: Layers,
  terminal: Terminal, lock: Lock, download: Download, zap: Zap, store: Store,
}

// ── Render ────────────────────────────────────────────────────

document.getElementById('app')!.innerHTML = /* html */ `
<div class="page">

  ${renderToC()}
  <button id="back-to-top" class="fixed bottom-8 right-8 z-50 w-10 h-10 rounded-full bg-gray-800/90 border border-gray-700/50 text-gray-400 hover:text-white hover:bg-gray-700/90 transition-all duration-300 flex items-center justify-center opacity-0 pointer-events-none backdrop-blur-md shadow-lg" aria-label="Back to top">
    <svg class="w-4 h-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="18 15 12 9 6 15"/></svg>
  </button>

  ${renderNav()}
  ${renderHero()}
  ${renderFeatures()}
  ${renderDemo()}
  ${renderSpecs()}
  ${renderMCP()}
  ${renderPrivacy()}
  ${renderDownload()}
  ${renderFooter()}

</div>
`

// Replace <i data-lucide> placeholders with SVG icons
document.querySelectorAll('[data-lucide]').forEach(el => {
  try {
    const name = el.getAttribute('data-lucide')!
    const icon = iconMap[name]
    if (!icon) return
    const svg = createElement(icon)
    const size = el.classList.contains('w-5') ? '1.25rem' : '0.875rem'
    svg.setAttribute('width', size)
    svg.setAttribute('height', size)
    svg.setAttribute('stroke', 'currentColor')
    svg.classList.add('shrink-0')
    el.replaceWith(svg)
  } catch (_) { /* icon not found, leave placeholder */ }
})

// ── Scroll reveal ─────────────────────────────────────────────

const observer = new IntersectionObserver(
  (entries) => {
    entries.forEach((e) => {
      if (e.isIntersecting) {
        e.target.classList.add('visible')
        observer.unobserve(e.target)
      }
    })
  },
  { threshold: 0.12 }
)

document.querySelectorAll('.reveal').forEach((el) => observer.observe(el))

// ── Sidebar ToC ──────────────────────────────────────────────

const tocLinks = document.querySelectorAll<HTMLAnchorElement>('.toc-link')
const tocObserver = new IntersectionObserver(
  (entries) => {
    for (const entry of entries) {
      if (entry.isIntersecting) {
        tocLinks.forEach((l) => l.classList.remove('toc-active'))
        const id = entry.target.id
        const link = document.querySelector<HTMLAnchorElement>(`.toc-link[href="#${id}"]`)
        link?.classList.add('toc-active')
      }
    }
  },
  { rootMargin: '-20% 0px -75% 0px', threshold: 0 }
)

document.querySelectorAll<HTMLElement>('[data-toc]').forEach((el) => tocObserver.observe(el))

// ── Back to top ──────────────────────────────────────────────

const topBtn = document.getElementById('back-to-top')!
window.addEventListener('scroll', () => {
  topBtn.classList.toggle('opacity-0', window.scrollY < 500)
  topBtn.classList.toggle('pointer-events-none', window.scrollY < 500)
})

topBtn.addEventListener('click', () => window.scrollTo({ top: 0, behavior: 'smooth' }))

// ── Nav scroll effect ─────────────────────────────────────────

const navEl = document.getElementById('nav')!
let lastY = 0
window.addEventListener('scroll', () => {
  const y = window.scrollY
  navEl.classList.toggle('nav-scrolled', y > 20)
  navEl.classList.toggle('nav-hidden', y > lastY && y > 400)
  lastY = y
})

// ═══════════════════════════════════════════════════════════════
// Sidebar ToC
// ═══════════════════════════════════════════════════════════════

function renderToC() {
  const short: Record<string, string> = {
    'overview-dashboard': 'Overview', 'spectrum-scanner': 'Spectrum',
    'channel-quality-analyzer': 'Channels', '18-column-network-table': 'Table',
    'roaming-test': 'Roaming', 'network-interfaces': 'Interfaces',
  }
  const items = [
    { id: 'features', label: 'Features', icon: 'zap' },
    ...(t.demo.items as readonly { title: string }[]).map(s => {
      const slug = s.title.toLowerCase().replace(/\s+/g, '-')
      return { id: slug, label: short[slug] ?? s.title, icon: lucideIcons[slug] ?? '' }
    }),
    { id: 'mcp', label: 'MCP', icon: 'terminal' },
    { id: 'privacy', label: 'Privacy', icon: 'lock' },
    { id: 'download', label: 'Download', icon: 'download' },
  ]

  return /* html */ `
  <aside class="toc-sidebar hidden xl:block fixed right-6 top-1/2 -translate-y-1/2 z-40 w-28">
    <nav class="flex flex-col gap-0.5">
      ${items.map(it => /* html */ `
      <a href="#${it.id}" class="toc-link flex items-center gap-2 text-xs text-gray-500 hover:text-gray-200 transition-colors duration-200 py-1 px-3 rounded-lg">${it.icon ? `<i data-lucide="${it.icon}"></i>` : ''}<span>${it.label}</span></a>
      `).join('')}
    </nav>
  </aside>`
}

// ═══════════════════════════════════════════════════════════════
// Nav
// ═══════════════════════════════════════════════════════════════

function renderNav() {
  return /* html */ `
  <nav id="nav" class="fixed top-0 inset-x-0 z-50 transition-transform duration-500">
    <div class="mx-auto max-w-6xl px-6 h-16 flex items-center justify-between">
      <a href="#" class="flex items-center gap-3 group">
        <img src="${BASE}icon.png" alt="WiFi Lens" class="w-8 h-8 rounded-lg transition-transform duration-300 group-hover:scale-110" />
        <span class="text-base font-semibold tracking-tight text-white">WiFi Lens</span>
      </a>
      <div class="hidden sm:flex items-center gap-8 text-sm">
        <a href="#features" class="text-gray-400 hover:text-white transition-colors duration-200">${t.nav.features}</a>
        <a href="#mcp" class="text-gray-400 hover:text-white transition-colors duration-200">${t.nav.mcp}</a>
        <a href="#download" class="text-gray-400 hover:text-white transition-colors duration-200">${t.nav.download}</a>
        <a href="#privacy" class="text-gray-400 hover:text-white transition-colors duration-200">${t.nav.privacy}</a>
        <a href="https://github.com/SHIINASAMA/wifi-lens/tree/master/docs" class="text-gray-400 hover:text-white transition-colors duration-200">${t.nav.docs}</a>
        <a href="https://github.com/SHIINASAMA/wifi-lens" class="text-gray-400 hover:text-white transition-colors duration-200" aria-label="GitHub">
          <svg class="w-5 h-5" viewBox="0 0 24 24" fill="currentColor"><path d="M12 0C5.37 0 0 5.37 0 12c0 5.31 3.435 9.795 8.205 11.385.6.105.825-.255.825-.57 0-.285-.015-1.23-.015-2.235-3.015.555-3.795-.735-4.035-1.41-.135-.345-.72-1.41-1.23-1.695-.42-.225-1.02-.78-.015-.795.945-.015 1.62.87 1.845 1.23 1.08 1.815 2.805 1.305 3.495.99.105-.78.42-1.305.765-1.605-2.67-.3-5.46-1.335-5.46-5.925 0-1.305.465-2.385 1.23-3.225-.12-.3-.54-1.53.12-3.18 0 0 1.005-.315 3.3 1.23.96-.27 1.98-.405 3-.405s2.04.135 3 .405c2.295-1.56 3.3-1.23 3.3-1.23.66 1.65.24 2.88.12 3.18.765.84 1.23 1.905 1.23 3.225 0 4.605-2.805 5.625-5.475 5.925.435.375.81 1.095.81 2.22 0 1.605-.015 2.895-.015 3.3 0 .315.225.69.825.57A12.02 12.02 0 0 0 24 12c0-6.63-5.37-12-12-12z"/></svg>
        </a>
      </div>
    </div>
  </nav>`
}

// ── Hero ──────────────────────────────────────────────────────

function renderHero() {
  return /* html */ `
  <section class="relative min-h-screen flex items-center overflow-hidden">
    <div class="absolute inset-0 bg-gradient-to-b from-gray-950 via-gray-950 to-gray-900"></div>
    <div class="absolute inset-0 bg-[radial-gradient(ellipse_80%_60%_at_50%_-10%,rgba(27,110,247,0.08),transparent)]"></div>
    <div class="absolute inset-0 bg-[radial-gradient(ellipse_40%_40%_at_80%_70%,rgba(46,142,255,0.04),transparent)]"></div>
    <div class="absolute inset-0 opacity-[0.03]" style="background-image:radial-gradient(circle,rgba(255,255,255,0.3) 1px,transparent 1px);background-size:32px 32px;"></div>

    <div class="relative mx-auto max-w-6xl px-6 pt-24 pb-20 w-full">
      <div class="grid lg:grid-cols-2 gap-16 items-center">

        <div class="reveal flex flex-col gap-8">
          <div class="inline-flex items-center gap-2 self-start px-3 py-1.5 rounded-full bg-gray-900/70 border border-gray-800 text-xs text-gray-400 font-mono">
            <span class="w-2 h-2 rounded-full bg-green-400 animate-pulse"></span>
            ${t.hero.badge}
          </div>

          <h1 class="text-5xl sm:text-6xl lg:text-7xl font-extrabold tracking-tight leading-[1.05]">
            <span class="text-white">${t.hero.title.split(' ')[0]}</span>
            <span class="bg-gradient-to-r from-brand-400 via-brand-500 to-cyan-400 bg-clip-text text-transparent"> ${t.hero.title.split(' ')[1]}</span>
          </h1>

          <p class="text-lg sm:text-xl text-gray-400 leading-relaxed max-w-lg">
            ${t.hero.subtitle}
          </p>

          <div class="flex flex-col sm:flex-row gap-3">
            <a href="https://github.com/SHIINASAMA/wifi-lens/releases/latest" class="btn-oss text-center">
              <svg class="w-5 h-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/></svg>
              ${t.hero.cta.oss}
            </a>
            <a href="#mcp" class="btn-pro text-center hero-secondary-cta">
              <svg class="w-5 h-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M9.59 4.59A2 2 0 1 1 11 8H2m10.59 11.41A2 2 0 1 0 14 16H2m15.73-8.27A2.5 2.5 0 1 1 19.5 12H2"/></svg>
              ${t.hero.cta.secondary}
            </a>
          </div>

          <p class="text-xs text-gray-600 font-mono flex items-center gap-1.5">
            <svg class="w-3.5 h-3.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><path d="M9 12l2 2 4-4"/></svg>
            ${t.hero.hint}
          </p>
        </div>

        <div class="reveal hidden lg:flex justify-center items-center">
          ${heroVisual()}
        </div>

      </div>
    </div>
  </section>`
}

function heroVisual() {
  return /* html */ `
  <div class="relative w-80 h-80">
    <svg viewBox="0 0 400 400" class="w-full h-full opacity-90">
      <defs>
        <radialGradient id="glow" cx="50%" cy="50%" r="50%">
          <stop offset="0%" stop-color="rgba(27,110,247,0.12)"/>
          <stop offset="100%" stop-color="transparent"/>
        </radialGradient>
      </defs>
      <circle cx="200" cy="320" r="160" fill="url(#glow)"/>

      <!-- Grid lines -->
      ${Array.from({length: 8}, (_, i) => {
        const y = 320 - (i + 1) * 35
        return `<line x1="40" y1="${y}" x2="360" y2="${y}" stroke="rgba(255,255,255,0.025)" stroke-width="0.5"/>`
      }).join('')}

      <!-- WiFi signal arcs radiating from bottom-center -->
      ${[0, 1, 2, 3].map(i => {
        const r = 55 + i * 54
        const start = -52 - i * 4
        const end = 52 + i * 4
        const sx = 200 + r * Math.cos(start * Math.PI / 180)
        const sy = 320 + r * Math.sin(start * Math.PI / 180)
        const ex = 200 + r * Math.cos(end * Math.PI / 180)
        const ey = 320 + r * Math.sin(end * Math.PI / 180)
        return `<path d="M${sx},${sy} A${r},${r} 0 0,1 ${ex},${ey}" fill="none" stroke="#1b6ef7" stroke-width="${3.2 - i * 0.55}" stroke-linecap="round" opacity="${0.2 + i * 0.22}"/>`
      }).join('')}

      <!-- Gaussian bell curves -->
      ${[
        [90, 220, 50, 'rgba(59,130,246,0.6)'],
        [200, 150, 45, 'rgba(139,92,246,0.5)'],
        [310, 190, 48, 'rgba(6,182,212,0.5)'],
        [150, 100, 35, 'rgba(59,130,246,0.35)'],
        [260, 120, 32, 'rgba(139,92,246,0.3)'],
      ].map(([cx, peak, w, color]) => {
        const pts = Array.from({length: 32}, (_, i) => {
          const x = +cx - +w + (2 * +w * i / 31)
          const relX = (x - +cx) / +w
          const y = 320 - +peak * Math.exp(-relX * relX * 2.2)
          return `${i === 0 ? 'M' : 'L'}${Math.round(x)},${Math.round(y)}`
        }).join(' ')
        return `<path d="${pts}" fill="none" stroke="${color}" stroke-width="1.2"/>`
      }).join('')}

      <!-- Scan line -->
      <line x1="0" y1="120" x2="400" y2="120" stroke="rgba(27,110,247,0.06)" stroke-width="1">
        <animate attributeName="y1" from="40" to="320" dur="5s" repeatCount="indefinite"/>
        <animate attributeName="y2" from="40" to="320" dur="5s" repeatCount="indefinite"/>
      </line>

      <!-- Center origin dot -->
      <circle cx="200" cy="320" r="4" fill="#1b6ef7" opacity="0.7">
        <animate attributeName="r" values="4;6;4" dur="2s" repeatCount="indefinite"/>
        <animate attributeName="opacity" values="0.7;0.3;0.7" dur="2s" repeatCount="indefinite"/>
      </circle>
    </svg>
  </div>`
}

// ── Features ──────────────────────────────────────────────────

function renderFeatures() {
  const items: { icon: string; title: string; desc: string }[] = [
    {
      icon: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" class="w-6 h-6"><path d="M2 15c0-6 8-10 10-10s10 4 10 10"/><circle cx="6" cy="18" r="2"/><circle cx="18" cy="18" r="2"/><circle cx="12" cy="15" r="3"/></svg>`,
      title: t.features.scanning.title,
      desc: t.features.scanning.desc,
    },
    {
      icon: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" class="w-6 h-6"><rect x="3" y="3" width="18" height="18" rx="2"/><line x1="3" y1="9" x2="21" y2="9"/><line x1="3" y1="15" x2="21" y2="15"/><line x1="9" y1="3" x2="9" y2="21"/></svg>`,
      title: t.features.table.title,
      desc: t.features.table.desc,
    },
    {
      icon: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" class="w-6 h-6"><polyline points="16 3 21 3 21 8"/><line x1="4" y1="20" x2="21" y2="3"/><polyline points="21 16 21 21 16 21"/><line x1="15" y1="15" x2="21" y2="21"/><line x1="4" y1="4" x2="9" y2="9"/></svg>`,
      title: t.features.roaming.title,
      desc: t.features.roaming.desc,
    },
    {
      icon: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" class="w-6 h-6"><circle cx="12" cy="12" r="10"/><path d="M12 6v6l4 2"/></svg>`,
      title: t.features.quality.title,
      desc: t.features.quality.desc,
    },
    {
      icon: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" class="w-6 h-6"><circle cx="12" cy="12" r="10"/><path d="M2 12h20"/><path d="M12 2a15.3 15.3 0 0 1 4 10 15.3 15.3 0 0 1-4 10 15.3 15.3 0 0 1-4-10 15.3 15.3 0 0 1 4-10z"/></svg>`,
      title: t.features.overview.title,
      desc: t.features.overview.desc,
    },
    {
      icon: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" class="w-6 h-6"><rect x="3" y="11" width="18" height="11" rx="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></svg>`,
      title: t.features.privacy.title,
      desc: t.features.privacy.desc,
    },
  ]

  return /* html */ `
  <section id="features" class="relative py-32" data-toc>
    <div class="mx-auto max-w-6xl px-6">
      <div class="reveal text-center mb-20">
        <h2 class="section-title">${t.features.title}</h2>
      </div>
      <div class="grid sm:grid-cols-2 lg:grid-cols-3 gap-px rounded-2xl overflow-hidden" style="background:linear-gradient(135deg,rgba(255,255,255,0.04),rgba(255,255,255,0.01),rgba(255,255,255,0.04))">
        ${items.map((f, i) => /* html */ `
        <div class="reveal glass-card group p-8 rounded-none" style="animation-delay:${i * 80}ms">
          <div class="feature-icon bg-brand-500/10 text-brand-400 group-hover:bg-brand-500/20 transition-colors duration-300">
            ${f.icon}
          </div>
          <h3 class="text-base font-semibold text-white mb-2">${f.title}</h3>
          <p class="text-sm text-gray-400 leading-relaxed">${f.desc}</p>
        </div>
        `).join('')}
      </div>
    </div>
  </section>`
}

// ── Demo / Screenshots ────────────────────────────────────────

function renderDemo() {
  const items: readonly {
    title: string
    alt: string
    desc: string
    bullets: readonly string[]
    image: string
  }[] = t.demo.items

  return /* html */ `
  <section class="relative py-32">
    <div class="mx-auto max-w-6xl px-6">
      <div class="reveal text-center mb-20">
        <h2 class="section-title">${t.demo.title}</h2>
        <p class="section-subtitle mx-auto">${t.demo.subtitle}</p>
      </div>

      <div class="flex flex-col gap-24">
        ${items.map((item, i) => screenshotRow(item, i)).join('')}
      </div>
    </div>
  </section>`
}

function screenshotRow(item: { title: string; alt: string; desc: string; bullets: readonly string[]; image: string }, index: number) {
  const slug = item.title.toLowerCase().replace(/\s+/g, '-')
  const isEven = index % 2 === 0
  const imgCol = /* html */ `
  <div class="reveal ${isEven ? 'lg:order-1' : 'lg:order-2'}">
    <div class="overflow-hidden rounded-2xl shadow-xl shadow-brand-950/10 group bg-gray-950/80 relative min-h-[240px]">
      <img
        src="${BASE}${item.image}"
        alt="${item.alt}"
        class="w-full block"
        onerror="this.style.display='none';this.nextElementSibling.classList.remove('hidden');this.nextElementSibling.classList.add('flex')"
      />
      <div class="hidden absolute inset-0 flex-col items-center justify-center gap-3 text-gray-600 pointer-events-none">
        <svg class="w-8 h-8" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1" opacity="0.4"><rect x="3" y="3" width="18" height="18" rx="2"/><circle cx="8.5" cy="8.5" r="1.5"/><polyline points="21 15 16 10 5 21"/></svg>
        <span class="text-xs font-mono">${item.image}</span>
        <span class="text-[10px] uppercase tracking-wider opacity-50">Screenshot unavailable</span>
      </div>
    </div>
  </div>`

  const textCol = /* html */ `
  <div class="reveal flex flex-col justify-center ${isEven ? 'lg:order-2' : 'lg:order-1'}">
    <h3 class="text-xl font-bold text-white mb-4">${item.title}</h3>
    <p class="text-sm text-gray-400 leading-relaxed mb-5">${item.desc}</p>
    <ul class="space-y-2">
      ${item.bullets.map(b => /* html */ `
      <li class="flex items-center gap-2.5 text-sm text-gray-300">
        <svg class="w-4 h-4 shrink-0 text-brand-400" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="20 6 9 17 4 12"/></svg>
        ${b}
      </li>
      `).join('')}
    </ul>
  </div>`

  return /* html */ `
  <section id="${slug}" class="grid lg:grid-cols-2 gap-10 items-center" data-toc>
    ${imgCol}
    ${textCol}
  </section>`
}

// ── Specs ─────────────────────────────────────────────────────

function renderSpecs() {
  return /* html */ `
  <section class="relative py-24">
    <div class="absolute inset-0 bg-gradient-to-b from-transparent via-brand-950/[0.03] to-transparent"></div>
    <div class="relative mx-auto max-w-4xl px-6">
      <div class="reveal text-center mb-12">
        <h2 class="section-title">${t.specs.title}</h2>
      </div>
      <div class="reveal glass-card p-px rounded-2xl overflow-hidden" style="background:linear-gradient(135deg,rgba(27,110,247,0.15),rgba(6,182,212,0.08),rgba(27,110,247,0.05))">
        <div class="bg-gray-950 rounded-2xl p-8 grid sm:grid-cols-2 gap-0.5">
          ${t.specs.items.map((s: {label: string; value: string}) => /* html */ `
          <div class="flex flex-col gap-1 px-4 py-3 rounded-lg hover:bg-gray-900/50 transition-colors">
            <dt class="text-[11px] text-gray-500 font-mono uppercase tracking-wider">${s.label}</dt>
            <dd class="text-sm text-gray-300">${s.value}</dd>
          </div>
          `).join('')}
        </div>
      </div>
    </div>
  </section>`
}

// ── MCP ──────────────────────────────────────────────────────

function renderMCP() {
  const mcp = t.mcp

  return /* html */ `
  <section class="relative py-28" data-toc id="mcp">
    <div class="absolute inset-0 bg-gradient-to-b from-gray-950 via-gray-950/80 to-gray-950"></div>
    <!-- subtle terminal green accent -->
    <div class="absolute inset-0 bg-[radial-gradient(ellipse_60%_40%_at_50%_50%,rgba(34,197,94,0.03),transparent)]"></div>

    <div class="relative mx-auto max-w-4xl px-6">
      <div class="reveal text-center mb-16">
        <span class="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-green-500/10 border border-green-500/20 text-[11px] text-green-400 font-mono uppercase tracking-wider mb-6">
          <svg class="w-3.5 h-3.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M9.59 4.59A2 2 0 1 1 11 8H2m10.59 11.41A2 2 0 1 0 14 16H2m15.73-8.27A2.5 2.5 0 1 1 19.5 12H2"/></svg>
          Model Context Protocol
        </span>
        <h2 class="section-title">${mcp.title}</h2>
        <p class="section-subtitle mx-auto max-w-2xl">${mcp.subtitle}</p>
      </div>

      <!-- Endpoints -->
      <div class="reveal grid sm:grid-cols-3 gap-4 mb-12">
        ${[
          { method: 'GET', path: '/networks', desc: mcp.endpoints.networks },
          { method: 'GET', path: '/networks/:bssid', desc: mcp.endpoints.detail },
          { method: 'GET', path: '/occupancy', desc: mcp.endpoints.occupancy },
        ].map(ep => /* html */ `
        <div class="glass-card p-5 group hover:border-green-500/20 transition-colors duration-300">
          <div class="flex items-center gap-2 mb-3">
            <span class="text-[10px] font-mono font-bold text-green-400 bg-green-500/10 px-1.5 py-0.5 rounded">${ep.method}</span>
            <span class="text-xs font-mono text-gray-400 group-hover:text-gray-200 transition-colors truncate">${ep.path}</span>
          </div>
          <p class="text-xs text-gray-500 leading-relaxed">${ep.desc}</p>
        </div>
        `).join('')}
      </div>

      <!-- Config snippet -->
      <div class="reveal">
        <p class="text-sm text-gray-400 text-center mb-4">${mcp.config.desc}</p>
        <div class="max-w-lg mx-auto glass-card overflow-hidden border-gray-700/50">
          <div class="flex items-center justify-between px-4 py-2 bg-gray-900/80 border-b border-gray-800/40">
            <span class="text-[10px] text-gray-500 font-mono uppercase tracking-wider">claude_desktop_config.json</span>
            <span class="flex gap-1.5">
              <span class="w-2.5 h-2.5 rounded-full bg-red-500/60"></span>
              <span class="w-2.5 h-2.5 rounded-full bg-yellow-500/60"></span>
              <span class="w-2.5 h-2.5 rounded-full bg-green-500/60"></span>
            </span>
          </div>
          <pre class="p-5 text-xs font-mono text-gray-300 bg-gray-950/80 overflow-x-auto leading-relaxed"><span class="text-gray-500">{</span>
  <span class="text-green-400">"mcpServers"</span>: <span class="text-gray-500">{</span>
    <span class="text-green-400">"wifi-lens"</span>: <span class="text-gray-500">{</span>
      <span class="text-green-400">"command"</span>: <span class="text-amber-300">"WiFiLensMCP"</span>,
      <span class="text-green-400">"args"</span>: <span class="text-gray-500">[</span><span class="text-amber-300">"19840"</span><span class="text-gray-500">]</span>
    <span class="text-gray-500">}</span>
  <span class="text-gray-500">}</span>
<span class="text-gray-500">}</span></pre>
        </div>
      </div>

      <!-- Links -->
      <div class="reveal flex justify-center gap-4 mt-8">
        <a href="https://github.com/SHIINASAMA/wifi-lens/blob/master/docs/ARCHITECTURE.md" class="text-xs text-gray-500 hover:text-gray-300 transition-colors font-mono flex items-center gap-1.5">
          <svg class="w-3.5 h-3.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M2 3h6a4 4 0 0 1 4 4v14a3 3 0 0 0-3-3H2z"/><path d="M22 3h-6a4 4 0 0 0-4 4v14a3 3 0 0 1 3-3h7z"/></svg>
          ${mcp.cta.docs}
        </a>
        <a href="https://github.com/SHIINASAMA/wifi-lens" class="text-xs text-gray-500 hover:text-gray-300 transition-colors font-mono flex items-center gap-1.5">
          <svg class="w-3.5 h-3.5" viewBox="0 0 24 24" fill="currentColor"><path d="M12 0C5.37 0 0 5.37 0 12c0 5.31 3.435 9.795 8.205 11.385.6.105.825-.255.825-.57 0-.285-.015-1.23-.015-2.235-3.015.555-3.795-.735-4.035-1.41-.135-.345-.72-1.41-1.23-1.695-.42-.225-1.02-.78-.015-.795.945-.015 1.62.87 1.845 1.23 1.08 1.815 2.805 1.305 3.495.99.105-.78.42-1.305.765-1.605-2.67-.3-5.46-1.335-5.46-5.925 0-1.305.465-2.385 1.23-3.225-.12-.3-.54-1.53.12-3.18 0 0 1.005-.315 3.3 1.23.96-.27 1.98-.405 3-.405s2.04.135 3 .405c2.295-1.56 3.3-1.23 3.3-1.23.66 1.65.24 2.88.12 3.18.765.84 1.23 1.905 1.23 3.225 0 4.605-2.805 5.625-5.475 5.925.435.375.81 1.095.81 2.22 0 1.605-.015 2.895-.015 3.3 0 .315.225.69.825.57A12.02 12.02 0 0 0 24 12c0-6.63-5.37-12-12-12z"/></svg>
          ${mcp.cta.github}
        </a>
      </div>
    </div>
  </section>`
}

// ── Privacy ───────────────────────────────────────────────────

function renderPrivacy() {
  const p = t.privacy

  return /* html */ `
  <section class="relative py-28" data-toc id="privacy">
    <div class="absolute inset-0 bg-gradient-to-b from-gray-950/50 via-transparent to-transparent"></div>
    <div class="relative mx-auto max-w-4xl px-6">
      <div class="reveal text-center mb-14">
        <h2 class="section-title">${p.title}</h2>
        <p class="section-subtitle mx-auto">${p.subtitle}</p>
      </div>
      <div class="reveal max-w-2xl mx-auto space-y-4">
        ${p.bullets.map((b: string) => /* html */ `
        <div class="flex items-start gap-3 text-sm text-gray-400">
          <svg class="w-5 h-5 mt-0.5 shrink-0 text-brand-400/70" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="20 6 9 17 4 12"/></svg>
          <span>${b}</span>
        </div>
        `).join('')}
        <div class="flex items-start gap-3 text-sm text-gray-500 pt-2">
          <svg class="w-5 h-5 mt-0.5 shrink-0 text-green-500/60" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="11" width="18" height="11" rx="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></svg>
          <span>${p.mcp}</span>
        </div>
        <p class="text-xs text-gray-600 text-center pt-6">${p.oss}</p>
      </div>
    </div>
  </section>`
}

// ── Download ──────────────────────────────────────────────────

function renderDownload() {
  return /* html */ `
  <section id="download" class="relative py-32" data-toc>
    <div class="absolute inset-0 bg-gradient-to-b from-transparent via-brand-950/5 to-transparent"></div>
    <div class="relative mx-auto max-w-4xl px-6">
      <div class="reveal text-center mb-16">
        <h2 class="section-title">${t.download.title}</h2>
      </div>
      <div class="grid md:grid-cols-2 gap-6 items-stretch download-grid">
        ${downloadCard('oss')}
        ${downloadCard('pro')}
      </div>
      <p class="reveal text-center text-xs text-gray-500 font-mono mt-6">${t.hero.cta.proSoon}</p>
    </div>
  </section>`
}

function downloadCard(variant: 'oss' | 'pro') {
  const d = t.download[variant]
  const isPro = variant === 'pro'

  return /* html */ `
  <div class="reveal download-card ${isPro ? 'download-card-pro relative' : 'download-card-oss'}">
    ${isPro ? `<span class="absolute -top-3 left-1/2 -translate-x-1/2 px-3 py-1 rounded-full bg-gray-800 border border-gray-700 text-[11px] font-medium text-gray-300 shadow-lg flex items-center gap-1.5"><svg class="w-3 h-3" viewBox="0 0 24 24" fill="currentColor"><path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.8-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z"/></svg>App Store</span>` : ''}
    <div class="flex items-center gap-3 mb-3">
      <h3 class="text-xl font-bold text-white">${d.title}</h3>
      <span class="px-2.5 py-0.5 rounded-full text-[10px] font-medium ${isPro ? 'bg-brand-500/15 text-brand-300' : 'bg-emerald-500/15 text-emerald-300'}">${d.badge}</span>
    </div>
    <p class="text-sm text-gray-400 mb-6 leading-relaxed">${d.desc}</p>
    <ul class="space-y-3 mb-8 flex-1">
      ${(d.features as readonly string[]).map((f: string) => /* html */ `
      <li class="flex items-start gap-2.5 text-sm text-gray-300">
        <svg class="w-5 h-5 mt-0.5 shrink-0 ${isPro ? 'text-brand-400' : 'text-emerald-400'}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="20 6 9 17 4 12"/></svg>
        ${f}
      </li>
      `).join('')}
    </ul>
    ${variant === 'oss' ? /* html */ `
    <a href="${(d as {url: string}).url}" class="btn-oss justify-center text-center">
      <svg class="w-5 h-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/></svg>
      ${d.cta}
    </a>
    ` : /* html */ `
    <button class="btn-pro justify-center text-center w-full cursor-not-allowed opacity-80" disabled>
      <svg class="w-5 h-5" viewBox="0 0 24 24" fill="currentColor"><path d="M8.8086 14.9194l6.1107-11.0368c.0837-.1513.1682-.302.2437-.4584.0685-.142.1267-.2854.1646-.4403.0803-.3259.0588-.6656-.066-.9767-.1238-.3095-.3417-.5678-.6201-.7355a1.4175 1.4175 0 0 0-.921-.1924c-.3207.043-.6135.1935-.8443.4288-.1094.1118-.1996.2361-.2832.369-.092.1463-.175.2979-.259.4492l-.3864.6979-.3865-.6979c-.0837-.1515-.1667-.303-.2587-.4492-.0837-.1329-.1739-.2572-.2835-.369-.2305-.2353-.5233-.3857-.844-.429a1.4181 1.4181 0 0 0-.921.1926c-.2784.1677-.4964.426-.6203.7355-.1246.311-.1461.6508-.066.9767.038.155.0962.2984.1648.4403.0753.1564.1598.307.2437.4584l1.248 2.2543-4.8625 8.7825H2.0295c-.1676 0-.3351-.0007-.5026.0092-.1522.009-.3004.0284-.448.0714-.3108.0906-.5822.2798-.7783.548-.195.2665-.3006.5929-.3006.9279 0 .3352.1057.6612.3006.9277.196.2683.4675.4575.7782.548.1477.043.296.0623.4481.0715.1675.01.335.009.5026.009h13.0974c.0171-.0357.059-.1294.1-.2697.415-1.4151-.6156-2.843-2.0347-2.843zM3.113 18.5418l-.7922 1.5008c-.0818.1553-.1644.31-.2384.4705-.067.1458-.124.293-.1611.452-.0785.3346-.0576.6834.0645 1.0029.1212.3175.3346.583.607.7549.2727.172.5891.2416.9013.1975.3139-.044.6005-.1986.8263-.4402.1072-.1148.1954-.2424.2772-.3787.0902-.1503.1714-.3059.2535-.4612L6 19.4636c-.0896-.149-.9473-1.4704-2.887-.9218m20.5861-3.0056a1.4707 1.4707 0 0 0-.779-.5407c-.1476-.0425-.2961-.0616-.4483-.0705-.1678-.0099-.3352-.0091-.503-.0091H18.648l-4.3891-7.817c-.6655.7005-.9632 1.485-1.0773 2.1976-.1655 1.0333.0367 2.0934.546 3.0004l5.2741 9.3933c.084.1494.167.299.2591.4435.0837.131.1739.2537.2836.364.231.2323.5238.3809.8449.4232.3192.0424.643-.0244.9217-.1899.2784-.1653.4968-.4204.621-.7257.1246-.3072.146-.6425.0658-.9641-.0381-.1529-.0962-.2945-.165-.4346-.0753-.1543-.1598-.303-.2438-.4524l-1.216-2.1662h1.596c.1677 0 .3351.0009.5029-.009.1522-.009.3007-.028.4483-.0705a1.4707 1.4707 0 0 0 .779-.5407A1.5386 1.5386 0 0 0 24 16.452a1.539 1.539 0 0 0-.3009-.9158Z"/></svg>
      ${d.cta}
    </button>
    `}
  </div>`
}

// ── Footer ────────────────────────────────────────────────────

function renderFooter() {
  return /* html */ `
  <footer class="relative border-t border-gray-800/50 py-10">
    <div class="mx-auto max-w-6xl px-6 flex flex-col sm:flex-row items-center justify-between gap-4">
      <p class="text-xs text-gray-500">${t.footer.copyright}</p>
      <div class="flex items-center gap-5 text-xs text-gray-600">
        <a href="https://x.com/WiFiLens" class="hover:text-gray-300 transition-colors flex items-center gap-1.5" aria-label="X (Twitter)">
          <svg class="w-3.5 h-3.5" viewBox="0 0 24 24" fill="currentColor"><path d="M18.244 2.25h3.308l-7.227 8.26 8.502 11.24H16.17l-5.214-6.817L4.99 21.75H1.68l7.73-8.835L1.254 2.25H8.08l4.713 6.231zm-1.161 17.52h1.833L7.084 4.126H5.117z"/></svg>
          ${t.footer.x}
        </a>
        <a href="mailto:${t.footer.email}" class="hover:text-gray-300 transition-colors flex items-center gap-1.5">
          <svg class="w-3.5 h-3.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="2" y="4" width="20" height="16" rx="2"/><path d="M22 4L12 13 2 4"/></svg>
          ${t.footer.email}
        </a>
        <span class="text-gray-800">|</span>
        <a href="#privacy" class="hover:text-gray-400 transition-colors">${t.footer.privacy}</a>
        <a href="https://github.com/SHIINASAMA/wifi-lens/issues" class="hover:text-gray-400 transition-colors">${t.footer.support}</a>
        <a href="https://github.com/SHIINASAMA/wifi-lens" class="hover:text-gray-400 transition-colors">${t.footer.oss}</a>
        <a href="https://github.com/SHIINASAMA/wifi-lens/blob/master/LICENSE" class="hover:text-gray-400 transition-colors">${t.footer.license}</a>
      </div>
    </div>
  </footer>`
}
