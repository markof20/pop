import { useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import { useAuth } from '../hooks/useAuth'
import { useParty } from '../hooks/useParty'
import { Card } from '../components/ui/Card'
import { Button } from '../components/ui/Button'
import { Avatar } from '../components/ui/Avatar'
import { EmptyState } from '../components/ui/EmptyState'

const MEDALS = ['🥇', '🥈', '🥉']

export function Party() {
  const { id } = useParams<{ id: string }>()
  const { user } = useAuth()
  const {
    isAdmin,
    session,
    checkins,
    currentTask,
    completionVotes,
    ratings,
    leaderboard,
    loading,
    busy,
    error,
    startSession,
    checkin,
    startRound,
    markDone,
    rate,
    skip,
    advance,
    endSession,
    dismissSession,
  } = useParty(id)
  const [confirmingEnd, setConfirmingEnd] = useState(false)

  async function handleEndSession() {
    await endSession()
    setConfirmingEnd(false)
  }

  if (loading) {
    return <div className="p-10 text-center text-neutral-500">Preparo il party... 🎉</div>
  }

  const myCheckedIn = checkins.some((c) => c.user_id === user?.id)
  const amAssignee = !!currentTask && currentTask.assignee_id === user?.id
  const myCompletionVoted = completionVotes.includes(user?.id ?? '')
  const myRating = ratings.find((r) => r.voter_id === user?.id)?.value ?? null
  const eligibleVoters = Math.max(checkins.length - 1, 0)
  const upvotes = ratings.filter((r) => r.value === 1).length
  const downvotes = ratings.filter((r) => r.value === -1).length
  const currentAssigneeName = checkins.find((c) => c.user_id === currentTask?.assignee_id)?.profiles
    ?.username

  return (
    <div className="relative mx-auto flex max-w-2xl flex-col gap-6 px-4 py-8">
      <div className="flex items-center justify-between">
        <Link to={`/circles/${id}`} className="text-sm font-medium text-neutral-500 hover:underline">
          ← Cerchia
        </Link>
        <h1 className="font-display text-lg font-bold">🎉 Modalità PARTY</h1>
      </div>

      {error && <p className="text-sm text-red-600">{error}</p>}

      {session && session.status !== 'completed' && isAdmin && (
        <div className="flex justify-end">
          {!confirmingEnd ? (
            <button
              onClick={() => setConfirmingEnd(true)}
              className="text-xs font-medium text-neutral-400 hover:text-red-500 hover:underline"
            >
              Termina sessione
            </button>
          ) : (
            <div className="flex items-center gap-2 text-xs">
              <span className="font-medium text-red-600">Chiudere il party per tutti?</span>
              <button
                onClick={handleEndSession}
                disabled={busy}
                className="font-semibold text-red-600 underline disabled:opacity-50"
              >
                Sì, chiudi
              </button>
              <button onClick={() => setConfirmingEnd(false)} className="text-neutral-400 underline">
                Annulla
              </button>
            </div>
          )}
        </div>
      )}

      {!session && (
        <Card className="animate-pop-in text-center">
          <p className="mb-4 text-sm text-neutral-500">
            Radunate la cerchia di persona: i task vengono rivelati uno alla volta e a sorpresa. Si
            può saltare un task una sola volta, poi se ricapita va fatto per forza. Si va avanti
            finché tutti non hanno fatto tutti i loro task — il gruppo conferma ogni esecuzione dal
            vivo, poi vota 👍/👎.
          </p>
          {isAdmin ? (
            <Button size="lg" fullWidth disabled={busy} onClick={() => startSession()}>
              {busy ? 'Avvio...' : '🎉 Avvia sessione PARTY'}
            </Button>
          ) : (
            <p className="text-sm text-neutral-400">Aspetta che un admin della cerchia avvii una sessione</p>
          )}
        </Card>
      )}

      {session?.status === 'checkin' && (
        <Card>
          <h2 className="mb-3 font-display text-lg font-bold">Chi c'è? 🙋</h2>
          <div className="mb-4 flex flex-wrap gap-3">
            {checkins.map((c) => (
              <div key={c.user_id} className="flex flex-col items-center gap-1">
                <Avatar username={c.profiles?.username ?? '?'} avatarUrl={c.profiles?.avatar_url} size={44} />
                <span className="text-xs text-neutral-500">{c.profiles?.username}</span>
              </div>
            ))}
            {checkins.length === 0 && (
              <p className="text-sm text-neutral-400">Ancora nessuno ha fatto check-in</p>
            )}
          </div>

          {!myCheckedIn ? (
            <Button fullWidth onClick={() => checkin()}>
              Sono qui! 🙋
            </Button>
          ) : (
            <p className="mb-1 text-center text-sm text-neutral-500">✅ Sei dentro, aspetta gli altri</p>
          )}

          {isAdmin && (
            <Button
              fullWidth
              variant="secondary"
              disabled={busy || checkins.length < 2}
              onClick={() => startRound()}
              className="mt-3"
            >
              {busy ? 'Avvio...' : `Inizia il party (${checkins.length} present${checkins.length === 1 ? 'e' : 'i'})`}
            </Button>
          )}
        </Card>
      )}

      {session?.status === 'active' && currentTask && (
        <>
          <Card className="shadow-glow animate-pop-in bg-gradient-to-br from-pop-purple to-pop-pink text-center text-white">
            <p className="text-xs font-bold uppercase tracking-widest text-white/70">Tocca a</p>
            <h2 className="font-display mt-1 text-2xl font-extrabold">{currentAssigneeName ?? '...'}</h2>
            <p className="mt-3 text-lg">{currentTask.prompt_text}</p>
          </Card>

          {currentTask.status === 'revealed' && (
            <Card className="text-center">
              {amAssignee ? (
                <>
                  <p className="mb-3 text-sm text-neutral-500">
                    🎭 Tocca a te: eseguilo dal vivo, poi gli altri confermano
                  </p>
                  {currentTask.skipped ? (
                    <p className="text-xs text-neutral-400">
                      Hai già saltato questo task una volta: stavolta va fatto
                    </p>
                  ) : (
                    <Button variant="outline" onClick={() => skip()}>
                      Salta ⏭️
                    </Button>
                  )}
                </>
              ) : myCompletionVoted ? (
                <p className="text-sm text-neutral-500">
                  ✅ Confermato — {completionVotes.length}/{eligibleVoters} hanno detto fatto
                </p>
              ) : (
                <>
                  <p className="mb-3 text-sm text-neutral-500">
                    {completionVotes.length}/{eligibleVoters} hanno confermato
                  </p>
                  <Button fullWidth onClick={() => markDone()}>
                    Fatto! ✅
                  </Button>
                </>
              )}
            </Card>
          )}

          {currentTask.status === 'completed' && (
            <Card className="text-center">
              {amAssignee ? (
                <p className="text-sm text-neutral-500">
                  👍 {upvotes} · 👎 {downvotes} — aspetta che gli altri votino
                </p>
              ) : (
                <>
                  <p className="mb-3 text-sm text-neutral-500">Come l'ha interpretato?</p>
                  <div className="flex gap-3">
                    <button
                      onClick={() => rate(1)}
                      className={`flex-1 rounded-2xl border-2 py-3 text-2xl transition active:scale-95 ${
                        myRating === 1
                          ? 'border-pop-purple bg-pop-purple/10'
                          : 'border-neutral-200 dark:border-neutral-700'
                      }`}
                    >
                      👍 {upvotes}
                    </button>
                    <button
                      onClick={() => rate(-1)}
                      className={`flex-1 rounded-2xl border-2 py-3 text-2xl transition active:scale-95 ${
                        myRating === -1
                          ? 'border-red-400 bg-red-50 dark:bg-red-950/30'
                          : 'border-neutral-200 dark:border-neutral-700'
                      }`}
                    >
                      👎 {downvotes}
                    </button>
                  </div>
                </>
              )}

              {isAdmin && (
                <Button fullWidth variant="secondary" disabled={busy} onClick={() => advance()} className="mt-4">
                  {busy ? '...' : 'Turno successivo ➡️'}
                </Button>
              )}
            </Card>
          )}

          {currentTask.status === 'skipped' && (
            <Card className="text-center">
              <p className="text-sm text-neutral-500">⏭️ Task saltato</p>
              {isAdmin && (
                <Button fullWidth variant="secondary" disabled={busy} onClick={() => advance()} className="mt-3">
                  {busy ? '...' : 'Turno successivo ➡️'}
                </Button>
              )}
            </Card>
          )}
        </>
      )}

      {session?.status === 'completed' && (
        <Card className="animate-bounce-in">
          <h2 className="mb-3 font-display text-lg font-bold">🏆 Classifica party</h2>
          {leaderboard.length === 0 ? (
            <EmptyState icon="🤷" text="Nessun task completato" />
          ) : (
            <ol className="flex flex-col gap-2">
              {leaderboard.map((row, i) => (
                <li
                  key={row.assignee_id}
                  className="flex items-center justify-between rounded-xl px-2 py-1.5 text-sm even:bg-neutral-50 dark:even:bg-neutral-800/50"
                >
                  <span className="flex items-center gap-2">
                    <span className="w-6 text-center">{MEDALS[i] ?? `${i + 1}.`}</span>
                    <span className="font-medium">{row.username}</span>
                    <span className="text-xs text-neutral-400">
                      {row.tasks_completed} task{row.tasks_completed === 1 ? '' : 's'}
                    </span>
                  </span>
                  <span className="flex items-center gap-2">
                    <span className="text-xs text-neutral-400">
                      👍{row.upvotes} 👎{row.downvotes}
                    </span>
                    <span className="font-display font-bold text-pop-purple">{row.net_score}</span>
                  </span>
                </li>
              ))}
            </ol>
          )}
          <Button fullWidth variant="outline" className="mt-4" onClick={() => dismissSession()}>
            Chiudi
          </Button>
        </Card>
      )}
    </div>
  )
}
