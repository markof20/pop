import { useEffect, useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import { useAuth } from '../hooks/useAuth'
import { useGifBattle } from '../hooks/useGifBattle'
import { GifPicker } from '../components/GifPicker'
import { Card } from '../components/ui/Card'
import { Button } from '../components/ui/Button'
import { PhotoCard } from '../components/ui/PhotoCard'
import { EmptyState } from '../components/ui/EmptyState'
import type { GifResult } from '../lib/giphy'

const MEDALS = ['🥇', '🥈', '🥉']

function useCountdown(target: Date | null) {
  const [label, setLabel] = useState('')

  useEffect(() => {
    if (!target) return
    const tick = () => {
      const diffMs = target.getTime() - Date.now()
      if (diffMs <= 0) {
        setLabel('Tempo scaduto')
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

export function GifBattle() {
  const { id } = useParams<{ id: string }>()
  const { user } = useAuth()
  const {
    isAdmin,
    session,
    phase,
    mySubmission,
    myVote,
    results,
    loading,
    busy,
    error,
    startSession,
    submitGif,
    voteGif,
  } = useGifBattle(id)
  const [pickerOpen, setPickerOpen] = useState(false)
  const [submitError, setSubmitError] = useState<string | null>(null)
  const [voteError, setVoteError] = useState<string | null>(null)

  const submissionCountdown = useCountdown(
    session && phase === 'submitting' ? new Date(session.submission_end_at) : null,
  )
  const votingCountdown = useCountdown(
    session && phase === 'voting' ? new Date(session.voting_end_at) : null,
  )

  async function handleSelectGif(gif: GifResult) {
    setSubmitError(null)
    try {
      await submitGif(gif.id, gif.url)
      setPickerOpen(false)
    } catch (err) {
      setSubmitError(err instanceof Error ? err.message : 'Errore, riprova')
    }
  }

  async function handleVote(submissionId: string) {
    setVoteError(null)
    try {
      await voteGif(submissionId)
    } catch (err) {
      setVoteError(err instanceof Error ? err.message : 'Errore, riprova')
    }
  }

  if (loading) {
    return <div className="p-10 text-center text-neutral-500">Preparo il round GIF... 🎬</div>
  }

  const winnerCount = results[0]?.vote_count ?? 0

  return (
    <div className="relative mx-auto flex max-w-2xl flex-col gap-6 px-4 py-8">
      <div className="flex items-center justify-between">
        <Link to={`/circles/${id}`} className="text-sm font-medium text-neutral-500 hover:underline">
          ← Cerchia
        </Link>
        <h1 className="font-display text-lg font-bold">🎬 GIF Battle</h1>
      </div>

      {error && <p className="text-sm text-red-600">{error}</p>}

      {!session && (
        <Card className="animate-pop-in text-center">
          <p className="mb-4 text-sm text-neutral-500">
            Esce una frase a caso: ognuno risponde con una GIF cercata al volo, poi tutti votano quella
            che si abbina meglio (non si può votare la propria).
          </p>
          {isAdmin ? (
            <Button size="lg" fullWidth disabled={busy} onClick={() => startSession()}>
              {busy ? 'Avvio...' : '🎬 Avvia round GIF'}
            </Button>
          ) : (
            <p className="text-sm text-neutral-400">Aspetta che un admin della cerchia avvii un round</p>
          )}
        </Card>
      )}

      {session && (
        <Card className="shadow-glow animate-pop-in bg-gradient-to-br from-pop-purple to-pop-pink text-center text-white">
          <p className="text-xs font-bold uppercase tracking-widest text-white/70">La frase di oggi</p>
          <h2 className="font-display mt-2 text-2xl font-extrabold drop-shadow-sm">
            {session.prompt_text}
          </h2>
        </Card>
      )}

      {session && phase === 'submitting' && (
        <Card className="text-center">
          <p className="mb-3 text-sm text-neutral-500">⏳ Hai {submissionCountdown} per mandare la tua GIF</p>
          {submitError && <p className="mb-3 text-sm text-red-600">{submitError}</p>}
          {mySubmission ? (
            <>
              <img
                src={mySubmission.gif_url}
                alt="La tua GIF"
                className="mx-auto mb-3 max-h-48 rounded-2xl shadow-md"
              />
              <p className="mb-3 text-sm text-neutral-500">✅ GIF inviata — aspetta gli altri</p>
              <Button variant="outline" disabled={busy} onClick={() => setPickerOpen(true)}>
                Cambia GIF
              </Button>
            </>
          ) : (
            <Button size="lg" fullWidth disabled={busy} onClick={() => setPickerOpen(true)}>
              🔍 Scegli una GIF
            </Button>
          )}
        </Card>
      )}

      {session && phase === 'voting' && (
        <div>
          <p className="mb-3 text-center text-sm text-neutral-500">
            🗳️ Vota la GIF migliore — chiude tra {votingCountdown}
          </p>
          {voteError && <p className="mb-3 text-center text-sm text-red-600">{voteError}</p>}
          {results.length === 0 ? (
            <EmptyState icon="🤷" text="Nessuna GIF inviata questo round" />
          ) : (
            <div className="grid grid-cols-2 gap-4 sm:grid-cols-3">
              {results.map((r, i) => {
                const isMine = r.user_id === user?.id
                const isVoted = myVote === r.submission_id
                return (
                  <button
                    key={r.submission_id}
                    disabled={isMine || busy}
                    onClick={() => handleVote(r.submission_id)}
                    style={{ animationDelay: `${i * 60}ms` }}
                    className={`animate-pop-in text-left transition hover:-translate-y-1 active:scale-95 disabled:cursor-not-allowed disabled:hover:translate-y-0 ${
                      isVoted ? 'ring-3 ring-pop-purple rounded-2xl' : ''
                    }`}
                  >
                    <PhotoCard
                      src={r.gif_url}
                      alt={r.username}
                      reveal
                      badge={
                        <span className="shadow-glow-sm absolute top-2 right-2 flex items-center gap-0.5 rounded-full bg-pop-yellow px-2 py-0.5 text-xs font-black text-neutral-900">
                          👍 {r.vote_count}
                        </span>
                      }
                      caption={
                        <>
                          {r.username}
                          {isMine ? ' (tu)' : ''}
                        </>
                      }
                    />
                  </button>
                )
              })}
            </div>
          )}
        </div>
      )}

      {session && phase === 'completed' && (
        <Card className="animate-bounce-in">
          <h2 className="mb-3 font-display text-lg font-bold">🏆 Risultati</h2>
          {results.length === 0 ? (
            <EmptyState icon="🤷" text="Nessuna GIF inviata questo round" />
          ) : (
            <ol className="flex flex-col gap-2">
              {results.map((r, i) => (
                <li
                  key={r.submission_id}
                  className="flex items-center justify-between rounded-xl px-2 py-1.5 text-sm even:bg-neutral-50 dark:even:bg-neutral-800/50"
                >
                  <span className="flex items-center gap-3">
                    <span className="w-6 text-center">{MEDALS[i] ?? `${i + 1}.`}</span>
                    <img src={r.gif_url} alt={r.username} className="h-12 w-12 rounded-xl object-cover" />
                    <span className="font-medium">{r.username}</span>
                  </span>
                  <span className="font-display font-bold text-pop-purple">
                    👍 {r.vote_count}
                    {r.vote_count > 0 && r.vote_count === winnerCount && i === 0 ? ' 🏆' : ''}
                  </span>
                </li>
              ))}
            </ol>
          )}
          {isAdmin && (
            <Button fullWidth variant="secondary" disabled={busy} onClick={() => startSession()} className="mt-4">
              {busy ? 'Avvio...' : '🎬 Nuovo round'}
            </Button>
          )}
        </Card>
      )}

      {pickerOpen && (
        <GifPicker busy={busy} onClose={() => setPickerOpen(false)} onSelect={handleSelectGif} />
      )}
    </div>
  )
}
