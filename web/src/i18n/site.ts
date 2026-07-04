import { de } from './de'
import { en } from './en'
import { es } from './es'
import { ja } from './ja'
import { zhHans } from './zh-Hans'

export const locales = {
  en,
  de,
  es,
  ja,
  'zh-Hans': zhHans,
} as const

export type SupportedLocale = keyof typeof locales
export type SiteDictionary = typeof en

export const defaultLocale: SupportedLocale = 'en'
export const localeOrder: SupportedLocale[] = ['en', 'de', 'es', 'ja', 'zh-Hans']
export const localeLabels: Record<SupportedLocale, string> = {
  en: 'English',
  de: 'Deutsch',
  es: 'Español',
  ja: '日本語',
  'zh-Hans': '中文',
}

export const pageSlugs = {
  home: '',
  features: 'features',
  mcp: 'ai-mcp',
  faq: 'faq',
  privacy: 'privacy',
  download: 'download',
  changelog: 'changelog',
} as const

export type PageKey = keyof typeof pageSlugs

export function isSupportedLocale(value: string): value is SupportedLocale {
  return value in locales
}

export function getDictionary(locale: SupportedLocale): SiteDictionary {
  return locales[locale]
}

export function withBase(path: string): string {
  if (/^(https?:|mailto:|#)/.test(path)) return path
  const base = import.meta.env.BASE_URL === '/' ? '' : import.meta.env.BASE_URL.replace(/\/$/, '')
  const normalized = path.startsWith('/') ? path : `/${path}`
  return `${base}${normalized}`
}

export function getPagePath(locale: SupportedLocale, page: PageKey): string {
  const prefix = locale === defaultLocale ? '' : `/${locale}`
  const slug = pageSlugs[page]
  const pathname = slug ? `${prefix}/${slug}/` : `${prefix}/`
  return withBase(pathname)
}

export function getHomeAnchor(locale: SupportedLocale, anchor: string): string {
  return `${getPagePath(locale, 'home')}#${anchor}`
}

export function getAlternateLinks(page: PageKey) {
  return localeOrder.map((locale) => ({
    locale,
    hrefLang: locale === 'zh-Hans' ? 'zh-Hans' : locale,
    href: getPagePath(locale, page),
  }))
}
