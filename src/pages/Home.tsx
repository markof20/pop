import { Link } from 'react-router-dom'
import { useAuth } from '../hooks/useAuth'
import { useCircles } from '../hooks/useCircles'
import { useProfile } from '../hooks/useProfile'
import { CATEGORY_ICON } from '../lib/style'

const CIRCLE_CARD_GRADIENT = 'bg-gradient-to-br from-pop-purple to-pop-pink'
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
    <div className="relative min-h-full overflow-hidden">
      <div
        aria-hidden
        className="animate-float pointer-events-none fixed -top-32 -left-24 h-96 w-96 rounded-full bg-pop-purple/25 blur-3xl dark:bg-pop-purple/20"
      />
      <div
        aria-hidden
        className="animate-float pointer-events-none fixed top-1/3 -right-32 h-80 w-80 rounded-full bg-pop-pink/25 blur-3xl dark:bg-pop-pink/15"
        style={{ animationDelay: '2s' }}
      />
      <div
        aria-hidden
        className="animate-float pointer-events-none fixed -bottom-32 left-1/4 h-96 w-96 rounded-full bg-pop-yellow/25 blur-3xl dark:bg-pop-yellow/10"
        style={{ animationDelay: '3.5s' }}
      />

      <div className="relative mx-auto flex max-w-2xl flex-col gap-6 px-4 py-10">
        <div className="glass shadow-glow animate-pop-in flex items-center justify-between rounded-3xl bg-gradient-to-br from-pop-purple to-pop-pink p-6 text-white">
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
          {circles.map((circle, i) => (
            <Link
              key={circle.id}
              to={`/circles/${circle.id}`}
              style={{ animationDelay: `${i * 60}ms` }}
              className="glass shadow-glow-sm animate-fade-in-up flex flex-col overflow-hidden rounded-3xl transition hover:-translate-y-1 hover:shadow-glow active:scale-[0.98]"
            >
              <div className={`flex h-24 items-center justify-center text-4xl ${CIRCLE_CARD_GRADIENT}`}>
                {circle.circle_type === 'gif' ? '🎬' : CATEGORY_ICON[circle.category]}
              </div>
              <div className="flex flex-1 flex-col gap-1 p-4">
                <h2 className="font-display line-clamp-2 text-base leading-tight font-bold">
                  {circle.name}
                </h2>
                <p className="text-xs text-neutral-500">
                  {circle.my_role === 'admin' ? '👑 Admin' : 'Membro'}
                </p>
              </div>
            </Link>
          ))}
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
