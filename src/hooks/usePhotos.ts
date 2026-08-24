import { useCallback, useEffect, useState } from 'react'
import { supabase } from '../lib/supabase'
import { useAuth } from './useAuth'
import type { PhotoWithProfile } from '../types/database'

const SIGNED_URL_TTL_SECONDS = 60 * 30

// Il nickname finisce nel path dello storage: va reso sicuro per un nome file
// (niente '/', spazi, accenti, emoji) restando leggibile.
function slugifyUsername(username: string) {
  const slug = username
    .normalize('NFKD')
    .replace(/\p{Diacritic}/gu, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
  return slug || 'user'
}

export function usePhotos(
  circleId: string | undefined,
  challengeId: string | undefined,
  challengeDate: string | undefined,
  options: { bypassGate?: boolean } = {},
) {
  const { user } = useAuth()
  const { bypassGate = false } = options
  const [myPhoto, setMyPhoto] = useState<PhotoWithProfile | null>(null)
  const [gridPhotos, setGridPhotos] = useState<PhotoWithProfile[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const refresh = useCallback(async () => {
    if (!challengeId || !user) return
    setLoading(true)

    const { data: mine, error: mineError } = await supabase
      .from('photos')
      .select('*, profiles(*)')
      .eq('daily_challenge_id', challengeId)
      .eq('user_id', user.id)
      .maybeSingle()

    if (mineError) {
      setError(mineError.message)
      setLoading(false)
      return
    }

    setMyPhoto(mine as PhotoWithProfile | null)

    // Il Game Master (proposed_by di oggi) non partecipa ma può comunque vedere la griglia.
    if (!mine && !bypassGate) {
      setGridPhotos([])
      setError(null)
      setLoading(false)
      return
    }

    const { data: all, error: allError } = await supabase
      .from('photos')
      .select('*, profiles(*)')
      .eq('daily_challenge_id', challengeId)

    if (allError) {
      setError(allError.message)
      setLoading(false)
      return
    }

    const { data: picks } = await supabase
      .from('top_picks')
      .select('photo_id')
      .eq('daily_challenge_id', challengeId)

    const countByPhoto = (picks ?? []).reduce<Record<string, number>>((acc, p) => {
      acc[p.photo_id] = (acc[p.photo_id] ?? 0) + 1
      return acc
    }, {})

    const withUrls = await Promise.all(
      (all ?? []).map(async (photo) => {
        const { data: signed } = await supabase.storage
          .from('photos')
          .createSignedUrl(photo.storage_path, SIGNED_URL_TTL_SECONDS)
        return {
          ...photo,
          signed_url: signed?.signedUrl,
          top_pick_count: countByPhoto[photo.id] ?? 0,
        } as PhotoWithProfile
      }),
    )

    const ranked = withUrls.sort((a, b) => {
      const byVotes = (b.top_pick_count ?? 0) - (a.top_pick_count ?? 0)
      if (byVotes !== 0) return byVotes
      return new Date(a.created_at).getTime() - new Date(b.created_at).getTime()
    })

    setGridPhotos(ranked)
    setError(null)
    setLoading(false)
  }, [challengeId, user, bypassGate])

  useEffect(() => {
    refresh()
  }, [refresh])

  async function submitPhoto(blob: Blob) {
    if (!circleId || !challengeId || !challengeDate || !user) throw new Error('Missing context')

    const { data: profile } = await supabase
      .from('profiles')
      .select('username')
      .eq('id', user.id)
      .single()
    const nickname = slugifyUsername(profile?.username ?? user.id)

    const storagePath = `${circleId}/${challengeDate}/${nickname}.jpg`

    const { error: uploadError } = await supabase.storage
      .from('photos')
      .upload(storagePath, blob, { contentType: 'image/jpeg', upsert: true })
    if (uploadError) throw uploadError

    const { error: insertError } = await supabase.from('photos').insert({
      daily_challenge_id: challengeId,
      user_id: user.id,
      storage_path: storagePath,
    })
    if (insertError) throw insertError

    await refresh()
  }

  return { myPhoto, gridPhotos, loading, error, refresh, submitPhoto }
}
