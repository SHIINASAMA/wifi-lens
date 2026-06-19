/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{js,ts,jsx,tsx}'],
  theme: {
    extend: {
      colors: {
        accent: {
          DEFAULT: 'oklch(75% 0.19 190)',
          glow:   'oklch(75% 0.19 190 / 0.15)',
          muted:  'oklch(65% 0.08 190)',
          surface:'oklch(75% 0.19 190 / 0.06)',
          border: 'oklch(75% 0.19 190 / 0.12)',
        },
        surface: {
          DEFAULT: 'oklch(18% 0.005 260)',
          raised:  'oklch(22% 0.005 260)',
          border:  'oklch(28% 0.005 260)',
          hover:   'oklch(25% 0.005 260)',
        },
      },
      fontFamily: {
        sans:    ['Inter', 'system-ui', '-apple-system', 'sans-serif'],
        display: ['Satoshi', 'Inter', 'system-ui', '-apple-system', 'sans-serif'],
        mono:    ['JetBrains Mono', 'SF Mono', 'monospace'],
      },
      fontSize: {
        'hero':      ['clamp(3.5rem, 8vw, 8rem)',   { lineHeight: '0.92', letterSpacing: '-0.03em', fontWeight: '900' }],
        'hero-line': ['clamp(2.5rem, 6vw, 5rem)',    { lineHeight: '0.95', letterSpacing: '-0.02em', fontWeight: '400' }],
        'section':   ['clamp(2rem, 5vw, 3.5rem)',    { lineHeight: '1.08', letterSpacing: '-0.02em', fontWeight: '700' }],
      },
    },
  },
  plugins: [],
}
