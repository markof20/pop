import type { ButtonHTMLAttributes } from 'react'

type Variant = 'primary' | 'secondary' | 'outline' | 'danger' | 'ghost'
type Size = 'md' | 'lg'

interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: Variant
  size?: Size
  fullWidth?: boolean
}

const variantClasses: Record<Variant, string> = {
  primary: 'bg-pop-purple text-white shadow-glow-sm hover:brightness-105 active:scale-95',
  secondary: 'bg-pop-pink text-white shadow-glow-sm hover:brightness-105 active:scale-95',
  outline:
    'glass text-neutral-700 hover:bg-white/80 active:scale-95 dark:text-neutral-200 dark:hover:bg-neutral-800/70',
  danger:
    'border border-red-300 text-red-600 shadow-[0_8px_20px_-10px_rgba(220,38,38,0.45)] hover:bg-red-50 active:scale-95 dark:border-red-900 dark:text-red-400 dark:hover:bg-red-900/30',
  ghost: 'text-neutral-600 hover:underline dark:text-neutral-300',
}

const sizeClasses: Record<Size, string> = {
  md: 'px-4 py-2.5 text-sm rounded-xl',
  lg: 'px-6 py-3.5 text-base rounded-2xl',
}

export function Button({
  variant = 'primary',
  size = 'md',
  fullWidth = false,
  disabled,
  className = '',
  children,
  ...props
}: ButtonProps) {
  return (
    <button
      disabled={disabled}
      className={`font-display font-bold transition disabled:cursor-not-allowed disabled:opacity-50 disabled:active:scale-100 ${variantClasses[variant]} ${sizeClasses[size]} ${fullWidth ? 'w-full' : ''} ${className}`}
      {...props}
    >
      {children}
    </button>
  )
}
