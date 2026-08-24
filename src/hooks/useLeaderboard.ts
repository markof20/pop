import { useCallback, useEffect, useState } from 'react'
import { supabase } from '../lib/supabase'

export type LeaderboardPeriod = 'all_time' | 'weekly'

export interface LeaderboardRow {
  user_id: string
  username: string
  total_score: number
  wins_count: number
  challenges_participated: number
}

export function useLeaderboard(circleId: string | undefined, period: LeaderboardPeriod) {
  const [rows, setRows] = useState<LeaderboardRow[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const refresh = useCallback(async () => {
    if (!circleId) return
    setLoading(true)
    const { data, error: rpcError } = await supabase.rpc('get_circle_leaderboard', {
      p_circle_id: circleId,
      p_period: period,
    })
    if (rpcError) {
      setError(rpcError.message)
      setLoading(false)
      return
    }
    setRows((data as LeaderboardRow[]) ?? [])
    setError(null)
    setLoading(false)
  }, [circleId, period])

  useEffect(() => {
    refresh()
  }, [refresh])

  return { rows, loading, error, refresh }
}
