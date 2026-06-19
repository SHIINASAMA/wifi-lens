import { defineConfig } from 'vite'

export default defineConfig({
  base: '/wifi-lens/',
  build: {
    outDir: '_site',
    emptyOutDir: true,
    target: 'es2022',
  },
  optimizeDeps: {
    esbuildOptions: {
      target: 'es2022',
    },
  },
})
