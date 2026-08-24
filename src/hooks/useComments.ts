import { useCallback, useEffect, useState } from 'react'
import { supabase } from '../lib/supabase'
import { useAuth } from './useAuth'
import type { CommentWithProfile } from '../types/database'

export function useComments(photoId: string | undefined) {
  const { user } = useAuth()
  const [comments, setComments] = useState<CommentWithProfile[]>([])
  const [loading, setLoading] = useState(true)
  const [posting, setPosting] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const load = useCallback(async () => {
    if (!photoId) return
    setLoading(true)
    const { data, error: fetchError } = await supabase
      .from('comments')
      .select('*, profiles(*)')
      .eq('photo_id', photoId)
      .order('created_at', { ascending: true })

    if (fetchError) setError(fetchError.message)
    else {
      setComments((data ?? []) as unknown as CommentWithProfile[])
      setError(null)
    }
    setLoading(false)
  }, [photoId])

  useEffect(() => {
    load()
  }, [load])

  const addComment = useCallback(
    async (body: string) => {
      if (!photoId || !user) return
      const trimmed = body.trim()
      if (!trimmed) return
      setPosting(true)
      const { error: insertError } = await supabase
        .from('comments')
        .insert({ photo_id: photoId, user_id: user.id, body: trimmed })
      setPosting(false)
      if (insertError) {
        setError(insertError.message)
        throw insertError
      }
      await load()
    },
    [photoId, user, load],
  )

  const deleteComment = useCallback(
    async (commentId: string) => {
      const { error: deleteError } = await supabase.from('comments').delete().eq('id', commentId)
      if (deleteError) setError(deleteError.message)
      else await load()
    },
    [load],
  )

  return { comments, loading, posting, error, addComment, deleteComment }
}
