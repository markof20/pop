import { useEffect, useState, useCallback } from 'react'
import type { FormEvent } from 'react'
import { Link, useNavigate, useParams } from 'react-router-dom'
import { supabase } from '../lib/supabase'
import { useAuth } from '../hooks/useAuth'
import { useLeaderboard } from '../hooks/useLeaderboard'
import type { LeaderboardPeriod } from '../hooks/useLeaderboard'
import { Card } from '../components/ui/Card'
import { Button } from '../components/ui/Button'
import { pillClass } from '../lib/style'
import type { Circle, CircleCategory, CircleRole, Profile } from '../types/database'

const MEDALS = ['🥇', '🥈', '🥉']

const CATEGORY_OPTIONS: { value: CircleCategory; label: string }[] = [
  { value: 'amici', label: '👥 Amici' },
  { value: 'normal', label: '🎲 Normal' },
  { value: 'hot', label: '🔥 Hot' },
]

function LeaderboardSection({ circleId }: { circleId: string }) {
  const [period, setPeriod] = useState<LeaderboardPeriod>('all_time')
  const { rows, loading, error } = useLeaderboard(circleId, period)

  return (
    <Card>
      <div className="mb-3 flex items-center justify-between">
        <h2 className="font-display text-lg font-bold">Classifica</h2>
        <div className="flex rounded-full bg-neutral-100 p-1 dark:bg-neutral-800">
          <button
            onClick={() => setPeriod('weekly')}
            className={`rounded-full px-3 py-1 text-xs font-semibold transition ${
              period === 'weekly'
                ? 'bg-white text-pop-purple shadow dark:bg-neutral-700 dark:text-white'
                : 'text-neutral-500'
            }`}
          >
            Settimana
          </button>
          <button
            onClick={() => setPeriod('all_time')}
            className={`rounded-full px-3 py-1 text-xs font-semibold transition ${
              period === 'all_time'
                ? 'bg-white text-pop-purple shadow dark:bg-neutral-700 dark:text-white'
                : 'text-neutral-500'
            }`}
          >
            Di sempre
          </button>
        </div>
      </div>

      {loading ? (
        <p className="text-sm text-neutral-500">Carico...</p>
      ) : error ? (
        <p className="text-sm text-red-600">{error}</p>
      ) : rows.length === 0 ? (
        <p className="text-sm text-neutral-500">Nessun dato ancora</p>
      ) : (
        <ol className="flex flex-col gap-2">
          {rows.map((row, i) => (
            <li
              key={row.user_id}
              className="flex items-center justify-between rounded-xl px-2 py-1.5 text-sm even:bg-neutral-50 dark:even:bg-neutral-800/50"
            >
              <span className="flex items-center gap-2">
                <span className="w-6 text-center">{MEDALS[i] ?? `${i + 1}.`}</span>
                <span className="font-medium">{row.username}</span>
                {row.wins_count > 0 && (
                  <span className="text-xs text-neutral-400">🏆×{row.wins_count}</span>
                )}
              </span>
              <span className="font-display font-bold text-pop-purple">{row.total_score} pt</span>
            </li>
          ))}
        </ol>
      )}
    </Card>
  )
}

async function deleteCircleStorage(circleId: string) {
  const { data: challengeFolders } = await supabase.storage.from('photos').list(circleId)
  for (const folder of challengeFolders ?? []) {
    const { data: files } = await supabase.storage.from('photos').list(`${circleId}/${folder.name}`)
    const paths = (files ?? []).map((f) => `${circleId}/${folder.name}/${f.name}`)
    if (paths.length > 0) {
      await supabase.storage.from('photos').remove(paths)
    }
  }
}

interface MemberRow {
  user_id: string
  role: CircleRole
  joined_at: string
  profiles: Profile
}

export function CircleSettings() {
  const { id } = useParams<{ id: string }>()
  const { user } = useAuth()
  const navigate = useNavigate()

  const [circle, setCircle] = useState<Circle | null>(null)
  const [members, setMembers] = useState<MemberRow[]>([])
  const [streaks, setStreaks] = useState<Record<string, number>>({})
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [copied, setCopied] = useState(false)
  const [windowMinutes, setWindowMinutes] = useState(120)
  const [category, setCategory] = useState<CircleCategory>('normal')
  const [savingSettings, setSavingSettings] = useState(false)
  const [confirmingDelete, setConfirmingDelete] = useState(false)
  const [deleting, setDeleting] = useState(false)
  const [deleteError, setDeleteError] = useState<string | null>(null)

  const myRole = members.find((m) => m.user_id === user?.id)?.role

  const load = useCallback(async () => {
    if (!id) return
    setLoading(true)

    const [{ data: circleData, error: circleError }, { data: memberData }, { data: streakData }] =
      await Promise.all([
        supabase.from('circles').select('*').eq('id', id).single(),
        supabase
          .from('circle_members')
          .select('user_id, role, joined_at, profiles(*)')
          .eq('circle_id', id)
          .order('joined_at', { ascending: true }),
        supabase.from('user_streaks').select('user_id, current_streak').eq('circle_id', id),
      ])

    if (circleError) {
      setError(circleError.message)
      setLoading(false)
      return
    }

    setCircle(circleData as Circle)
    setWindowMinutes((circleData as Circle).time_window_minutes)
    setCategory((circleData as Circle).category)
    setMembers((memberData ?? []) as unknown as MemberRow[])
    setStreaks(
      Object.fromEntries((streakData ?? []).map((s) => [s.user_id, s.current_streak as number])),
    )
    setError(null)
    setLoading(false)
  }, [id])

  useEffect(() => {
    load()
  }, [load])

  async function handleCopyInvite() {
    if (!circle) return
    await navigator.clipboard.writeText(circle.invite_code)
    setCopied(true)
    setTimeout(() => setCopied(false), 1500)
  }

  async function handleSaveSettings(e: FormEvent) {
    e.preventDefault()
    if (!circle) return
    setSavingSettings(true)
    const { error: updateError } = await supabase
      .from('circles')
      .update({ time_window_minutes: windowMinutes, category })
      .eq('id', circle.id)
    setSavingSettings(false)
    if (!updateError) await load()
  }

  async function handleDeleteCircle() {
    if (!circle) return
    setDeleting(true)
    setDeleteError(null)
    try {
      await deleteCircleStorage(circle.id)
      const { error: deleteRowError } = await supabase.from('circles').delete().eq('id', circle.id)
      if (deleteRowError) throw deleteRowError
      navigate('/')
    } catch (err) {
      setDeleteError(err instanceof Error ? err.message : 'Impossibile eliminare la cerchia')
      setDeleting(false)
    }
  }

  if (loading) {
    return <div className="p-10 text-center text-neutral-500">Caricamento cerchia...</div>
  }

  if (error || !circle) {
    return <div className="p-10 text-center text-red-500">{error ?? 'Cerchia non trovata'}</div>
  }

  return (
    <div className="mx-auto flex max-w-2xl flex-col gap-6 px-4 py-10">
      <Link to={`/circles/${id}`} className="text-sm font-medium text-neutral-500 hover:underline">
        ← Torna al feed
      </Link>

      <div className="animate-fade-in-up">
        <h1 className="font-display text-3xl font-bold text-pop-purple">{circle.name}</h1>
      </div>

      <Card>
        <h2 className="mb-2 font-display text-lg font-bold">Invita amici</h2>
        <div className="flex items-center gap-3">
          <code className="rounded-xl bg-neutral-100 px-3 py-2 text-lg font-mono tracking-widest dark:bg-neutral-800">
            {circle.invite_code}
          </code>
          <Button onClick={handleCopyInvite}>{copied ? '✅ Copiato!' : 'Copia codice'}</Button>
        </div>
      </Card>

      <Card>
        <h2 className="mb-3 font-display text-lg font-bold">Membri ({members.length}/20)</h2>
        <ul className="flex flex-col gap-2">
          {members.map((m) => (
            <li key={m.user_id} className="flex items-center justify-between text-sm">
              <span>{m.profiles?.username}</span>
              <span className="flex items-center gap-2">
                <span className="text-xs text-neutral-500">🔥 {streaks[m.user_id] ?? 0}g</span>
                {m.role === 'admin' && (
                  <span className="rounded-full bg-pop-yellow/30 px-2 py-0.5 text-xs font-semibold text-neutral-700 dark:text-neutral-200">
                    👑 Admin
                  </span>
                )}
              </span>
            </li>
          ))}
        </ul>
      </Card>

      {id && <LeaderboardSection circleId={id} />}

      {myRole === 'admin' && (
        <Card as="form" onSubmit={handleSaveSettings}>
          <h2 className="mb-3 font-display text-lg font-bold">Impostazioni cerchia</h2>

          {circle.circle_type === 'photo' && (
            <>
              <label className="mb-1 block text-sm font-medium text-neutral-700 dark:text-neutral-300">
                Categoria dei prompt
              </label>
              <div className="mb-4 flex gap-2">
                {CATEGORY_OPTIONS.map((opt) => (
                  <button
                    key={opt.value}
                    type="button"
                    onClick={() => setCategory(opt.value)}
                    className={`rounded-full px-4 py-2 text-sm font-semibold transition ${pillClass(category === opt.value)}`}
                  >
                    {opt.label}
                  </button>
                ))}
              </div>

              <p className="mb-4 text-xs text-neutral-400">
                Il livello (intensità del prompt) lo sceglie ogni membro singolarmente, quando apre la
                sfida del giorno.
              </p>
            </>
          )}

          <label className="mb-1 block text-sm font-medium text-neutral-700 dark:text-neutral-300">
            Finestra di tempo per partecipare (minuti)
          </label>
          <div className="flex gap-3">
            <input
              type="number"
              min={15}
              max={1440}
              value={windowMinutes}
              onChange={(e) => setWindowMinutes(Number(e.target.value))}
              className="w-32 rounded-xl border-2 border-neutral-200 px-3 py-2 outline-none focus:border-pop-purple dark:border-neutral-700 dark:bg-neutral-800"
            />
            <Button type="submit" disabled={savingSettings}>
              {savingSettings ? 'Salvataggio...' : 'Salva'}
            </Button>
          </div>
        </Card>
      )}

      {myRole === 'admin' && (
        <Card className="border-red-300! bg-red-50! dark:border-red-900! dark:bg-red-950/30!">
          <h2 className="mb-2 font-display text-lg font-bold text-red-700 dark:text-red-400">
            Zona pericolosa
          </h2>
          <p className="mb-3 text-sm text-red-700/80 dark:text-red-400/80">
            Elimina definitivamente la cerchia: membri, sfide, foto e voti verranno cancellati per
            tutti. Non è reversibile.
          </p>

          {deleteError && <p className="mb-3 text-sm text-red-600">{deleteError}</p>}

          {!confirmingDelete ? (
            <Button variant="danger" onClick={() => setConfirmingDelete(true)}>
              Elimina cerchia
            </Button>
          ) : (
            <div className="flex flex-wrap items-center gap-3">
              <span className="text-sm font-medium text-red-700 dark:text-red-400">Sei sicuro?</span>
              <button
                onClick={handleDeleteCircle}
                disabled={deleting}
                className="rounded-xl bg-red-600 px-4 py-2.5 text-sm font-semibold text-white shadow-md shadow-red-600/30 transition active:scale-95 disabled:opacity-50"
              >
                {deleting ? 'Eliminazione...' : 'Sì, elimina definitivamente'}
              </button>
              <Button variant="ghost" onClick={() => setConfirmingDelete(false)} disabled={deleting}>
                Annulla
              </Button>
            </div>
          )}
        </Card>
      )}
    </div>
  )
}
