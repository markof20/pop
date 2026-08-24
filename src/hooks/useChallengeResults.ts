import { useCallback, useEffect, useState } from 'react'
import { supabase } from '../lib/supabase'
import type { DailyChallenge } from '../types/database'

const SIGNED_URL_TTL_SECONDS = 60 * 30

export interface ChallengeResultRow {
  photo_id: string
  user_id: string
  username: string
  storage_path: string
  is_late: boolean
  hours_late: number
  top_pick_count: number
  score: number
  uploaded_at: string
  signed_url?: string
}

export function useChallengeResults(circleId: string | undefined) {
  const [challenge, setChallenge] = useState<DailyChallenge | null>(null)
  const [results, setResults] = useState<ChallengeResultRow[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const refresh = useCallback(async () => {
    if (!circleId) return
    setLoading(true)

    const { data: latest, error: latestError } = await supabase.rpc(
      'get_latest_completed_challenge',
      { p_circle_id: circleId },
    )
    if (latestError) {
      setError(latestError.message)
      setLoading(false)
      return
    }

    if (!latest) {
      setChallenge(null)
      setResults([])
      setError(null)
      setLoading(false)
      return
    }

    const { data: rows, error: resultsError } = await supabase.rpc('get_challenge_results', {
      p_daily_challenge_id: (latest as DailyChallenge).id,
    })
    if (resultsError) {
      setError(resultsError.message)
      setLoading(false)
      return
    }

    const withUrls = await Promise.all(
      ((rows ?? []) as ChallengeResultRow[]).map(async (row) => {
        const { data: signed } = await supabase.storage
          .from('photos')
          .createSignedUrl(row.storage_path, SIGNED_URL_TTL_SECONDS)
        return { ...row, signed_url: signed?.signedUrl }
      }),
    )

    setChallenge(latest as DailyChallenge)
    setResults(withUrls)
    setError(null)
    setLoading(false)
  }, [circleId])

  useEffect(() => {
    refresh()
  }, [refresh])

  const winner = results[0] ?? null
  const wasTie = results.length > 1 && results[1].top_pick_count === winner?.top_pick_count

  return { challenge, results, winner, wasTie, loading, error, refresh }
}
