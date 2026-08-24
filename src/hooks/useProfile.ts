import { useCallback, useEffect, useState } from 'react'
import { supabase } from '../lib/supabase'
import { useAuth } from './useAuth'
import type { Profile } from '../types/database'

export function useProfile() {
  const { user } = useAuth()
  const [profile, setProfile] = useState<Profile | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const refresh = useCallback(async () => {
    if (!user) {
      setProfile(null)
      setLoading(false)
      return
    }
    setLoading(true)
    const { data, error: fetchError } = await supabase
      .from('profiles')
      .select('*')
      .eq('id', user.id)
      .single()

    if (fetchError) setError(fetchError.message)
    else {
      setProfile(data as Profile)
      setError(null)
    }
    setLoading(false)
  }, [user])

  useEffect(() => {
    refresh()
  }, [refresh])

  const updateProfile = useCallback(
    async (patch: Partial<Pick<Profile, 'avatar_url' | 'gender'>>) => {
      if (!user) return
      const { error: updateError } = await supabase.from('profiles').update(patch).eq('id', user.id)
      if (updateError) {
        setError(updateError.message)
        throw updateError
      }
      await refresh()
    },
    [user, refresh],
  )

  return { profile, loading, error, refresh, updateProfile }
}
