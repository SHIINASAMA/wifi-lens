import { defineConfig } from 'astro/config'
import sitemap from '@astrojs/sitemap'

export default defineConfig({
  site: 'https://shiinasama.github.io',
  base: '/wifi-lens',
  output: 'static',
  integrations: [sitemap()],
})
