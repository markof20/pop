import { useCallback, useEffect, useState } from 'react'
import { supabase } from '../lib/supabase'
import type { ChallengeParticipant, DailyChallenge } from '../types/database'

export function useDailyChallenge(circleId: string | undefined) {
  const [challenge, setChallenge] = useState<DailyChallenge | null>(null)
  const [participation, setParticipation] = useState<ChallengeParticipant | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const refresh = useCallback(async () => {
    if (!circleId) return
    setLoading(true)

    const { data: challengeData, error: challengeError } = await supabase.rpc('get_active_challenge', {
      p_circle_id: circleId,
    })
    if (challengeError) {
      setError(challengeError.message)
      setLoading(false)
      return
    }

    const { data: participationData, error: participationError } = await supabase.rpc(
      'start_my_challenge',
      { p_daily_challenge_id: (challengeData as DailyChallenge).id },
    )
    if (participationError) {
      setError(participationError.message)
      setLoading(false)
      return
    }

    setChallenge(challengeData as DailyChallenge)
    setParticipation(participationData as ChallengeParticipant)
    setError(null)
    setLoading(false)
  }, [circleId])

  useEffect(() => {
    refresh()
  }, [refresh])

  // Il timer è personale: parte quando QUESTO utente ha visto per la prima volta
  // il prompt di oggi, non quando il primo membro della cerchia lo ha aperto.
  const windowEndAt = participation ? new Date(participation.window_end_at) : null
  const isWindowOpen = windowEndAt ? new Date() < windowEndAt : false

  return { challenge, participation, loading, error, refresh, windowEndAt, isWindowOpen }
}
