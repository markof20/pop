import type { ElementType, ComponentPropsWithoutRef } from 'react'

type CardProps<T extends ElementType> = {
  as?: T
  className?: string
} & Omit<ComponentPropsWithoutRef<T>, 'as' | 'className'>

export function Card<T extends ElementType = 'div'>({
  as,
  className = '',
  children,
  ...props
}: CardProps<T>) {
  const Component = as ?? 'div'
  return (
    <Component
      className={`glass shadow-glow rounded-3xl p-5 transition ${className}`}
      {...props}
    >
      {children}
    </Component>
  )
}
