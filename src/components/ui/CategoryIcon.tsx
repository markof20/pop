import type { ReactElement } from 'react'
import type { CircleCategory, CircleType } from '../../types/database'

interface IconProps {
  size?: number
}

function PeopleIcon({ size = 18 }: IconProps) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth={2.2}
      strokeLinecap="round"
      strokeLinejoin="round"
    >
      <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" />
      <circle cx="9" cy="7" r="4" />
      <path d="M23 21v-2a4 4 0 0 0-3-3.87" />
      <path d="M16 3.13a4 4 0 0 1 0 7.75" />
    </svg>
  )
}

function DiceIcon({ size = 18 }: IconProps) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth={2.2}
      strokeLinecap="round"
      strokeLinejoin="round"
    >
      <rect x="3" y="3" width="18" height="18" rx="5" />
      <circle cx="8" cy="8" r="1.1" fill="currentColor" stroke="none" />
      <circle cx="16" cy="8" r="1.1" fill="currentColor" stroke="none" />
      <circle cx="12" cy="12" r="1.1" fill="currentColor" stroke="none" />
      <circle cx="8" cy="16" r="1.1" fill="currentColor" stroke="none" />
      <circle cx="16" cy="16" r="1.1" fill="currentColor" stroke="none" />
    </svg>
  )
}

function FlameIcon({ size = 18 }: IconProps) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="currentColor" stroke="none">
      <path d="M8.5 14.5A2.5 2.5 0 0 0 11 12c0-1.38-.5-2-1-3-1.072-2.143-.224-4.054 2-6 .5 2.5 2 4.9 4 6.5 2 1.5 3 3.5 3 5.5a7 7 0 1 1-14 0c0-1.153.433-2.294 1-3a2.5 2.5 0 0 0 2.5 2.5z" />
    </svg>
  )
}

function ClapperboardIcon({ size = 18 }: IconProps) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth={2.2}
      strokeLinecap="round"
      strokeLinejoin="round"
    >
      <rect x="3" y="8" width="18" height="13" rx="2" />
      <path d="M3 8l2-5h4l-2 5" />
      <path d="M9 8l2-5h4l-2 5" />
      <path d="M15 8l2-5h3l-2 5" />
    </svg>
  )
}

const CONFIG: Record<string, { bg: string; icon: (props: IconProps) => ReactElement }> = {
  amici: { bg: 'bg-pop-purple', icon: PeopleIcon },
  normal: { bg: 'bg-pop-teal', icon: DiceIcon },
  hot: { bg: 'bg-pop-pink', icon: FlameIcon },
  gif: { bg: 'bg-pop-yellow', icon: ClapperboardIcon },
}

// Stessa mappatura categoria→colore/icona usata sia dal chip qui sotto sia
// dalla fascia colorata a piena larghezza delle card cerchia in Home.tsx.
export function getCategoryStyle(category: CircleCategory, circleType: CircleType) {
  return CONFIG[circleType === 'gif' ? 'gif' : category] ?? CONFIG.normal
}

interface CategoryIconProps {
  category: CircleCategory
  circleType: CircleType
  size?: number
  className?: string
}

export function CategoryIcon({ category, circleType, size = 36, className = '' }: CategoryIconProps) {
  const { bg, icon: Icon } = getCategoryStyle(category, circleType)
  return (
    <div
      style={{ width: size, height: size }}
      className={`flex shrink-0 items-center justify-center rounded-xl text-white ${bg} ${className}`}
    >
      <Icon size={size * 0.5} />
    </div>
  )
}
