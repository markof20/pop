import type { ReactNode } from 'react'

interface PhotoCardProps {
  src?: string
  alt?: string
  caption?: ReactNode
  badge?: ReactNode
  reveal?: boolean
  className?: string
}

export function PhotoCard({ src, alt = '', caption, badge, reveal = false, className = '' }: PhotoCardProps) {
  return (
    <div className={`glass shadow-glow-sm relative aspect-square w-full overflow-hidden rounded-2xl ${className}`}>
      {src && (
        <img
          src={src}
          alt={alt}
          className={`h-full w-full object-cover ${reveal ? 'animate-reveal' : ''}`}
        />
      )}
      {badge}
      {caption && (
        <div className="absolute inset-x-0 bottom-0 bg-gradient-to-t from-black/65 via-black/20 to-transparent px-3 pt-8 pb-2">
          <p className="truncate text-sm font-semibold text-white">{caption}</p>
        </div>
      )}
    </div>
  )
}
