import { useEffect, useState } from 'react'
import type { FormEvent } from 'react'
import { Link, useNavigate, useParams } from 'react-router-dom'
import { useAuth } from '../hooks/useAuth'
import { useDailyChallenge } from '../hooks/useDailyChallenge'
import { usePhotos } from '../hooks/usePhotos'
import { useChallengeResults } from '../hooks/useChallengeResults'
import { useWinnerDecision } from '../hooks/useWinnerDecision'
import { Card } from '../components/ui/Card'
import { Button } from '../components/ui/Button'
import { PhotoCard } from '../components/ui/PhotoCard'

function useCountdown(target: Date | null) {
  const [label, setLabel] = useState('')

  useEffect(() => {
    if (!target) return
    const tick = () => {
      const diffMs = target.getTime() - Date.now()
      if (diffMs <= 0) {
        setLabel('Finestra chiusa')
        return
      }
      const totalSeconds = Math.floor(diffMs / 1000)
      const h = Math.floor(totalSeconds / 3600)
      const m = Math.floor((totalSeconds % 3600) / 60)
      const s = totalSeconds % 60
      setLabel(h > 0 ? `${h}h ${m}m` : `${m}m ${s}s`)
    }
    tick()
    const interval = setInterval(tick, 1000)
    return () => clearInterval(interval)
  }, [target])

  return label
}

function PendingWinBanner({ circleId }: { circleId: string }) {
  const { pendingWin, loading, submitting, chooseOptionA, chooseOptionB } = useWinnerDecision(circleId)
  const [choosingA, setChoosingA] = useState(false)
  const [customPrompt, setCustomPrompt] = useState('')
  const [error, setError] = useState<string | null>(null)

  if (loading || !pendingWin) return null

  const decideByLabel = new Date(pendingWin.decide_by_at).toLocaleTimeString('it-IT', {
    hour: '2-digit',
    minute: '2-digit',
  })

  async function handleOptionB() {
    setError(null)
    try {
      await chooseOptionB()
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Errore, riprova')
    }
  }

  async function handleSubmitA(e: FormEvent) {
    e.preventDefault()
    setError(null)
    try {
      await chooseOptionA(customPrompt.trim())
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Errore, riprova')
    }
  }

  return (
    <Card className="animate-bounce-in bg-gradient-to-br from-pop-yellow/25 to-pop-yellow/5">
      <p className="font-display text-lg font-bold text-neutral-800 dark:text-neutral-100">
        🏆 Hai vinto ieri!
      </p>
      <p className="mt-1 text-sm italic text-neutral-600 dark:text-neutral-300">
        "{pendingWin.prompt_text}"
      </p>
      <p className="mt-2 text-sm font-medium text-neutral-700 dark:text-neutral-200">
        Cosa vuoi fare oggi?
      </p>

      {error && <p className="mt-2 text-sm text-red-600">{error}</p>}

      {!choosingA ? (
        <div className="mt-3 flex flex-col gap-2 sm:flex-row">
          <Button onClick={() => setChoosingA(true)} disabled={submitting} className="flex-1">
            🎬 Propongo io il prompt
          </Button>
          <Button onClick={handleOptionB} disabled={submitting} variant="outline" className="flex-1">
            🎲 Lascia scegliere all'app
          </Button>
        </div>
      ) : (
        <form onSubmit={handleSubmitA} className="mt-3 flex flex-col gap-2">
          <input
            required
            value={customPrompt}
            onChange={(e) => setCustomPrompt(e.target.value)}
            placeholder="Scrivi il prompt di oggi..."
            className="rounded-xl border-2 border-neutral-200 px-4 py-2.5 outline-none focus:border-pop-purple dark:border-neutral-700 dark:bg-neutral-800"
          />
          <div className="flex gap-2">
            <Button type="submit" disabled={submitting}>
              {submitting ? 'Invio...' : 'Conferma'}
            </Button>
            <Button type="button" variant="ghost" onClick={() => setChoosingA(false)} disabled={submitting}>
              Annulla
            </Button>
          </div>
        </form>
      )}

      <p className="mt-3 text-xs text-neutral-500">Hai tempo fino alle {decideByLabel}, poi si sceglie da sé</p>
    </Card>
  )
}

export function CircleFeed() {
  const { id } = useParams<{ id: string }>()
  const navigate = useNavigate()
  const { user } = useAuth()
  const {
    challenge,
    loading: challengeLoading,
    error: challengeError,
    isWindowOpen,
    windowEndAt,
  } = useDailyChallenge(id)

  const amGameMaster = !!challenge && challenge.proposed_by === user?.id

  const { myPhoto, gridPhotos, loading: photosLoading } = usePhotos(
    id,
    challenge?.id,
    challenge?.challenge_date,
    { bypassGate: amGameMaster },
  )
  const countdown = useCountdown(windowEndAt)
  const {
    challenge: resultsChallenge,
    winner,
    wasTie,
    results,
    loading: resultsLoading,
  } = useChallengeResults(id)

  if (challengeLoading) {
    return <div className="p-10 text-center text-neutral-500">Preparo la sfida di oggi... 🎲</div>
  }

  if (challengeError || !challenge) {
    return (
      <div className="p-10 text-center text-red-500">
        {challengeError ?? 'Impossibile caricare la sfida'}
      </div>
    )
  }

  return (
    <div className="relative mx-auto flex max-w-2xl flex-col gap-6 overflow-x-hidden px-4 py-8">
      <div
        aria-hidden
        className="animate-float pointer-events-none fixed -top-24 -right-24 h-80 w-80 rounded-full bg-pop-pink/20 blur-3xl"
      />
      <div
        aria-hidden
        className="animate-float pointer-events-none fixed -bottom-24 -left-24 h-80 w-80 rounded-full bg-pop-purple/20 blur-3xl"
        style={{ animationDelay: '2.5s' }}
      />

      <div className="relative flex items-center justify-between">
        <Link to="/" className="text-sm font-medium text-neutral-500 hover:underline">
          ← Cerchie
        </Link>
        <div className="flex items-center gap-4">
          <Link
            to={`/circles/${id}/party`}
            className="text-sm font-medium text-neutral-500 hover:underline"
          >
            🎉 Party
          </Link>
          <Link
            to={`/circles/${id}/settings`}
            className="text-sm font-medium text-neutral-500 hover:underline"
          >
            Impostazioni →
          </Link>
        </div>
      </div>

      {id && <PendingWinBanner circleId={id} />}

      {!resultsLoading && resultsChallenge && (
        <Card className="animate-fade-in-up border-l-4! border-l-pop-yellow!">
          <p className="text-xs font-bold uppercase tracking-wide text-neutral-400">Ultimi risultati</p>
          <p className="mb-2 text-sm italic text-neutral-500">"{resultsChallenge.prompt_text}"</p>
          {winner ? (
            <button
              onClick={() => navigate(`/circles/${id}/photos/${winner.photo_id}`)}
              className="flex w-full items-center gap-3 text-left transition active:scale-[0.98]"
            >
              {winner.signed_url && (
                <img
                  src={winner.signed_url}
                  alt={winner.username}
                  className="h-16 w-16 rounded-2xl object-cover shadow-md"
                />
              )}
              <div>
                <p className="font-display font-bold">🏆 {winner.username}</p>
                <p className="text-xs text-neutral-500">
                  {winner.top_pick_count} top pick{winner.top_pick_count === 1 ? '' : 's'}
                  {winner.hours_late > 0 ? ` · caricata con ${winner.hours_late}h di ritardo` : ''}
                </p>
                {wasTie && (
                  <p className="mt-0.5 text-xs font-medium text-pop-purple dark:text-pop-pink">
                    Pareggio con {results[1].username} — vince per aver scattato prima 📸
                  </p>
                )}
              </div>
            </button>
          ) : (
            <p className="text-sm text-neutral-500">Nessuno ha partecipato 😶</p>
          )}
          {results.length > 1 && (
            <p className="mt-2 text-xs text-neutral-400">+{results.length - 1} altre foto</p>
          )}
        </Card>
      )}

      <div className="shadow-glow animate-pop-in relative overflow-hidden rounded-3xl bg-gradient-to-br from-pop-purple via-pop-purple-dark to-pop-pink p-6 text-center text-white">
        <p className="text-xs font-bold uppercase tracking-widest text-white/70">
          {challenge.source === 'winner_choice' ? '🎬 Scelto dal Game Master' : 'Il prompt di oggi'}
        </p>
        <h1 className="font-display mt-2 text-2xl font-extrabold drop-shadow-sm">{challenge.prompt_text}</h1>
        {!amGameMaster && (
          <p className="mt-3 inline-block rounded-full bg-black/15 px-4 py-1.5 text-sm font-semibold">
            {isWindowOpen ? `⏳ Hai ${countdown} per scattare` : '⌛ Tempo scaduto — carica pure in ritardo'}
          </p>
        )}
      </div>

      {amGameMaster ? (
        <Card className="text-center">
          <p className="text-sm text-neutral-500">
            🎬 Hai proposto tu il prompt di oggi — sei il Game Master, non partecipi
          </p>
        </Card>
      ) : myPhoto ? (
        <Card className="text-center">
          <p className="text-sm text-neutral-500">
            {myPhoto.is_late ? '📸 Foto caricata (in ritardo)' : '✅ Foto caricata!'}
          </p>
        </Card>
      ) : (
        <Button size="lg" fullWidth onClick={() => navigate(`/circles/${id}/capture`)} className="animate-pop-in">
          📷 Scatta la tua foto
        </Button>
      )}

      <div className="relative">
        <h2 className="font-display mb-3 text-lg font-bold">Griglia della cerchia</h2>
        {!myPhoto && !amGameMaster ? (
          <div className="rounded-3xl border-2 border-dashed border-neutral-300 p-8 text-center dark:border-neutral-700">
            <div aria-hidden className="mb-4 flex flex-wrap justify-center gap-3 opacity-50">
              {Array.from({ length: 6 }).map((_, i) => (
                <div
                  key={i}
                  className="glass aspect-square w-16 rounded-2xl bg-gradient-to-br from-pop-purple/30 to-pop-pink/30"
                />
              ))}
            </div>
            <p className="text-sm font-medium text-neutral-600 dark:text-neutral-300">
              Fai il tuo scatto per sbloccare quelle degli altri membri 🔓
            </p>
          </div>
        ) : photosLoading ? (
          <p className="text-center text-sm text-neutral-500">Carico la griglia...</p>
        ) : (
          <div className="grid grid-cols-2 gap-4 sm:grid-cols-3">
            {gridPhotos.map((photo, i) => (
              <button
                key={photo.id}
                onClick={() => navigate(`/circles/${id}/photos/${photo.id}`)}
                style={{ animationDelay: `${i * 60}ms` }}
                className="animate-pop-in transition hover:-translate-y-1 active:scale-95"
              >
                <PhotoCard
                  src={photo.signed_url}
                  alt={photo.profiles?.username ?? 'foto'}
                  reveal
                  badge={
                    !!photo.top_pick_count && (
                      <span className="shadow-glow-sm absolute top-2 right-2 flex items-center gap-0.5 rounded-full bg-pop-yellow px-2 py-0.5 text-xs font-black text-neutral-900">
                        ⭐ {photo.top_pick_count}
                      </span>
                    )
                  }
                  caption={
                    <>
                      {photo.profiles?.username}
                      {photo.is_late ? ' ⏰' : ''}
                    </>
                  }
                />
              </button>
            ))}
          </div>
        )}
      </div>
    </div>
  )
}
