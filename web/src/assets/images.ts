import overview from './screenshots/overview.png'
import spectrum from './screenshots/spectrum.png'
import channels from './screenshots/channels.png'
import table from './screenshots/table.png'
import roaming from './screenshots/roaming.png'
import interfaces from './screenshots/interfaces.png'
import icon from './icon.png'

export const screenshots = {
  '/screenshots/overview.png': overview,
  '/screenshots/spectrum.png': spectrum,
  '/screenshots/channels.png': channels,
  '/screenshots/table.png': table,
  '/screenshots/roaming.png': roaming,
  '/screenshots/interfaces.png': interfaces,
} as const

export function getScreenshot(path: string) {
  return screenshots[path as keyof typeof screenshots]
}

export { icon }
