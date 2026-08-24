import { useState } from 'react'
import type { FormEvent } from 'react'
import { useNavigate } from 'react-router-dom'
import { useCircles } from '../hooks/useCircles'
import { Card } from '../components/ui/Card'
import { Button } from '../components/ui/Button'
import { pillClass } from '../lib/style'
import type { CircleCategory, CircleType } from '../types/database'

const inputClasses =
  'rounded-xl border-2 border-neutral-200 px-4 py-2.5 outline-none transition focus:border-pop-purple dark:border-neutral-700 dark:bg-neutral-800'

const CATEGORY_OPTIONS: { value: CircleCategory; label: string }[] = [
  { value: 'amici', label: '👥 Amici' },
  { value: 'normal', label: '🎲 Normal' },
  { value: 'hot', label: '🔥 Hot' },
]

const TYPE_OPTIONS: { value: CircleType; label: string; description: string }[] = [
  { value: 'photo', label: '📷 Foto', description: 'Prompt del giorno, scatta e vota la foto migliore' },
  { value: 'gif', label: '🎬 Gif', description: 'Frase del giorno, rispondi con una GIF e vota la migliore' },
]

export function Onboarding() {
  const navigate = useNavigate()
  const { createCircle, joinCircleByCode } = useCircles()

  const [circleName, setCircleName] = useState('')
  const [circleType, setCircleType] = useState<CircleType>('photo')
  const [circleCategory, setCircleCategory] = useState<CircleCategory>('normal')
  const [inviteCode, setInviteCode] = useState('')
  const [creating, setCreating] = useState(false)
  const [joining, setJoining] = useState(false)
  const [createError, setCreateError] = useState<string | null>(null)
  const [joinError, setJoinError] = useState<string | null>(null)

  async function handleCreate(e: FormEvent) {
    e.preventDefault()
    setCreateError(null)
    setCreating(true)
    try {
      const circle = await createCircle(circleName.trim(), circleCategory, 120, circleType)
      navigate(`/circles/${circle.id}`)
    } catch (err) {
      setCreateError(err instanceof Error ? err.message : 'Impossibile creare la cerchia')
    } finally {
      setCreating(false)
    }
  }

  async function handleJoin(e: FormEvent) {
    e.preventDefault()
    setJoinError(null)
    setJoining(true)
    try {
      const circle = await joinCircleByCode(inviteCode)
      navigate(`/circles/${circle.id}`)
    } catch (err) {
      setJoinError(err instanceof Error ? err.message : 'Codice non valido')
    } finally {
      setJoining(false)
    }
  }

  return (
    <div className="mx-auto flex max-w-2xl flex-col gap-6 px-4 py-10">
      <div className="animate-fade-in-up text-center">
        <h1 className="font-display text-4xl font-bold text-pop-purple">Entra in una cerchia 👋</h1>
        <p className="mt-2 text-neutral-500">
          Crea la tua cerchia di amici o unisciti a una esistente con un codice invito.
        </p>
      </div>

      <div className="grid gap-6 sm:grid-cols-2">
        <Card
          as="form"
          onSubmit={handleCreate}
          className="animate-pop-in flex flex-col gap-3 border-t-4! border-t-pop-purple!"
        >
          <span className="text-3xl">✨</span>
          <h2 className="font-display text-xl font-bold">Crea una cerchia</h2>
          <input
            required
            minLength={2}
            value={circleName}
            onChange={(e) => setCircleName(e.target.value)}
            placeholder="Es. Gli Amici del Bar"
            className={inputClasses}
          />

          <div className="flex flex-col gap-1.5">
            {TYPE_OPTIONS.map((opt) => (
              <button
                key={opt.value}
                type="button"
                onClick={() => setCircleType(opt.value)}
                className={`rounded-xl border-2 px-3 py-2 text-left transition ${
                  circleType === opt.value
                    ? 'border-pop-purple bg-pop-purple/5'
                    : 'border-neutral-200 dark:border-neutral-700'
                }`}
              >
                <span className="text-sm font-semibold">{opt.label}</span>
                <p className="text-xs text-neutral-500">{opt.description}</p>
              </button>
            ))}
          </div>

          {circleType === 'photo' && (
            <div className="flex gap-2">
              {CATEGORY_OPTIONS.map((opt) => (
                <button
                  key={opt.value}
                  type="button"
                  onClick={() => setCircleCategory(opt.value)}
                  className={`rounded-full px-3 py-1.5 text-xs font-semibold transition ${pillClass(circleCategory === opt.value)}`}
                >
                  {opt.label}
                </button>
              ))}
            </div>
          )}
          {createError && <p className="text-sm text-red-500">{createError}</p>}
          <Button type="submit" disabled={creating} className="mt-1">
            {creating ? 'Creazione...' : 'Crea'}
          </Button>
        </Card>

        <Card
          as="form"
          onSubmit={handleJoin}
          className="animate-pop-in flex flex-col gap-3 border-t-4! border-t-pop-pink!"
          style={{ animationDelay: '80ms' }}
        >
          <span className="text-3xl">🔗</span>
          <h2 className="font-display text-xl font-bold">Unisciti con un codice</h2>
          <input
            required
            value={inviteCode}
            onChange={(e) => setInviteCode(e.target.value.toUpperCase())}
            placeholder="Es. A1B2C3"
            className={`${inputClasses} uppercase`}
          />
          {joinError && <p className="text-sm text-red-500">{joinError}</p>}
          <Button type="submit" variant="secondary" disabled={joining} className="mt-1">
            {joining ? 'Verifica...' : 'Unisciti'}
          </Button>
        </Card>
      </div>
    </div>
  )
}
