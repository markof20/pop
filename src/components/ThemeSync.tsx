import { useEffect } from 'react'
import { useProfile } from '../hooks/useProfile'
import { applyTheme } from '../lib/themes'

export function ThemeSync() {
  const { profile } = useProfile()

  useEffect(() => {
    if (profile) applyTheme(profile.theme_palette, profile.theme_font)
  }, [profile])

  return null
}
