import { useCallback, useEffect, useRef, useState } from 'react'
import { supabase } from '../lib/supabase'
import { useAuth } from './useAuth'
import type { GifSession, GifSubmission, GifSubmissionResult } from '../types/database'

const POLL_MS = 4000

export type GifBattlePhase = 'submitting' | 'voting' | 'completed'

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

// Nessuna colonna di stato in gif_sessions: la fase si deriva confrontando
// now() con submission_end_at/voting_end_at, calcolata qui allo stesso modo
// delle RPC lato server (che sono l'unica fonte di verità sui permessi).
export function gifBattlePhase(session: GifSession, now: Date): GifBattlePhase {
  if (now < new Date(session.submission_end_at)) return 'submitting'
  if (now < new Date(session.voting_end_at)) return 'voting'
  return 'completed'
}

// Il round di oggi si crea da solo al primo accesso di un membro (stesso
// pattern lazy di useDailyChallenge/get_active_challenge): nessuna azione di
// avvio, la cerchia GIF ha sempre un round "in corso" non appena esiste.
export function useGifBattle(circleId: string | undefined) {
  const { user } = useAuth()
  const sessionIdRef = useRef<string | null>(null)

  const [session, setSession] = useState<GifSession | null>(null)
  const [mySubmission, setMySubmission] = useState<GifSubmission | null>(null)
  const [myVote, setMyVote] = useState<string | null>(null)
  const [results, setResults] = useState<GifSubmissionResult[]>([])
  const [loading, setLoading] = useState(true)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const refresh = useCallback(async () => {
    if (!circleId || !user) return

    const { data, error: rpcError } = await supabase.rpc('get_active_gif_session', {
      p_circle_id: circleId,
    })
    if (rpcError) {
      setError(rpcError.message)
      setLoading(false)
      return
    }

    const found = data as GifSession
    sessionIdRef.current = found.id
    setSession(found)

    const phase = gifBattlePhase(found, new Date())

    const { data: mine } = await supabase
      .from('gif_submissions')
      .select('*')
      .eq('session_id', found.id)
      .eq('user_id', user.id)
      .maybeSingle()
    setMySubmission((mine as GifSubmission | null) ?? null)

    const { data: vote } = await supabase
      .from('gif_votes')
      .select('submission_id')
      .eq('session_id', found.id)
      .eq('voter_id', user.id)
      .maybeSingle()
    setMyVote((vote?.submission_id as string | undefined) ?? null)

    if (phase === 'voting' || phase === 'completed') {
      const { data: rows, error: resultsError } = await supabase.rpc('get_gif_session_results', {
        p_session_id: found.id,
      })
      if (resultsError) {
        setError(resultsError.message)
        setLoading(false)
        return
      }
      setResults((rows ?? []) as GifSubmissionResult[])
    } else {
      setResults([])
    }

    setError(null)
    setLoading(false)
  }, [circleId, user])

  useEffect(() => {
    refresh()
    const interval = setInterval(refresh, POLL_MS)
    return () => clearInterval(interval)
  }, [refresh])

  async function submitGif(giphyId: string, gifUrl: string) {
    if (!sessionIdRef.current) return
    setBusy(true)
    try {
      const { error: rpcError } = await supabase.rpc('submit_gif', {
        p_session_id: sessionIdRef.current,
        p_giphy_id: giphyId,
        p_gif_url: gifUrl,
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

  async function voteGif(submissionId: string) {
    if (!sessionIdRef.current) return
    setBusy(true)
    try {
      const { error: rpcError } = await supabase.rpc('vote_gif', {
        p_session_id: sessionIdRef.current,
        p_submission_id: submissionId,
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

  return {
    session,
    phase: session ? gifBattlePhase(session, new Date()) : null,
    mySubmission,
    myVote,
    results,
    loading,
    busy,
    error,
    submitGif,
    voteGif,
  }
}
