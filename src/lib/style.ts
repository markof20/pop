import type { CircleCategory } from '../types/database'

export const CATEGORY_ICON: Record<CircleCategory, string> = {
  amici: '👥',
  normal: '🎲',
  hot: '🔥',
}

function hashString(str: string) {
  return [...str].reduce((acc, ch) => acc + ch.charCodeAt(0), 0)
}

const AVATAR_GRADIENTS = [
  'bg-gradient-to-br from-pop-purple to-pop-pink',
  'bg-gradient-to-br from-pop-pink to-pop-yellow',
  'bg-gradient-to-br from-pop-yellow to-pop-purple',
  'bg-gradient-to-br from-pop-purple-dark to-pop-purple',
]

export function avatarGradient(name: string) {
  return AVATAR_GRADIENTS[hashString(name) % AVATAR_GRADIENTS.length]
}

export const PILL_SELECTED = 'shadow-glow-sm border border-transparent bg-pop-purple text-white'
export const PILL_UNSELECTED =
  'border border-neutral-200 bg-white/50 text-neutral-500 backdrop-blur hover:border-neutral-300 dark:border-neutral-700 dark:bg-neutral-800/40 dark:text-neutral-400'

export function pillClass(selected: boolean) {
  return selected ? PILL_SELECTED : PILL_UNSELECTED
}
