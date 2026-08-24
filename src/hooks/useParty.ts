import { useCallback, useEffect, useRef, useState } from 'react'
import { supabase } from '../lib/supabase'
import { useAuth } from './useAuth'
import type {
  PartyCheckinWithProfile,
  PartyLeaderboardRow,
  PartyRating,
  PartySession,
  PartyTask,
} from '../types/database'

const POLL_MS = 3000

// Le RPC di supabase-js rifiutano con un PostgrestError (un oggetto semplice con
// .message), non con un'istanza di Error: "err instanceof Error" lo lascerebbe
// passare e nasconderebbe il messaggio reale dietro un generico "Errore, riprova".
function getErrorMessage(err: unknown): string {
  if (err instanceof Error) return err.message
  if (err && typeof err === 'object' && 'message' in err && typeof err.message === 'string') {
    return err.message
  }
  return 'Errore, riprova'
}

// A differenza delle sfide giornaliere, la modalità party è sincrona (tutti fisicamente
// insieme): serve un poll leggero per far vedere a tutti i telefoni lo stesso turno
// senza bisogno di un refresh manuale.
export function useParty(circleId: string | undefined) {
  const { user } = useAuth()
  const sessionIdRef = useRef<string | null>(null)

  const [isAdmin, setIsAdmin] = useState(false)
  const [session, setSession] = useState<PartySession | null>(null)
  const [checkins, setCheckins] = useState<PartyCheckinWithProfile[]>([])
  const [currentTask, setCurrentTask] = useState<PartyTask | null>(null)
  const [completionVotes, setCompletionVotes] = useState<string[]>([])
  const [ratings, setRatings] = useState<PartyRating[]>([])
  const [leaderboard, setLeaderboard] = useState<PartyLeaderboardRow[]>([])
  const [loading, setLoading] = useState(true)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    if (!circleId || !user) return
    supabase
      .from('circle_members')
      .select('role')
      .eq('circle_id', circleId)
      .eq('user_id', user.id)
      .maybeSingle()
      .then(({ data }) => setIsAdmin(data?.role === 'admin'))
  }, [circleId, user])

  const refresh = useCallback(async () => {
    if (!circleId || !user) return

    let activeSessionId = sessionIdRef.current

    if (!activeSessionId) {
      const { data, error: rpcError } = await supabase.rpc('get_active_party_session', {
        p_circle_id: circleId,
      })
      if (rpcError) {
        setError(rpcError.message)
        setLoading(false)
        return
      }
      const found = data as PartySession | null
      if (!found) {
        setSession(null)
        setError(null)
        setLoading(false)
        return
      }
      activeSessionId = found.id
      sessionIdRef.current = found.id
    }

    const { data: sessionRow, error: sessionError } = await supabase
      .from('party_sessions')
      .select('*')
      .eq('id', activeSessionId)
      .maybeSingle()

    if (sessionError) {
      setError(sessionError.message)
      setLoading(false)
      return
    }
    if (!sessionRow) {
      sessionIdRef.current = null
      setSession(null)
      setError(null)
      setLoading(false)
      return
    }

    const typedSession = sessionRow as PartySession
    setSession(typedSession)

    const { data: checkinData } = await supabase
      .from('party_checkins')
      .select('user_id, checked_in_at, profiles(*)')
      .eq('session_id', activeSessionId)
      .order('checked_in_at', { ascending: true })
    setCheckins((checkinData ?? []) as unknown as PartyCheckinWithProfile[])

    if (typedSession.current_task_id) {
      const { data: taskRow } = await supabase
        .from('party_tasks')
        .select('*')
        .eq('id', typedSession.current_task_id)
        .maybeSingle()
      setCurrentTask((taskRow as PartyTask | null) ?? null)

      const { data: votes } = await supabase
        .from('party_completion_votes')
        .select('voter_id')
        .eq('task_id', typedSession.current_task_id)
      setCompletionVotes((votes ?? []).map((v) => v.voter_id as string))

      const { data: ratingRows } = await supabase
        .from('party_ratings')
        .select('*')
        .eq('task_id', typedSession.current_task_id)
      setRatings((ratingRows ?? []) as PartyRating[])
    } else {
      setCurrentTask(null)
      setCompletionVotes([])
      setRatings([])
    }

    if (typedSession.status === 'completed') {
      const { data: board } = await supabase.rpc('get_party_leaderboard', {
        p_session_id: activeSessionId,
      })
      setLeaderboard((board ?? []) as PartyLeaderboardRow[])
    } else {
      setLeaderboard([])
    }

    setError(null)
    setLoading(false)
  }, [circleId, user])

  useEffect(() => {
    refresh()
    const interval = setInterval(refresh, POLL_MS)
    return () => clearInterval(interval)
  }, [refresh])

  async function startSession() {
    if (!circleId) return
    setBusy(true)
    try {
      const { data, error: rpcError } = await supabase.rpc('start_party_session', {
        p_circle_id: circleId,
      })
      if (rpcError) throw rpcError
      sessionIdRef.current = (data as PartySession).id
      await refresh()
    } catch (err) {
      setError(getErrorMessage(err))
      throw err
    } finally {
      setBusy(false)
    }
  }

  async function checkin() {
    if (!sessionIdRef.current) return
    const { error: rpcError } = await supabase.rpc('party_checkin', {
      p_session_id: sessionIdRef.current,
    })
    if (rpcError) {
      setError(rpcError.message)
      throw rpcError
    }
    await refresh()
  }

  async function startRound() {
    if (!sessionIdRef.current) return
    setBusy(true)
    try {
      const { error: rpcError } = await supabase.rpc('start_party_round', {
        p_session_id: sessionIdRef.current,
      })
      if (rpcError) throw rpcError
      await refresh()
    } catch (err) {
      setError(getErrorMessage(err))
      throw err
    } finally {
      setBusy(false)
    }
  }

  async function markDone() {
    if (!currentTask) return
    const { error: rpcError } = await supabase.rpc('mark_task_done', { p_task_id: currentTask.id })
    if (rpcError) {
      setError(rpcError.message)
      throw rpcError
    }
    await refresh()
  }

  async function rate(value: 1 | -1) {
    if (!currentTask) return
    const { error: rpcError } = await supabase.rpc('rate_task', {
      p_task_id: currentTask.id,
      p_value: value,
    })
    if (rpcError) {
      setError(rpcError.message)
      throw rpcError
    }
    await refresh()
  }

  async function skip() {
    if (!currentTask) return
    const { error: rpcError } = await supabase.rpc('skip_task', { p_task_id: currentTask.id })
    if (rpcError) {
      setError(rpcError.message)
      throw rpcError
    }
    await refresh()
  }

  async function advance() {
    if (!sessionIdRef.current) return
    setBusy(true)
    try {
      const { error: rpcError } = await supabase.rpc('advance_party_round', {
        p_session_id: sessionIdRef.current,
      })
      if (rpcError) throw rpcError
      await refresh()
    } catch (err) {
      setError(getErrorMessage(err))
      throw err
    } finally {
      setBusy(false)
    }
  }

  async function endSession() {
    if (!sessionIdRef.current) return
    setBusy(true)
    try {
      const { error: rpcError } = await supabase.rpc('end_party_session', {
        p_session_id: sessionIdRef.current,
      })
      if (rpcError) throw rpcError
      await refresh()
    } catch (err) {
      setError(getErrorMessage(err))
      throw err
    } finally {
      setBusy(false)
    }
  }

  function dismissSession() {
    sessionIdRef.current = null
    setSession(null)
    setCurrentTask(null)
    setCheckins([])
    setCompletionVotes([])
    setRatings([])
    setLeaderboard([])
    refresh()
  }

  return {
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
  }
}
