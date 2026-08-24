import type { CircleCategory } from '../types/database'

export const CATEGORY_ICON: Record<CircleCategory, string> = {
  amici: '👥',
  normal: '🎲',
  hot: '🔥',
}

function hashString(str: string) {
  return [...str].reduce((acc, ch) => acc + ch.charCodeAt(0), 0)
}

const AVATAR_COLORS = ['bg-pop-purple', 'bg-pop-pink', 'bg-pop-teal', 'bg-pop-yellow']

export function avatarColor(name: string) {
  return AVATAR_COLORS[hashString(name) % AVATAR_COLORS.length]
}

export const PILL_SELECTED = 'shadow-glow-sm border border-transparent bg-pop-purple text-white'
export const PILL_UNSELECTED =
  'border border-neutral-200 bg-white/50 text-neutral-500 backdrop-blur hover:border-neutral-300 dark:border-neutral-700 dark:bg-neutral-800/40 dark:text-neutral-400'

export function pillClass(selected: boolean) {
  return selected ? PILL_SELECTED : PILL_UNSELECTED
}
