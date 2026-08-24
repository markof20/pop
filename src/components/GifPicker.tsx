import { useEffect, useState } from 'react'
import type { FormEvent } from 'react'
import { searchGifs, trendingGifs } from '../lib/giphy'
import type { GifResult } from '../lib/giphy'
import { EmptyState } from './ui/EmptyState'

interface GifPickerProps {
  onSelect: (gif: GifResult) => void
  onClose: () => void
  busy?: boolean
}

export function GifPicker({ onSelect, onClose, busy = false }: GifPickerProps) {
  const [query, setQuery] = useState('')
  const [gifs, setGifs] = useState<GifResult[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    let cancelled = false
    setLoading(true)
    setError(null)
    const fetcher = query.trim() ? searchGifs(query.trim()) : trendingGifs()
    fetcher
      .then((data) => {
        if (!cancelled) setGifs(data)
      })
      .catch((err) => {
        if (!cancelled) setError(err instanceof Error ? err.message : 'Errore, riprova')
      })
      .finally(() => {
        if (!cancelled) setLoading(false)
      })
    return () => {
      cancelled = true
    }
  }, [query])

  function handleSubmit(e: FormEvent) {
    e.preventDefault()
  }

  return (
    <div
      className="fixed inset-0 z-50 flex items-end justify-center bg-black/50 p-0 sm:items-center sm:p-4"
      onClick={onClose}
    >
      <div
        className="glass shadow-glow flex max-h-[85vh] w-full max-w-lg flex-col rounded-t-3xl p-5 sm:rounded-3xl"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="mb-3 flex items-center justify-between">
          <h2 className="font-display text-lg font-bold">Cerca una GIF</h2>
          <button
            onClick={onClose}
            className="text-neutral-400 hover:text-neutral-600 dark:hover:text-neutral-200"
          >
            ✕
          </button>
        </div>

        <form onSubmit={handleSubmit} className="mb-4">
          <input
            autoFocus
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="Cerca su Giphy..."
            className="w-full rounded-xl border-2 border-neutral-200 px-4 py-2.5 outline-none focus:border-pop-purple dark:border-neutral-700 dark:bg-neutral-800"
          />
        </form>

        <div className="flex-1 overflow-y-auto">
          {error && <p className="mb-3 text-sm text-red-600">{error}</p>}
          {loading ? (
            <p className="text-center text-sm text-neutral-500">Carico GIF...</p>
          ) : gifs.length === 0 ? (
            <EmptyState icon="🔍" text="Nessuna GIF trovata" />
          ) : (
            <div className="grid grid-cols-2 gap-3 sm:grid-cols-3">
              {gifs.map((gif) => (
                <button
                  key={gif.id}
                  disabled={busy}
                  onClick={() => onSelect(gif)}
                  className="shadow-glow-sm overflow-hidden rounded-2xl transition hover:-translate-y-1 active:scale-95 disabled:opacity-50"
                >
                  <img src={gif.previewUrl} alt="" className="aspect-square w-full object-cover" />
                </button>
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  )
}
