import i18next from 'i18next'
import LanguageDetector from 'i18next-browser-languagedetector'
import { en } from './en'
import { ja } from './ja'
import { zhHans } from './zh-Hans'
import { es } from './es'
import { de } from './de'

const ready = i18next
  .use(LanguageDetector)
  .init({
    resources: {
      en: { translation: en },
      ja: { translation: ja },
      'zh-Hans': { translation: zhHans },
      es: { translation: es },
      de: { translation: de },
    },
    fallbackLng: 'en',
    detection: {
      order: ['localStorage', 'navigator'],
      lookupLocalStorage: 'wifi-lens-locale',
      caches: ['localStorage'],
    },
  })

export type SupportedLocale = 'en' | 'ja' | 'zh-Hans' | 'es' | 'de'

export async function changeLanguage(lng: SupportedLocale) {
  await i18next.changeLanguage(lng)
}

export { ready }
export default i18next
