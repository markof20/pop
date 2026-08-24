import { useCallback, useEffect, useState } from 'react'
import type { FormEvent } from 'react'
import { Link, useParams } from 'react-router-dom'
import { supabase } from '../lib/supabase'
import { useAuth } from '../hooks/useAuth'
import { useComments } from '../hooks/useComments'
import { PhotoCard } from '../components/ui/PhotoCard'
import { Button } from '../components/ui/Button'
import { Avatar } from '../components/ui/Avatar'
import type { PhotoWithProfile, Reaction } from '../types/database'

const EMOJI_OPTIONS = ['😂', '😍', '🔥', '😱', '👏', '💀']
const SIGNED_URL_TTL_SECONDS = 60 * 30

function CommentsSection({ photoId, currentUserId }: { photoId: string; currentUserId?: string }) {
  const { comments, loading, posting, error, addComment, deleteComment } = useComments(photoId)
  const [draft, setDraft] = useState('')

  async function handleSubmit(e: FormEvent) {
    e.preventDefault()
    if (!draft.trim()) return
    try {
      await addComment(draft)
      setDraft('')
    } catch {
      // l'errore è già mostrato sotto la lista
    }
  }

  return (
    <div className="mt-1 flex flex-col gap-3 border-t border-neutral-200 pt-4 dark:border-neutral-800">
      <p className="font-display text-sm font-bold text-neutral-500 dark:text-neutral-400">
        💬 Commenti{comments.length > 0 ? ` (${comments.length})` : ''}
      </p>

      {loading ? (
        <p className="text-sm text-neutral-400">Carico i commenti...</p>
      ) : comments.length === 0 ? (
        <p className="text-sm text-neutral-400">Ancora nessun commento. Scrivi il primo!</p>
      ) : (
        <div className="flex max-h-72 flex-col gap-3 overflow-y-auto pr-1">
          {comments.map((comment) => (
            <div key={comment.id} className="group flex items-start gap-2.5">
              <Avatar
                username={comment.profiles?.username ?? '?'}
                avatarUrl={comment.profiles?.avatar_url}
                size={32}
                className="mt-0.5"
              />
              <div className="min-w-0 flex-1">
                <p className="text-sm break-words">
                  <span className="font-display font-bold">{comment.profiles?.username}</span>{' '}
                  <span className="text-neutral-600 dark:text-neutral-300">{comment.body}</span>
                </p>
                <p className="text-xs text-neutral-400">
                  {new Date(comment.created_at).toLocaleTimeString('it-IT', {
                    hour: '2-digit',
                    minute: '2-digit',
                  })}
                </p>
              </div>
              {comment.user_id === currentUserId && (
                <button
                  onClick={() => deleteComment(comment.id)}
                  title="Elimina commento"
                  className="text-xs text-neutral-400 opacity-0 transition hover:text-red-500 group-hover:opacity-100"
                >
                  ✕
                </button>
              )}
            </div>
          ))}
        </div>
      )}

      {error && <p className="text-sm text-red-500">{error}</p>}

      <form onSubmit={handleSubmit} className="flex gap-2">
        <input
          value={draft}
          onChange={(e) => setDraft(e.target.value)}
          maxLength={500}
          placeholder="Scrivi un commento..."
          className="flex-1 rounded-full border border-neutral-200 bg-white/60 px-4 py-2 text-sm outline-none backdrop-blur focus:border-pop-purple dark:border-neutral-700 dark:bg-neutral-800/60"
        />
        <Button type="submit" disabled={posting || !draft.trim()}>
          Invia
        </Button>
      </form>
    </div>
  )
}

export function PhotoDetail() {
  const { id, photoId } = useParams<{ id: string; photoId: string }>()
  const { user } = useAuth()

  const [photo, setPhoto] = useState<PhotoWithProfile | null>(null)
  const [reactions, setReactions] = useState<Reaction[]>([])
  const [myTopPickPhotoId, setMyTopPickPhotoId] = useState<string | null>(null)
  const [topPickers, setTopPickers] = useState<string[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [actionError, setActionError] = useState<string | null>(null)
  const [votingBusy, setVotingBusy] = useState(false)

  const isMine = photo?.user_id === user?.id

  const load = useCallback(async () => {
    if (!photoId || !user) return
    setLoading(true)

    const { data: photoData, error: photoError } = await supabase
      .from('photos')
      .select('*, profiles(*)')
      .eq('id', photoId)
      .single()

    if (photoError) {
      setError(photoError.message)
      setLoading(false)
      return
    }

    const { data: signed } = await supabase.storage
      .from('photos')
      .createSignedUrl(photoData.storage_path, SIGNED_URL_TTL_SECONDS)

    const { data: reactionData } = await supabase
      .from('reactions')
      .select('*')
      .eq('photo_id', photoId)
      .order('created_at', { ascending: true })

    const { data: topPickData } = await supabase
      .from('top_picks')
      .select('photo_id')
      .eq('daily_challenge_id', photoData.daily_challenge_id)
      .eq('voter_id', user.id)
      .maybeSingle()

    const { data: pickersData } = await supabase
      .from('top_picks')
      .select('profiles(username)')
      .eq('photo_id', photoId)

    setPhoto({ ...photoData, signed_url: signed?.signedUrl } as PhotoWithProfile)
    setReactions(reactionData ?? [])
    setMyTopPickPhotoId(topPickData?.photo_id ?? null)
    setTopPickers(
      (pickersData ?? [])
        .map((row) => (row.profiles as unknown as { username: string } | null)?.username)
        .filter((username): username is string => Boolean(username)),
    )
    setError(null)
    setLoading(false)
  }, [photoId, user])

  useEffect(() => {
    load()
  }, [load])

  async function handleReact(emoji: string) {
    if (!photoId || !user) return

    const myReaction = reactions.find((r) => r.user_id === user.id)

    setActionError(null)

    if (myReaction?.emoji === emoji) {
      // stessa emoji ricliccata: la rimuove
      const { error: deleteError } = await supabase
        .from('reactions')
        .delete()
        .eq('photo_id', photoId)
        .eq('user_id', user.id)
      if (deleteError) {
        setActionError(deleteError.message)
        return
      }
    } else {
      const { error: upsertError } = await supabase
        .from('reactions')
        .upsert({ photo_id: photoId, user_id: user.id, emoji }, { onConflict: 'photo_id,user_id' })
      if (upsertError) {
        setActionError(upsertError.message)
        return
      }
    }

    await load()
  }

  async function handleTopPick() {
    if (!photo || !user || isMine) return
    setVotingBusy(true)
    setActionError(null)
    const { error: upsertError } = await supabase.from('top_picks').upsert(
      {
        daily_challenge_id: photo.daily_challenge_id,
        voter_id: user.id,
        photo_id: photo.id,
      },
      { onConflict: 'daily_challenge_id,voter_id' },
    )
    if (upsertError) setActionError(upsertError.message)
    else await load()
    setVotingBusy(false)
  }

  if (loading) {
    return <div className="p-10 text-center text-neutral-500">Carico la foto...</div>
  }

  if (error || !photo) {
    return <div className="p-10 text-center text-red-500">{error ?? 'Foto non trovata'}</div>
  }

  const isTopPicked = myTopPickPhotoId === photo.id

  const reactionCounts = reactions.reduce<Record<string, number>>((acc, r) => {
    acc[r.emoji] = (acc[r.emoji] ?? 0) + 1
    return acc
  }, {})

  const myReactionEmoji = reactions.find((r) => r.user_id === user?.id)?.emoji ?? null

  return (
    <div className="mx-auto flex max-w-lg flex-col gap-4 px-4 py-6">
      <Link to={`/circles/${id}`} className="text-sm font-medium text-neutral-500 hover:underline">
        ← Griglia
      </Link>

      <div className="mx-auto w-full max-w-sm">
        <PhotoCard
          src={photo.signed_url}
          alt={photo.profiles?.username}
          reveal
          className="animate-pop-in mx-auto"
        />
      </div>

      <div className="flex items-center justify-between gap-3">
        <p className="font-display font-bold">
          {photo.profiles?.username}
          {photo.is_late && (
            <span className="ml-2 rounded-full bg-amber-100 px-2 py-0.5 text-xs font-medium text-amber-700 dark:bg-amber-900/40 dark:text-amber-400">
              in ritardo
            </span>
          )}
        </p>
        {isMine ? (
          <span className="text-sm text-neutral-400">È la tua foto</span>
        ) : (
          <button
            key={isTopPicked ? 'picked' : 'unpicked'}
            onClick={handleTopPick}
            disabled={votingBusy}
            title={isTopPicked ? 'Top pick assegnato' : 'Dai il top pick'}
            className={`flex h-14 w-14 shrink-0 items-center justify-center rounded-full text-2xl transition active:scale-90 disabled:opacity-50 ${
              isTopPicked
                ? 'animate-pop-select shadow-glow-sm bg-gradient-to-br from-pop-purple to-pop-pink text-white'
                : 'glass text-neutral-400 hover:text-pop-purple dark:text-neutral-500'
            }`}
          >
            ⭐
          </button>
        )}
      </div>

      {actionError && <p className="text-sm text-red-500">{actionError}</p>}

      {topPickers.length > 0 && (
        <p className="text-sm text-neutral-500">
          ⭐ Top pick da:{' '}
          <span className="font-medium text-neutral-700 dark:text-neutral-200">
            {topPickers.join(', ')}
          </span>
        </p>
      )}

      <div className="flex flex-wrap gap-2">
        {EMOJI_OPTIONS.map((emoji) => (
          <button
            key={emoji}
            onClick={() => handleReact(emoji)}
            className={`flex items-center gap-1.5 rounded-full px-4 py-2.5 text-lg transition active:scale-90 ${
              myReactionEmoji === emoji
                ? 'shadow-glow-sm bg-pop-purple/15 ring-2 ring-pop-purple'
                : 'glass hover:bg-white/80 dark:hover:bg-neutral-800/70'
            }`}
          >
            <span>{emoji}</span>
            {reactionCounts[emoji] > 0 && (
              <span className="text-sm text-neutral-500">{reactionCounts[emoji]}</span>
            )}
          </button>
        ))}
      </div>

      <CommentsSection photoId={photo.id} currentUserId={user?.id} />
    </div>
  )
}
