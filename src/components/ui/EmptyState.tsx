interface EmptyStateProps {
  icon: string
  text: string
}

export function EmptyState({ icon, text }: EmptyStateProps) {
  return (
    <div className="flex flex-col items-center gap-2 rounded-3xl border-2 border-dashed border-neutral-300 p-8 text-center dark:border-neutral-700">
      <span className="text-4xl">{icon}</span>
      <p className="text-sm text-neutral-500">{text}</p>
    </div>
  )
}
