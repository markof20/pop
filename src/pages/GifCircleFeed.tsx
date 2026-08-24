import { useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import { useAuth } from '../hooks/useAuth'
import { useGifBattle } from '../hooks/useGifBattle'
import { GifPicker } from '../components/GifPicker'
import { Card } from '../components/ui/Card'
import { Button } from '../components/ui/Button'
import { PhotoCard } from '../components/ui/PhotoCard'
import { EmptyState } from '../components/ui/EmptyState'
import type { GifResult } from '../lib/giphy'

export function GifCircleFeed() {
  const { id } = useParams<{ id: string }>()
  const { user } = useAuth()
  const { session, mySubmission, myVote, results, yesterday, loading, busy, error, submitGif, voteGif } =
    useGifBattle(id)
  const [pickerOpen, setPickerOpen] = useState(false)
  const [submitError, setSubmitError] = useState<string | null>(null)
  const [voteError, setVoteError] = useState<string | null>(null)

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

  if (loading || !session) {
    return <div className="p-10 text-center text-neutral-500">Preparo la frase di oggi... 🎬</div>
  }

  const yesterdayWinner = yesterday?.results[0]

  return (
    <div className="relative mx-auto flex max-w-2xl flex-col gap-6 px-4 py-8">
      <div className="flex items-center justify-between">
        <Link to="/" className="text-sm font-medium text-neutral-500 hover:underline">
          ← Cerchie
        </Link>
        <div className="flex items-center gap-4">
          <Link to={`/circles/${id}/party`} className="text-sm font-medium text-neutral-500 hover:underline">
            🎉 Party
          </Link>
          <Link to={`/circles/${id}/settings`} className="text-sm font-medium text-neutral-500 hover:underline">
            Impostazioni →
          </Link>
        </div>
      </div>

      {error && <p className="text-sm text-red-600">{error}</p>}

      {yesterday && (
        <Card className="animate-fade-in-up border-l-4! border-l-pop-yellow!">
          <p className="text-xs font-bold uppercase tracking-wide text-neutral-400">Risultato di ieri</p>
          <p className="mb-2 text-sm italic text-neutral-500">"{yesterday.session.prompt_text}"</p>
          {yesterdayWinner ? (
            <div className="flex items-center gap-3">
              <img
                src={yesterdayWinner.gif_url}
                alt={yesterdayWinner.username}
                className="h-16 w-16 rounded-2xl object-cover shadow-md"
              />
              <div>
                <p className="font-display font-bold">🏆 {yesterdayWinner.username}</p>
                <p className="text-xs text-neutral-500">
                  {yesterdayWinner.vote_count} voto{yesterdayWinner.vote_count === 1 ? '' : 'i'}
                </p>
              </div>
            </div>
          ) : (
            <p className="text-sm text-neutral-500">Nessuno ha partecipato 😶</p>
          )}
          {yesterday.results.length > 1 && (
            <p className="mt-2 text-xs text-neutral-400">+{yesterday.results.length - 1} altre gif</p>
          )}
        </Card>
      )}

      <Card className="shadow-glow animate-pop-in bg-gradient-to-br from-pop-purple to-pop-pink text-center text-white">
        <p className="text-xs font-bold uppercase tracking-widest text-white/70">La frase di oggi</p>
        <h1 className="font-display mt-2 text-2xl font-extrabold drop-shadow-sm">{session.prompt_text}</h1>
      </Card>

      {!mySubmission ? (
        <Card className="text-center">
          {submitError && <p className="mb-3 text-sm text-red-600">{submitError}</p>}
          <p className="mb-3 text-sm text-neutral-500">
            Manda una GIF entro mezzanotte per sbloccare quelle degli altri e votare
          </p>
          <Button size="lg" fullWidth disabled={busy} onClick={() => setPickerOpen(true)}>
            🔍 Scegli una GIF
          </Button>
        </Card>
      ) : (
        <div>
          {voteError && <p className="mb-3 text-center text-sm text-red-600">{voteError}</p>}
          {results.length === 0 ? (
            <EmptyState icon="🤷" text="Nessun'altra GIF ancora, ricontrolla più tardi" />
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

      {pickerOpen && (
        <GifPicker busy={busy} onClose={() => setPickerOpen(false)} onSelect={handleSelectGif} />
      )}
    </div>
  )
}
