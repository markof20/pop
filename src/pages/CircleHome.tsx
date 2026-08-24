import { useEffect, useState } from 'react'
import { useParams } from 'react-router-dom'
import { supabase } from '../lib/supabase'
import { CircleFeed } from './CircleFeed'
import { GifCircleFeed } from './GifCircleFeed'
import type { CircleType } from '../types/database'

// Smista tra i due tipi di cerchia: 'photo' usa l'intero ciclo prompt→foto→voto
// esistente, 'gif' sostituisce quel ciclo con frase→gif→voto. Il tipo si
// decide alla creazione della cerchia e non cambia più.
export function CircleHome() {
  const { id } = useParams<{ id: string }>()
  const [circleType, setCircleType] = useState<CircleType | null>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    if (!id) return
    supabase
      .from('circles')
      .select('circle_type')
      .eq('id', id)
      .single()
      .then(({ data }) => {
        setCircleType((data?.circle_type as CircleType | undefined) ?? 'photo')
        setLoading(false)
      })
  }, [id])

  if (loading) {
    return <div className="p-10 text-center text-neutral-500">Caricamento cerchia...</div>
  }

  return circleType === 'gif' ? <GifCircleFeed /> : <CircleFeed />
}
