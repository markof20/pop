import { useCallback, useEffect, useState } from 'react'
import { supabase } from '../lib/supabase'

export interface PendingWin {
  daily_challenge_id: string
  prompt_text: string
  challenge_date: string
  decide_by_at: string
}

export function useWinnerDecision(circleId: string | undefined) {
  const [pendingWin, setPendingWin] = useState<PendingWin | null>(null)
  const [loading, setLoading] = useState(true)
  const [submitting, setSubmitting] = useState(false)

  const refresh = useCallback(async () => {
    if (!circleId) return
    setLoading(true)
    const { data } = await supabase.rpc('get_my_pending_win', { p_circle_id: circleId })
    setPendingWin(((data as PendingWin[] | null) ?? [])[0] ?? null)
    setLoading(false)
  }, [circleId])

  useEffect(() => {
    refresh()
  }, [refresh])

  async function chooseOptionA(customPrompt: string) {
    if (!pendingWin) return
    setSubmitting(true)
    try {
      const { error } = await supabase.rpc('submit_winner_choice', {
        p_won_challenge_id: pendingWin.daily_challenge_id,
        p_choice: 'A',
        p_custom_prompt: customPrompt,
      })
      if (error) throw error
      await refresh()
    } finally {
      setSubmitting(false)
    }
  }

  async function chooseOptionB() {
    if (!pendingWin) return
    setSubmitting(true)
    try {
      const { error } = await supabase.rpc('submit_winner_choice', {
        p_won_challenge_id: pendingWin.daily_challenge_id,
        p_choice: 'B',
      })
      if (error) throw error
      await refresh()
    } finally {
      setSubmitting(false)
    }
  }

  return { pendingWin, loading, submitting, chooseOptionA, chooseOptionB, refresh }
}
