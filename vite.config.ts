import { defineConfig } from 'vite'

export default defineConfig({
  base: '/wifi-lens/',
  build: {
    outDir: '_site',
    emptyOutDir: true,
    target: 'esnext',
  },
  esbuild: {
    target: 'esnext',
  },
  optimizeDeps: {
    esbuildOptions: {
      target: 'esnext',
    },
  },
})
