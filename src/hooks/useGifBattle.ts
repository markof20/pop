import { useCallback, useEffect, useRef, useState } from 'react'
import { supabase } from '../lib/supabase'
import { useAuth } from './useAuth'
import type { GifSession, GifSubmission, GifSubmissionResult } from '../types/database'

const POLL_MS = 4000

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

// Stesso ritmo delle sfide foto: un solo round per cerchia per giorno solare,
// creato al primo accesso di un membro. Manda/vota funzionano in qualunque
// momento del giorno fino a mezzanotte, senza finestre di tempo separate.
export function useGifBattle(circleId: string | undefined) {
  const { user } = useAuth()
  const sessionIdRef = useRef<string | null>(null)

  const [session, setSession] = useState<GifSession | null>(null)
  const [mySubmission, setMySubmission] = useState<GifSubmission | null>(null)
  const [myVote, setMyVote] = useState<string | null>(null)
  const [results, setResults] = useState<GifSubmissionResult[]>([])
  const [yesterday, setYesterday] = useState<{
    session: GifSession
    results: GifSubmissionResult[]
  } | null>(null)
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

    const { data: mine } = await supabase
      .from('gif_submissions')
      .select('*')
      .eq('session_id', found.id)
      .eq('user_id', user.id)
      .maybeSingle()
    const mySub = (mine as GifSubmission | null) ?? null
    setMySubmission(mySub)

    const { data: vote } = await supabase
      .from('gif_votes')
      .select('submission_id')
      .eq('session_id', found.id)
      .eq('voter_id', user.id)
      .maybeSingle()
    setMyVote((vote?.submission_id as string | undefined) ?? null)

    if (mySub) {
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

    const { data: prevSession, error: prevError } = await supabase.rpc(
      'get_latest_completed_gif_session',
      { p_circle_id: circleId },
    )
    if (prevError) {
      setError(prevError.message)
      setLoading(false)
      return
    }
    if (prevSession) {
      const { data: prevRows } = await supabase.rpc('get_gif_session_results', {
        p_session_id: (prevSession as GifSession).id,
      })
      setYesterday({
        session: prevSession as GifSession,
        results: (prevRows ?? []) as GifSubmissionResult[],
      })
    } else {
      setYesterday(null)
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
    mySubmission,
    myVote,
    results,
    yesterday,
    loading,
    busy,
    error,
    submitGif,
    voteGif,
  }
}
