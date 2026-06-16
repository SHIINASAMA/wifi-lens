import './style.css'
import i18next, { ready, changeLanguage } from './i18n'
import type { SupportedLocale } from './i18n'
import { en } from './i18n/en'

let lng: SupportedLocale = 'en'
let t: typeof en = en

const BASE = import.meta.env.BASE_URL

function resolveLanguage(): SupportedLocale {
  const lang = i18next.language
  if (lang?.startsWith('zh')) return 'zh-Hans'
  if (lang?.startsWith('ja')) return 'ja'
  if (lang?.startsWith('es')) return 'es'
  if (lang?.startsWith('de')) return 'de'
  return 'en'
}

function loadTranslation(lang: SupportedLocale) {
  const data = i18next.getDataByLanguage(lang) as { translation?: Record<string, unknown> } | undefined
  t = (data?.translation as typeof en) ?? en
}

function esc(s: string): string {
  return s
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;')
}

/* ── SVG helpers ───────────────────────────────────────────── */

const checkSVG = '<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="20 6 9 17 4 12"/></svg>'
const dlSVG = '<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/></svg>'
const ghSVG = '<svg class="gh-icon" viewBox="0 0 24 24" fill="currentColor"><path d="M12 0C5.37 0 0 5.37 0 12c0 5.31 3.435 9.795 8.205 11.385.6.105.825-.255.825-.57 0-.285-.015-1.23-.015-2.235-3.015.555-3.795-.735-4.035-1.41-.135-.345-.72-1.41-1.23-1.695-.42-.225-1.02-.78-.015-.795.945-.015 1.62.87 1.845 1.23 1.08 1.815 2.805 1.305 3.495.99.105-.78.42-1.305.765-1.605-2.67-.3-5.46-1.335-5.46-5.925 0-1.305.465-2.385 1.23-3.225-.12-.3-.54-1.53.12-3.18 0 0 1.005-.315 3.3 1.23.96-.27 1.98-.405 3-.405s2.04.135 3 .405c2.295-1.56 3.3-1.23 3.3-1.23.66 1.65.24 2.88.12 3.18.765.84 1.23 1.905 1.23 3.225 0 4.605-2.805 5.625-5.475 5.925.435.375.81 1.095.81 2.22 0 1.605-.015 2.895-.015 3.3 0 .315.225.69.825.57A12.02 12.02 0 0 0 24 12c0-6.63-5.37-12-12-12z"/></svg>'
const mcpIconSVG = '<svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M9.59 4.59A2 2 0 1 1 11 8H2m10.59 11.41A2 2 0 1 0 14 16H2m15.73-8.27A2.5 2.5 0 1 1 19.5 12H2"/></svg>'
const starSVG = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor"><path d="M2 15c0-6 8-10 10-10s10 4 10 10"/><circle cx="6" cy="18" r="2"/><circle cx="18" cy="18" r="2"/><circle cx="12" cy="15" r="3"/></svg>'
const tableSVG = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor"><rect x="3" y="3" width="18" height="18" rx="2"/><line x1="3" y1="9" x2="21" y2="9"/><line x1="3" y1="15" x2="21" y2="15"/><line x1="9" y1="3" x2="9" y2="21"/></svg>'
const roamSVG = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor"><polyline points="16 3 21 3 21 8"/><line x1="4" y1="20" x2="21" y2="3"/><polyline points="21 16 21 21 16 21"/><line x1="15" y1="15" x2="21" y2="21"/><line x1="4" y1="4" x2="9" y2="9"/></svg>'
const clockSVG = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor"><circle cx="12" cy="12" r="10"/><path d="M12 6v6l4 2"/></svg>'
const globeSVG = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor"><circle cx="12" cy="12" r="10"/><path d="M2 12h20"/><path d="M12 2a15.3 15.3 0 0 1 4 10 15.3 15.3 0 0 1-4 10 15.3 15.3 0 0 1-4-10 15.3 15.3 0 0 1 4-10z"/></svg>'
const lockSVG = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor"><rect x="3" y="11" width="18" height="11" rx="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></svg>'
const bttSVG = '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="18 15 12 9 6 15"/></svg>'

const featureIcons = [starSVG, tableSVG, roamSVG, clockSVG, globeSVG, lockSVG]

/* ── Render ────────────────────────────────────────────────── */

function renderAll() {
  document.getElementById('app')!.innerHTML = /* html */ `
<div class="page">

  <a id="skip-link" href="#hero">${esc(t.a11y.skipLink)}</a>

  ${renderNav()}
  ${renderHero()}
  ${renderStats()}
  ${renderFeatures()}
  ${renderDemo()}
  ${renderSpecs()}
  ${renderMCP()}
  ${renderPrivacy()}
  ${renderDownload()}
  ${renderFAQ()}
  ${renderFooter()}
  ${renderBTT()}

</div>
`
}

/* ── Nav ───────────────────────────────────────────────────── */

function renderNav() {
  return /* html */ `
  <nav id="nav">
    <a href="#" class="logo">
      <img src="${BASE}icon.png" alt="WiFi Lens" />
      WiFi Lens
    </a>
    <button class="hamburger" aria-label="${esc(t.a11y.menu)}" aria-expanded="false">
      <span></span><span></span><span></span>
    </button>
    <div class="links">
      <a href="#features">${t.nav.features}</a>
      <a href="#mcp" class="nav-hide-md">${t.nav.mcp}</a>
      <a href="#download">${t.nav.download}</a>
      <a href="#faq">${t.nav.faq ?? 'FAQ'}</a>
      <a href="#privacy">${t.nav.privacy}</a>
      <a href="https://github.com/SHIINASAMA/wifi-lens/tree/master/docs">${t.nav.docs}</a>
      <a href="https://github.com/SHIINASAMA/wifi-lens" aria-label="GitHub">${ghSVG}</a>
      <div class="lang-switch" role="radiogroup" aria-label="${esc(t.a11y.selectLanguage)}">
        <span class="lang-indicator" aria-hidden="true"></span>
        <button class="lang-option" role="radio" data-lang="en">EN</button>
        <button class="lang-option" role="radio" data-lang="de">DE</button>
        <button class="lang-option" role="radio" data-lang="es">ES</button>
        <button class="lang-option" role="radio" data-lang="ja">日本語</button>
        <button class="lang-option" role="radio" data-lang="zh-Hans">中文</button>
      </div>
    </div>
  </nav>`
}

/* ── Hero ─────────────────────────────────────────────────── */

function renderHero() {
  return /* html */ `
  <section id="hero">
    <canvas id="hero-canvas" aria-hidden="true"></canvas>
    <span class="hero-badge rv">${esc(t.hero.badge)}</span>
    <h1 class="rv-s">WiFi Lens<span class="sub">${esc(t.hero.hint.split('  ·  ')[0] ?? '')}</span></h1>
    <p class="hero-subtitle rv">${esc(t.hero.subtitle)}</p>
    <div class="hero-cta-row rv">
      <a href="#download" class="btn-primary">
        ${dlSVG}
        ${t.hero.cta.oss}
      </a>
      <a href="#mcp" class="btn-secondary">
        ${mcpIconSVG}
        ${t.hero.cta.secondary}
      </a>
    </div>
  </section>`
}

/* ── Stats ─────────────────────────────────────────────────── */

function renderStats() {
  const stats: { value: string; label: string }[] = (t as typeof en & { stats: { value: string; label: string }[] }).stats
  return /* html */ `
  <section id="stats" style="border-top:1px solid var(--border);border-bottom:1px solid var(--border)">
    <div class="stats-grid">
      ${stats.map(s => /* html */ `
      <div class="stat-cell rv"><span class="stat-value">${esc(s.value)}</span><span class="stat-label">${esc(s.label)}</span></div>
      `).join('')}
    </div>
  </section>`
}

/* ── Features ──────────────────────────────────────────────── */

function renderFeatures() {
  const items = [
    { icon: 0, title: t.features.scanning.title, desc: t.features.scanning.desc },
    { icon: 1, title: t.features.table.title, desc: t.features.table.desc },
    { icon: 2, title: t.features.roaming.title, desc: t.features.roaming.desc },
    { icon: 3, title: t.features.quality.title, desc: t.features.quality.desc },
    { icon: 4, title: t.features.overview.title, desc: t.features.overview.desc },
    { icon: 5, title: t.features.privacy.title, desc: t.features.privacy.desc },
  ]

  return /* html */ `
  <section id="features" class="sec-pad">
    <div class="sec-inner">
      <span class="sec-label rv">${t.nav.features}</span>
      <h2 class="sec-title rv">${t.features.title}</h2>

      <div class="feat-grid" style="margin-top:3rem">
        ${items.map((f, i) => /* html */ `
        <div class="feat-card rv" style="transition-delay:${i * 70}ms">
          <div class="feat-icon">${featureIcons[f.icon] ?? ''}</div>
          <h3>${esc(f.title)}</h3>
          <p>${esc(f.desc)}</p>
        </div>
        `).join('')}
      </div>
    </div>
  </section>`
}

/* ── Demo ──────────────────────────────────────────────────── */

function renderDemo() {
  const items: readonly {
    title: string; alt: string; desc: string; bullets: readonly string[]; image: string
  }[] = t.demo.items
  if (!items?.length) return ''

  return /* html */ `
  <section id="demo-sec" class="sec-pad">
    <div class="sec-inner">
      <span class="sec-label rv" id="screenshot-index-label">${t.demo.title}</span>
      <h2 class="sec-title rv">${t.demo.subtitle}</h2>

      <div style="margin-top:4rem">
        ${items.map((item, i) => screenshotRow(item, i)).join('')}
      </div>
    </div>
  </section>`
}

function screenshotRow(item: { title: string; alt: string; desc: string; bullets: readonly string[]; image: string }, index: number) {
  const slug = item.title.toLowerCase().replace(/\s+/g, '-')
  const even = index % 2 === 0

  const imgBlock = /* html */ `
  <div class="demo-img rv">
    <img src="${BASE}${item.image}" alt="${esc(item.alt)}" />
  </div>`

  const textBlock = /* html */ `
  <div class="demo-text rv">
    <h3>${esc(item.title)}</h3>
    <p>${esc(item.desc)}</p>
    <ul>
      ${item.bullets.map(b => /* html */ `
      <li>${checkSVG}${esc(b)}</li>
      `).join('')}
    </ul>
  </div>`

  return /* html */ `
  <div class="demo-row" id="${slug}">
    ${even ? imgBlock + textBlock : textBlock + imgBlock}
  </div>`
}

/* ── Specs ─────────────────────────────────────────────────── */

function renderSpecs() {
  return /* html */ `
  <section id="specs" class="sec-pad">
    <div class="sec-narrow">
      <h2 class="sec-title rv" style="margin-bottom:2.5rem">${t.specs.title}</h2>
      <div class="specs-grid rv">
        ${t.specs.items.map((s: {label: string; value: string}) => /* html */ `
        <div class="spec-cell"><p class="sl">${esc(s.label)}</p><p class="sv">${esc(s.value)}</p></div>
        `).join('')}
      </div>
    </div>
  </section>`
}

/* ── MCP ──────────────────────────────────────────────────── */

function renderMCP() {
  const mcp = t.mcp

  return /* html */ `
  <section id="mcp" class="sec-pad">
    <div class="sec-inner">
      <span class="sec-label rv" style="display:inline-flex;align-items:center;gap:0.35rem">
        ${mcpIconSVG}
        Model Context Protocol
      </span>
      <h2 class="sec-title rv" style="max-width:30rem">${mcp.title}</h2>
      <p class="sec-sub rv" style="margin-top:0.75rem">${mcp.subtitle}</p>

      <div class="mcp-grid rv" style="margin-top:2.5rem">
        <div class="mcp-card">
          <div><span class="method-tag">GET</span><span class="ep-path">/networks</span></div>
          <p>${mcp.endpoints.networks}</p>
        </div>
        <div class="mcp-card">
          <div><span class="method-tag">GET</span><span class="ep-path">/networks/:bssid</span></div>
          <p>${mcp.endpoints.detail}</p>
        </div>
        <div class="mcp-card">
          <div><span class="method-tag">GET</span><span class="ep-path">/occupancy</span></div>
          <p>${mcp.endpoints.occupancy}</p>
        </div>
      </div>

      <p class="sec-sub rv" style="text-align:center;margin:2.5rem auto 1.25rem;font-size:0.9375rem;max-width:28rem">${mcp.config.desc}</p>

      <div class="mcp-term rv">
        <div class="th">
          <span class="tf">claude_desktop_config.json</span>
          <span class="dots"><span class="dot"></span><span class="dot"></span><span class="dot"></span></span>
        </div>
        <pre>{
  <span style="color:var(--code-key)">"mcpServers"</span>: {
    <span style="color:var(--code-key)">"wifi-lens"</span>: {
      <span style="color:var(--code-key)">"command"</span>: <span style="color:var(--code-str)">"WiFiLensMCP"</span>,
      <span style="color:var(--code-key)">"args"</span>: [<span style="color:var(--code-str)">"19840"</span>]
    }
  }
}</pre>
      </div>
    </div>
  </section>`
}

/* ── Privacy ───────────────────────────────────────────────── */

function renderPrivacy() {
  const p = t.privacy

  return /* html */ `
  <section id="privacy" class="sec-pad">
    <div class="sec-narrow">
      <h2 class="sec-title rv" style="text-align:center">${p.title}</h2>
      <p class="sec-sub rv" style="text-align:center;max-width:30rem;margin:0.5rem auto 0">${p.subtitle}</p>

      <div class="priv-grid rv" style="margin-top:3rem">
        <div class="priv-item">
          <h3>${p.noCollection.heading}</h3>
          <p>${esc(p.noCollection.body.replace(/\n\n/g, '</p><p>'))}</p>
        </div>
        <div class="priv-item">
          <h3>${p.permissions.heading}</h3>
          ${p.permissions.body.split('\n\n').map(para => `<p>${esc(para.trim())}</p>`).join('')}
        </div>
        <div class="priv-item">
          <h3>${p.localOnly.heading}</h3>
          ${p.localOnly.body.split('\n\n').map(para => `<p>${esc(para.trim())}</p>`).join('')}
        </div>
        <div class="priv-item">
          <h3>${p.distribution.heading}</h3>
          ${p.distribution.body.split('\n\n').map(para => `<p>${esc(para.trim())}</p>`).join('')}
        </div>
        <div class="priv-item">
          <h3>${p.openSource.heading}</h3>
          <p>${esc(p.openSource.body)}</p>
        </div>
      </div>

      <div class="priv-foot rv">
        <p>${p.lastUpdated}</p>
        <p style="margin-top:0.25rem">${p.contact}</p>
      </div>
    </div>
  </section>`
}

/* ── Download ──────────────────────────────────────────────── */

function renderDownload() {
  const oss = t.download.oss
  const pro = t.download.pro

  return /* html */ `
  <section id="download" class="sec-pad">
    <div class="sec-inner">
      <h2 class="sec-title rv" style="text-align:center">${t.download.title}</h2>

      <div class="dl-grid rv" style="margin-top:3rem">
        <div class="dl-card">
          <div class="dlh">
            <h3>${oss.title}</h3>
            <span class="badge">${oss.badge}</span>
          </div>
          <p>${oss.desc}</p>
          <ul>
            ${(oss.features as readonly string[]).map((f: string) => `<li>${checkSVG}${esc(f)}</li>`).join('')}
          </ul>
          <div class="dl-btn">
            <a href="${(oss as {url: string}).url}" class="btn-secondary" style="justify-content:center">
              ${dlSVG}
              ${oss.cta}
            </a>
          </div>
        </div>

        <div class="dl-card pro">
          <div class="dlh">
            <h3>${pro.title}</h3>
            <span class="badge">${pro.badge}</span>
          </div>
          <p>${pro.desc}</p>
          <ul>
            ${(pro.features as readonly string[]).map((f: string) => `<li>${checkSVG}${esc(f)}</li>`).join('')}
          </ul>
          <div class="dl-btn">
            <a href="${(pro as {url: string}).url}" class="btn-primary" style="justify-content:center">
              ${pro.cta}
            </a>
          </div>
        </div>
      </div>
    </div>
  </section>`
}

/* ── FAQ ───────────────────────────────────────────────────── */

function renderFAQ() {
  const faq = (t as typeof en & { faq?: { title: string; items: { q: string; a: string }[] } }).faq
  if (!faq?.items?.length) return ''

  return /* html */ `
  <section id="faq" class="sec-pad">
    <div class="sec-narrow">
      <h2 class="sec-title rv" style="text-align:center;margin-bottom:3rem">${faq.title}</h2>
      <div class="faq-grid rv">
        ${faq.items.map((item) => /* html */ `
        <details class="faq-item">
          <summary><span class="faq-q">${esc(item.q)}</span></summary>
          <p>${esc(item.a)}</p>
        </details>
        `).join('')}
      </div>
    </div>
  </section>`
}

/* ── Footer ────────────────────────────────────────────────── */

function renderFooter() {
  return /* html */ `
  <footer id="footer" class="site-footer">
    <div class="finner">
      <span>${t.footer.copyright}</span>
      <div class="fr">
        <a href="https://x.com/WiFiLens" aria-label="X (Twitter) — @WiFiLens">
          <svg width="15" height="15" viewBox="0 0 24 24" fill="currentColor"><path d="M18.244 2.25h3.308l-7.227 8.26 8.502 11.24H16.17l-5.214-6.817L4.99 21.75H1.68l7.73-8.835L1.254 2.25H8.08l4.713 6.231zm-1.161 17.52h1.833L7.084 4.126H5.117z"/></svg>
          <span>${t.footer.x}</span>
        </a>
        <a href="mailto:${t.footer.email}">${t.footer.email}</a>
      </div>
    </div>
  </footer>`
}

/* ── Back to top ───────────────────────────────────────────── */

function renderBTT() {
  return /* html */ `
  <button id="btt" aria-label="${esc(t.a11y.backToTop)}">
    ${bttSVG}
  </button>`
}

/* ── Hydrate ───────────────────────────────────────────────── */

function hydrateUI() {
  // ── Hero spectrum canvas animation ─────────────────────────
  const hero = document.getElementById('hero')!
  const canvas = document.getElementById('hero-canvas') as HTMLCanvasElement
  if (canvas) {
    const ctx = canvas.getContext('2d')!
    const BAR_COUNT = 80
    const barHeights = new Float32Array(BAR_COUNT)
    const barTargets = new Float32Array(BAR_COUNT)

    function resize() {
      const rect = hero.getBoundingClientRect()
      const dpr = Math.min(window.devicePixelRatio || 1, 2)
      canvas.width = rect.width * dpr
      canvas.height = rect.height * dpr
      canvas.style.width = rect.width + 'px'
      canvas.style.height = rect.height + 'px'
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0)
    }

    function initBars() {
      for (let i = 0; i < BAR_COUNT; i++) {
        barHeights[i] = Math.random() * 0.2
        barTargets[i] = Math.random() * 0.25
      }
    }

    const accentA = (a: number) => `rgba(76,201,200,${a})`
    const accentB = (a: number) => `rgba(90,215,195,${a})`

    function draw() {
      const w = canvas.width / Math.min(window.devicePixelRatio || 1, 2)
      const h = canvas.height / Math.min(window.devicePixelRatio || 1, 2)
      ctx.clearRect(0, 0, w, h)

      const barAreaTop = h * 0.74
      const barAreaH = h * 0.26
      const barX0 = w * 0.02
      const barAreaW = w * 0.96
      const totalGap = barAreaW * 0.15
      const barW = (barAreaW - totalGap) / BAR_COUNT
      const barGap = totalGap / BAR_COUNT

      for (let i = 0; i < BAR_COUNT; i++) {
        if (Math.random() < 0.05) {
          barTargets[i] = Math.random() * 0.88 + 0.06
        }
        barHeights[i] += (barTargets[i] - barHeights[i]) * 0.08
      }

      for (let i = 0; i < BAR_COUNT; i++) {
        const bh = barHeights[i] * barAreaH
        if (bh < 2) continue
        const bx = barX0 + i * (barW + barGap)
        const by = barAreaTop + barAreaH - bh

        const band = Math.floor(i / (BAR_COUNT / 3))
        const g = band === 0 ? accentA : band === 1 ? accentB : accentA
        const baseAlpha = band === 2 ? 0.04 : 0.08
        const alpha = Math.min(baseAlpha + barHeights[i] * 0.32, 0.4)

        const grad = ctx.createLinearGradient(bx, by, bx, barAreaTop + barAreaH)
        grad.addColorStop(0, g(alpha))
        grad.addColorStop(1, g(0))
        ctx.fillStyle = grad
        ctx.fillRect(bx, by, barW, bh)
      }

      ctx.strokeStyle = accentA(0.05)
      ctx.lineWidth = 0.5
      ctx.setLineDash([4, 18])
      ctx.beginPath()
      ctx.moveTo(barX0, barAreaTop + barAreaH)
      ctx.lineTo(barX0 + barAreaW, barAreaTop + barAreaH)
      ctx.stroke()
      ctx.setLineDash([])

      requestAnimationFrame(draw)
    }

    resize()
    initBars()
    const prefersReduced = window.matchMedia('(prefers-reduced-motion: reduce)')
    if (!prefersReduced.matches) requestAnimationFrame(draw)
    prefersReduced.addEventListener('change', e => {
      if (e.matches) { ctx.clearRect(0, 0, canvas.width, canvas.height) }
      else { resize(); initBars(); requestAnimationFrame(draw) }
    })

    const roResize = new ResizeObserver(() => { resize(); initBars() })
    roResize.observe(hero)
  }

  // ── Scroll reveal ──────────────────────────────────────────
  const ro = new IntersectionObserver(
    (entries) => {
      entries.forEach(e => {
        if (e.isIntersecting) {
          e.target.classList.add('in')
          ro.unobserve(e.target)
        }
      })
    },
    { threshold: 0.08, rootMargin: '0px 0px -30px 0px' }
  )
  document.querySelectorAll('.rv, .rv-s').forEach(el => ro.observe(el))

  // ── Stats staggered animation ──────────────────────────────
  const statsEl = document.getElementById('stats')
  if (statsEl) {
    const statItems = statsEl.querySelectorAll('.stat-cell')
    const statObs = new IntersectionObserver(
      (entries) => {
        entries.forEach(e => {
          if (e.isIntersecting) {
            statItems.forEach((item, i) => {
              setTimeout(() => item.classList.add('revealed'), i * 120)
            })
            statObs.unobserve(e.target)
          }
        })
      },
      { threshold: 0.5 }
    )
    statObs.observe(statsEl)
  }

  // ── Language switcher ──────────────────────────────────────
  document.querySelectorAll<HTMLButtonElement>('.lang-option').forEach(btn => {
    btn.addEventListener('click', async () => {
      const target = btn.dataset.lang as SupportedLocale
      if (target === lng) return
      await switchTo(target)
    })
  })
  updateLangIndicator()
}

async function switchTo(target: SupportedLocale) {
  const scrollY = window.scrollY
  await changeLanguage(target)
  lng = target
  loadTranslation(lng)
  document.documentElement.setAttribute('lang', lng)

  // Update page title and meta description
  document.title = t.meta.title
  const metaDesc = document.querySelector<HTMLMetaElement>('meta[name="description"]')
  if (metaDesc) metaDesc.content = t.meta.description

  const app = document.getElementById('app')!
  app.style.opacity = '0'
  app.style.transition = 'opacity 100ms ease'

  await new Promise(r => setTimeout(r, 100))
  renderAll()
  hydrateUI()
  window.scrollTo({ top: scrollY, behavior: 'instant' as ScrollBehavior })

  requestAnimationFrame(() => { app.style.opacity = '1' })
}

function updateLangIndicator() {
  document.querySelectorAll('.lang-switch').forEach(container => {
    const active = container.querySelector<HTMLButtonElement>(`.lang-option[data-lang="${lng}"]`)
    if (!active) return
    const indicator = container.querySelector<HTMLElement>('.lang-indicator')
    if (!indicator) return
    const cr = container.getBoundingClientRect()
    const ar = active.getBoundingClientRect()
    indicator.style.left = `${ar.left - cr.left}px`
    indicator.style.width = `${ar.width}px`
  })
}

async function init() {
  await ready
  lng = resolveLanguage()
  loadTranslation(lng)
  document.documentElement.setAttribute('lang', lng)

  // Set initial page title and meta description
  document.title = t.meta.title
  const metaDesc = document.querySelector<HTMLMetaElement>('meta[name="description"]')
  if (metaDesc) metaDesc.content = t.meta.description

  renderAll()
  hydrateUI()

  // ── Window-level scroll effects ──────────────────────────────
  window.addEventListener('scroll', () => {
    const navEl = document.getElementById('nav')
    if (navEl) {
      const y = window.scrollY
      navEl.classList.toggle('scrolled', y > 20)
    }

    const topBtn = document.getElementById('btt')
    if (topBtn) {
      topBtn.classList.toggle('visible', window.scrollY > 500)
    }
  }, { passive: true })

  // ── Back to top click ───────────────────────────────────────
  document.getElementById('btt')?.addEventListener('click', () => {
    const prefersReduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches
    window.scrollTo({ top: 0, behavior: prefersReduced ? 'auto' : 'smooth' })
  })

  // ── Mobile hamburger menu ───────────────────────────────────
  const navEl = document.getElementById('nav')
  if (navEl) {
    const hamburger = navEl.querySelector('.hamburger')
    if (hamburger) {
      hamburger.addEventListener('click', () => {
        const open = navEl.classList.toggle('mobile-open')
        hamburger.classList.toggle('open', open)
        hamburger.setAttribute('aria-expanded', String(open))
        document.body.classList.toggle('menu-open', open)
      })
      navEl.querySelectorAll('.links a[href^="#"]').forEach(a => {
        a.addEventListener('click', () => {
          navEl.classList.remove('mobile-open')
          hamburger.classList.remove('open')
          hamburger.setAttribute('aria-expanded', 'false')
          document.body.classList.remove('menu-open')
        })
      })
    }
  }

  window.addEventListener('resize', updateLangIndicator, { passive: true })
  document.fonts.ready.then(updateLangIndicator)
}

init()
