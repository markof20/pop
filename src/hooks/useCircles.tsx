import { useCallback, useEffect, useState } from 'react'
import { supabase } from '../lib/supabase'
import { useAuth } from './useAuth'
import type { Circle, CircleCategory, CircleRole } from '../types/database'

interface CircleWithRole extends Circle {
  my_role: CircleRole
}

export function useCircles() {
  const { user } = useAuth()
  const [circles, setCircles] = useState<CircleWithRole[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const refresh = useCallback(async () => {
    if (!user) {
      setCircles([])
      setLoading(false)
      return
    }
    setLoading(true)
    const { data, error: fetchError } = await supabase
      .from('circle_members')
      .select('role, circles(*)')
      .eq('user_id', user.id)

    if (fetchError) {
      setError(fetchError.message)
      setLoading(false)
      return
    }

    const mapped = (data ?? [])
      .filter((row) => row.circles)
      .map((row) => ({
        ...(row.circles as unknown as Circle),
        my_role: row.role as CircleRole,
      }))

    setCircles(mapped)
    setError(null)
    setLoading(false)
  }, [user])

  useEffect(() => {
    refresh()
  }, [refresh])

  async function createCircle(name: string, category: CircleCategory = 'normal', timeWindowMinutes = 120) {
    const { data, error: rpcError } = await supabase.rpc('create_circle', {
      p_name: name,
      p_time_window_minutes: timeWindowMinutes,
      p_category: category,
    })
    if (rpcError) throw rpcError
    await refresh()
    return data as Circle
  }

  async function joinCircleByCode(inviteCode: string) {
    const { data, error: rpcError } = await supabase.rpc('join_circle_by_code', {
      p_invite_code: inviteCode.trim(),
    })
    if (rpcError) throw rpcError
    await refresh()
    return data as Circle
  }

  return { circles, loading, error, refresh, createCircle, joinCircleByCode }
}
