export interface Palette {
  label: string
  purple: string
  purpleDark: string
  pink: string
  yellow: string
}

export const PALETTES: Record<string, Palette> = {
  pop: {
    label: 'Pop viola',
    purple: '#aa3bff',
    purpleDark: '#7c1fd4',
    pink: '#ff5da2',
    yellow: '#ffcf4d',
  },
  ocean: {
    label: 'Oceano',
    purple: '#2b6cff',
    purpleDark: '#1d4fd1',
    pink: '#22d3c5',
    yellow: '#ffd166',
  },
  sunset: {
    label: 'Tramonto',
    purple: '#ff7a3c',
    purpleDark: '#dd5518',
    pink: '#ff4d8d',
    yellow: '#ffd166',
  },
  forest: {
    label: 'Foresta',
    purple: '#22c55e',
    purpleDark: '#15803d',
    pink: '#a3e635',
    yellow: '#fb923c',
  },
  mono: {
    label: 'Mono',
    purple: '#3f3f46',
    purpleDark: '#18181b',
    pink: '#71717a',
    yellow: '#facc15',
  },
}

export interface FontOption {
  label: string
  family: string
}

export const FONTS: Record<string, FontOption> = {
  baloo: { label: 'Baloo (predefinito)', family: "'Baloo 2', 'Segoe UI', system-ui, sans-serif" },
  poppins: { label: 'Poppins', family: "'Poppins', 'Segoe UI', system-ui, sans-serif" },
  fredoka: { label: 'Fredoka', family: "'Fredoka', 'Segoe UI', system-ui, sans-serif" },
  spacegrotesk: { label: 'Space Grotesk', family: "'Space Grotesk', 'Segoe UI', system-ui, sans-serif" },
}

export function applyTheme(paletteKey: string, fontKey: string) {
  const palette = PALETTES[paletteKey] ?? PALETTES.pop
  const font = FONTS[fontKey] ?? FONTS.baloo
  const root = document.documentElement.style
  root.setProperty('--color-pop-purple', palette.purple)
  root.setProperty('--color-pop-purple-dark', palette.purpleDark)
  root.setProperty('--color-pop-pink', palette.pink)
  root.setProperty('--color-pop-yellow', palette.yellow)
  root.setProperty('--font-display', font.family)
}
