import { Link } from 'react-router-dom'
import { useAuth } from '../hooks/useAuth'
import { useCircles } from '../hooks/useCircles'
import { useProfile } from '../hooks/useProfile'
import { getCategoryStyle } from '../components/ui/CategoryIcon'
import { Avatar } from '../components/ui/Avatar'
import { Onboarding } from './Onboarding'

export function Home() {
  const { user, signOut } = useAuth()
  const { circles, loading } = useCircles()
  const { profile } = useProfile()

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
        <div className="glass shadow-glow animate-pop-in flex items-center justify-between rounded-3xl bg-pop-purple p-6 text-white">
          <div>
            <p className="text-sm font-medium text-white/70">Ciao, {username} 👋</p>
            <h1 className="font-display text-2xl font-extrabold">Le tue cerchie</h1>
          </div>
          <div className="flex items-center gap-2">
            <Link to="/profile" title="Il tuo profilo">
              <Avatar
                username={username}
                avatarUrl={profile?.avatar_url}
                size={36}
                className="border-white/40!"
              />
            </Link>
            <button
              onClick={() => signOut()}
              className="rounded-full bg-black/15 px-3 py-1.5 text-sm font-semibold text-white/90 transition hover:bg-black/25 active:scale-95"
            >
              Esci
            </button>
          </div>
        </div>

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
          className="flex items-center justify-center gap-2 rounded-3xl border-2 border-dashed border-neutral-300 p-5 text-center font-display font-bold text-neutral-500 transition hover:border-pop-purple hover:text-pop-purple hover:bg-white/50 active:scale-[0.98] dark:border-neutral-700"
        >
          <span className="text-xl">➕</span> Crea o unisciti a un'altra cerchia
        </Link>
      </div>
    </div>
  )
}
