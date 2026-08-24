import { avatarColor } from '../../lib/style'

interface AvatarProps {
  username: string
  avatarUrl?: string | null
  size?: number
  className?: string
}

export function Avatar({ username, avatarUrl, size = 32, className = '' }: AvatarProps) {
  const style = { width: size, height: size }

  if (avatarUrl) {
    return (
      <img
        src={avatarUrl}
        alt={username}
        style={style}
        className={`shrink-0 rounded-full border-2 border-white object-cover shadow-sm dark:border-neutral-900 ${className}`}
      />
    )
  }

  return (
    <div
      style={{ ...style, fontSize: size * 0.4 }}
      className={`flex shrink-0 items-center justify-center rounded-full border-2 border-white font-bold text-white shadow-sm dark:border-neutral-900 ${avatarColor(username)} ${className}`}
    >
      {username.charAt(0).toUpperCase()}
    </div>
  )
}
