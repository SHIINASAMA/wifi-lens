import './style.css'
import { en as t } from './i18n'

const BASE = import.meta.env.BASE_URL

// ── Render ────────────────────────────────────────────────────

document.getElementById('app')!.innerHTML = /* html */ `
<div class="page">

  ${renderNav()}
  ${renderHero()}
  ${renderFeatures()}
  ${renderDemo()}
  ${renderSpecs()}
  ${renderDownload()}
  ${renderFooter()}

</div>
`

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
        <a href="#download" class="text-gray-400 hover:text-white transition-colors duration-200">${t.nav.download}</a>
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
            <a href="#download" class="btn-pro text-center relative">
              <svg class="w-5 h-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="2" y="4" width="20" height="16" rx="2"/><path d="M7 9l5 4 5-4"/><line x1="12" y1="9" x2="12" y2="17"/></svg>
              ${t.hero.cta.pro}
              <span class="absolute -top-2 -right-2 px-2 py-0.5 rounded-full bg-brand-600 text-[10px] font-semibold text-white shadow-lg">${t.hero.cta.proSoon}</span>
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
  <section id="features" class="relative py-32">
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

function screenshotRow(item: { title: string; desc: string; bullets: readonly string[]; image: string }, index: number) {
  const isEven = index % 2 === 0
  const imgCol = /* html */ `
  <div class="reveal ${isEven ? 'lg:order-1' : 'lg:order-2'}">
    <div class="glass-card overflow-hidden shadow-xl shadow-brand-950/10 group">
      <!-- macOS title bar -->
      <div class="flex items-center gap-2 px-3 h-8 bg-gray-900/80 border-b border-gray-800/50">
        <span class="w-2.5 h-2.5 rounded-full bg-red-500/60"></span>
        <span class="w-2.5 h-2.5 rounded-full bg-yellow-500/60"></span>
        <span class="w-2.5 h-2.5 rounded-full bg-green-500/60"></span>
        <span class="flex-1 text-center text-[10px] text-gray-600 font-medium tracking-wide mr-8">WiFi Lens — ${item.title}</span>
      </div>
      <!-- Image placeholder -->
      <div class="relative aspect-[16/10] bg-gray-950/80 flex items-center justify-center">
        <img
          src="${BASE}${item.image}"
          alt="${item.title}"
          class="absolute inset-0 w-full h-full object-cover"
          onerror="this.style.display='none';this.nextElementSibling.style.display='flex'"
        />
        <div class="hidden flex-col items-center gap-3 text-gray-600 pointer-events-none">
          <svg class="w-8 h-8" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1" opacity="0.4"><rect x="3" y="3" width="18" height="18" rx="2"/><circle cx="8.5" cy="8.5" r="1.5"/><polyline points="21 15 16 10 5 21"/></svg>
          <span class="text-xs font-mono">${item.image}</span>
          <span class="text-[10px] uppercase tracking-wider opacity-50">Placeholder — replace with screenshot</span>
        </div>
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
  <div class="grid lg:grid-cols-2 gap-10 items-center">
    ${imgCol}
    ${textCol}
  </div>`
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

// ── Download ──────────────────────────────────────────────────

function renderDownload() {
  return /* html */ `
  <section id="download" class="relative py-32">
    <div class="absolute inset-0 bg-gradient-to-b from-transparent via-brand-950/5 to-transparent"></div>
    <div class="relative mx-auto max-w-4xl px-6">
      <div class="reveal text-center mb-16">
        <h2 class="section-title">${t.download.title}</h2>
      </div>
      <div class="grid md:grid-cols-2 gap-6">
        ${downloadCard('oss')}
        ${downloadCard('pro')}
      </div>
    </div>
  </section>`
}

function downloadCard(variant: 'oss' | 'pro') {
  const d = t.download[variant]
  const isPro = variant === 'pro'

  return /* html */ `
  <div class="reveal glass-card p-8 flex flex-col ${isPro ? 'ring-1 ring-brand-500/20 relative' : ''}">
    ${isPro ? `<span class="absolute -top-3 left-1/2 -translate-x-1/2 px-3 py-1 rounded-full bg-brand-600 text-[11px] font-semibold text-white shadow-lg">Soon</span>` : ''}
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
      <svg class="w-5 h-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="2" y="4" width="20" height="16" rx="2"/><path d="M7 9l5 4 5-4"/><line x1="12" y1="9" x2="12" y2="17"/></svg>
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
      <div class="flex items-center gap-6 text-xs text-gray-600">
        <a href="https://github.com/SHIINASAMA/wifi-lens" class="hover:text-gray-400 transition-colors">${t.footer.oss}</a>
        <a href="https://github.com/SHIINASAMA/wifi-lens/blob/master/LICENSE" class="hover:text-gray-400 transition-colors">${t.footer.license}</a>
      </div>
    </div>
  </footer>`
}
