import { useRef, useState } from 'react'
import { Link } from 'react-router-dom'
import { useAuth } from '../hooks/useAuth'
import { useProfile } from '../hooks/useProfile'
import { supabase } from '../lib/supabase'
import { resizeImageToSquareJpeg } from '../lib/resizeImage'
import { PALETTES, FONTS, applyTheme } from '../lib/themes'
import type { Gender } from '../types/database'
import { Card } from '../components/ui/Card'
import { Avatar } from '../components/ui/Avatar'
import { pillClass } from '../lib/style'

const GENDER_OPTIONS: { value: Gender; label: string }[] = [
  { value: 'uomo', label: 'Uomo' },
  { value: 'donna', label: 'Donna' },
  { value: 'altro', label: 'Altro' },
]

export function Profile() {
  const { user } = useAuth()
  const { profile, loading, updateProfile } = useProfile()
  const fileInputRef = useRef<HTMLInputElement>(null)
  const [uploading, setUploading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const username = (user?.user_metadata?.username as string | undefined) ?? profile?.username ?? 'amico'

  async function handleFileChange(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0]
    if (!file || !user) return
    setUploading(true)
    setError(null)
    try {
      const blob = await resizeImageToSquareJpeg(file)
      const path = `${user.id}/avatar.jpg`
      const { error: uploadError } = await supabase.storage
        .from('avatars')
        .upload(path, blob, { contentType: 'image/jpeg', upsert: true })
      if (uploadError) throw uploadError

      const { data } = supabase.storage.from('avatars').getPublicUrl(path)
      await updateProfile({ avatar_url: `${data.publicUrl}?v=${Date.now()}` })
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Impossibile caricare la foto')
    } finally {
      setUploading(false)
      if (fileInputRef.current) fileInputRef.current.value = ''
    }
  }

  async function handleGenderChange(gender: Gender) {
    try {
      await updateProfile({ gender })
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Errore, riprova')
    }
  }

  async function handlePaletteChange(key: string) {
    if (!profile) return
    applyTheme(key, profile.theme_font)
    try {
      await updateProfile({ theme_palette: key })
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Errore, riprova')
    }
  }

  async function handleFontChange(key: string) {
    if (!profile) return
    applyTheme(profile.theme_palette, key)
    try {
      await updateProfile({ theme_font: key })
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Errore, riprova')
    }
  }

  if (loading || !profile) {
    return <div className="p-10 text-center text-neutral-500">Carico il profilo...</div>
  }

  return (
    <div className="mx-auto flex max-w-2xl flex-col gap-6 px-4 py-10">
      <Link to="/" className="text-sm font-medium text-neutral-500 hover:underline">
        ← Le tue cerchie
      </Link>

      <div className="animate-fade-in-up">
        <h1 className="font-display text-3xl font-bold text-pop-purple">Il tuo profilo</h1>
      </div>

      {error && <p className="text-sm text-red-500">{error}</p>}

      <Card className="flex items-center gap-4">
        <Avatar username={username} avatarUrl={profile.avatar_url} size={72} />
        <div>
          <p className="font-display font-bold">{username}</p>
          <button
            type="button"
            onClick={() => fileInputRef.current?.click()}
            disabled={uploading}
            className="glass mt-1 rounded-full px-3 py-1.5 text-xs font-semibold text-neutral-700 transition hover:bg-white/80 disabled:opacity-50 dark:text-neutral-200 dark:hover:bg-neutral-800/70"
          >
            {uploading ? 'Caricamento...' : 'Cambia foto'}
          </button>
          <input
            ref={fileInputRef}
            type="file"
            accept="image/*"
            onChange={handleFileChange}
            className="hidden"
          />
        </div>
      </Card>

      <Card>
        <h2 className="mb-3 font-display text-lg font-bold">Genere</h2>
        <p className="mb-3 text-xs text-neutral-400">
          Serve solo per proporre in futuro domande differenziate. Facoltativo.
        </p>
        <div className="flex gap-2">
          {GENDER_OPTIONS.map((opt) => (
            <button
              key={opt.value}
              type="button"
              onClick={() => handleGenderChange(opt.value)}
              className={`rounded-full px-4 py-2 text-sm font-semibold transition ${pillClass(profile.gender === opt.value)}`}
            >
              {opt.label}
            </button>
          ))}
        </div>
      </Card>

      <Card>
        <h2 className="mb-3 font-display text-lg font-bold">Palette colori</h2>
        <div className="grid grid-cols-2 gap-3 sm:grid-cols-3">
          {Object.entries(PALETTES).map(([key, palette]) => (
            <button
              key={key}
              type="button"
              onClick={() => handlePaletteChange(key)}
              className={`flex items-center gap-2 rounded-2xl p-2.5 text-left transition ${
                profile.theme_palette === key
                  ? 'shadow-glow-sm ring-2 ring-pop-purple'
                  : 'border border-neutral-200 hover:border-neutral-300 dark:border-neutral-700'
              }`}
            >
              <span
                className="h-8 w-8 shrink-0 rounded-full border border-black/10"
                style={{
                  background: `linear-gradient(135deg, ${palette.purple}, ${palette.pink} 60%, ${palette.yellow})`,
                }}
              />
              <span className="text-sm font-semibold">{palette.label}</span>
            </button>
          ))}
        </div>
      </Card>

      <Card>
        <h2 className="mb-3 font-display text-lg font-bold">Font</h2>
        <div className="flex flex-col gap-2">
          {Object.entries(FONTS).map(([key, font]) => (
            <button
              key={key}
              type="button"
              onClick={() => handleFontChange(key)}
              className={`flex items-center justify-between rounded-2xl px-4 py-3 text-left transition ${
                profile.theme_font === key
                  ? 'shadow-glow-sm bg-pop-purple/5 ring-2 ring-pop-purple'
                  : 'border border-neutral-200 hover:border-neutral-300 dark:border-neutral-700'
              }`}
            >
              <span className="text-sm text-neutral-500">{font.label}</span>
              <span className="text-xl font-bold" style={{ fontFamily: font.family }}>
                POP 📸
              </span>
            </button>
          ))}
        </div>
      </Card>
    </div>
  )
}
