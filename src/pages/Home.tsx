import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { useAuth } from '../hooks/useAuth'
import { useCircles } from '../hooks/useCircles'
import { useProfile } from '../hooks/useProfile'
import { supabase } from '../lib/supabase'
import { getCategoryStyle } from '../components/ui/CategoryIcon'
import { Avatar } from '../components/ui/Avatar'
import { Onboarding } from './Onboarding'

export function Home() {
  const { user, signOut } = useAuth()
  const { circles, loading } = useCircles()
  const { profile } = useProfile()
  const [maxStreak, setMaxStreak] = useState<number | null>(null)

  useEffect(() => {
    if (!user) return
    supabase
      .from('user_streaks')
      .select('current_streak')
      .eq('user_id', user.id)
      .then(({ data }) => {
        const max = (data ?? []).reduce((m, row) => Math.max(m, row.current_streak as number), 0)
        setMaxStreak(max)
      })
  }, [user])

  if (loading) {
    return <div className="p-10 text-center text-neutral-500">Caricamento cerchie...</div>
  }

  if (circles.length === 0) {
    return <Onboarding />
  }

  const username = (user?.user_metadata?.username as string | undefined) ?? 'amico'

  return (
    <div className="relative min-h-full">
      <div className="relative mx-auto flex max-w-2xl flex-col gap-6 px-4 py-10">
        <div className="flex items-center justify-between">
          <div>
            <h1 className="font-display text-3xl font-bold">Ciao {username}</h1>
            <p className="mt-0.5 text-sm text-neutral-500">
              {circles.length} cerchi{circles.length === 1 ? 'a' : 'e'} attiv{circles.length === 1 ? 'a' : 'e'}
            </p>
          </div>
          <div className="flex items-center gap-3">
            <button
              onClick={() => signOut()}
              className="text-xs font-medium text-neutral-400 transition hover:text-neutral-600 dark:hover:text-neutral-200"
            >
              Esci
            </button>
            <Link to="/profile" title="Il tuo profilo">
              <Avatar username={username} avatarUrl={profile?.avatar_url} size={44} />
            </Link>
          </div>
        </div>

        {maxStreak !== null && (
          <div className="shadow-glow animate-pop-in flex items-center justify-between rounded-3xl bg-neutral-900 p-4 text-white">
            <div className="flex items-center gap-3">
              <span className={`text-2xl ${maxStreak > 0 ? '' : 'opacity-40 grayscale'}`}>🔥</span>
              <div>
                <p className="text-sm font-bold">
                  {maxStreak > 0
                    ? `${maxStreak} giorn${maxStreak === 1 ? 'o' : 'i'} di streak`
                    : 'Nessuno streak attivo'}
                </p>
                <p className="text-xs text-neutral-400">
                  {maxStreak > 0 ? 'Continua così!' : 'Carica una foto oggi per iniziare'}
                </p>
              </div>
            </div>
            <span className="text-2xl">🏆</span>
          </div>
        )}

        <div className="grid grid-cols-2 gap-4">
          {circles.map((circle, i) => {
            const { bg, icon: Icon } = getCategoryStyle(circle.category, circle.circle_type)
            return (
              <Link
                key={circle.id}
                to={`/circles/${circle.id}`}
                style={{ animationDelay: `${i * 60}ms` }}
                className="glass shadow-glow-sm animate-fade-in-up flex flex-col overflow-hidden rounded-3xl transition hover:-translate-y-1 hover:shadow-glow active:scale-[0.98]"
              >
                <div className={`flex h-16 items-center justify-center text-white ${bg}`}>
                  <Icon size={26} />
                </div>
                <div className="flex flex-1 flex-col gap-2 p-4">
                  <h2 className="font-display line-clamp-2 text-base leading-tight font-bold">
                    {circle.name}
                  </h2>
                  <span
                    className={`w-fit rounded-full px-2 py-0.5 text-xs font-semibold ${
                      circle.my_role === 'admin'
                        ? 'bg-pop-purple/10 text-pop-purple'
                        : 'bg-neutral-100 text-neutral-500 dark:bg-neutral-800 dark:text-neutral-400'
                    }`}
                  >
                    {circle.my_role === 'admin' ? '👑 Admin' : 'Membro'}
                  </span>
                </div>
              </Link>
            )
          })}
        </div>

        <Link
          to="/onboarding"
          className="shadow-glow-sm animate-pop-in flex items-center justify-center gap-2 rounded-2xl bg-pop-purple px-5 py-4 text-center font-display font-bold text-white transition hover:brightness-105 active:scale-[0.98]"
        >
          <svg
            width="16"
            height="16"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            strokeWidth={2.4}
            strokeLinecap="round"
            strokeLinejoin="round"
          >
            <path d="M12 5v14M5 12h14" />
          </svg>
          Crea o unisciti a un'altra cerchia
        </Link>
      </div>
    </div>
  )
}
