import { useState } from 'react'
import type { FormEvent } from 'react'
import { Navigate, useLocation } from 'react-router-dom'
import { useAuth } from '../hooks/useAuth'
import { supabase } from '../lib/supabase'
import { Button } from '../components/ui/Button'

const inputClasses =
  'w-full rounded-xl border-2 border-neutral-200 px-4 py-2.5 outline-none transition focus:border-pop-purple dark:border-neutral-700 dark:bg-neutral-800'

export function Login() {
  const { user, signIn, signUp } = useAuth()
  const location = useLocation()
  const [mode, setMode] = useState<'login' | 'signup'>('login')
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [username, setUsername] = useState('')
  const [error, setError] = useState<string | null>(null)
  const [submitting, setSubmitting] = useState(false)
  const [confirmationSent, setConfirmationSent] = useState(false)

  if (user) {
    const redirectTo = (location.state as { from?: string } | null)?.from ?? '/'
    return <Navigate to={redirectTo} replace />
  }

  async function handleSubmit(e: FormEvent) {
    e.preventDefault()
    setError(null)
    setSubmitting(true)
    try {
      if (mode === 'signup') {
        const trimmedUsername = username.trim()
        const { data: taken, error: checkError } = await supabase.rpc('is_username_taken', {
          p_username: trimmedUsername,
        })
        if (checkError) throw checkError
        if (taken) {
          setError('Questo nickname è già in uso, scegline un altro')
          return
        }

        await signUp(email, password, trimmedUsername)
        setConfirmationSent(true)
      } else {
        await signIn(email, password)
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Qualcosa è andato storto')
    } finally {
      setSubmitting(false)
    }
  }

  return (
    <div className="relative flex min-h-full flex-col items-center justify-center gap-8 overflow-hidden bg-gradient-to-br from-pop-purple via-pop-purple-dark to-pop-pink px-4 py-12">
      <div
        aria-hidden
        className="pointer-events-none absolute -top-24 -left-16 h-72 w-72 rounded-full bg-pop-yellow/40 blur-3xl"
      />
      <div
        aria-hidden
        className="pointer-events-none absolute -right-20 top-1/3 h-80 w-80 rounded-full bg-white/20 blur-3xl"
      />
      <div
        aria-hidden
        className="pointer-events-none absolute -bottom-24 left-1/4 h-72 w-72 rounded-full bg-pop-pink/40 blur-3xl"
      />

      <div className="relative text-center animate-bounce-in">
        <h1 className="font-display text-6xl font-extrabold tracking-tight text-white drop-shadow-lg">
          POP <span className="inline-block">📸</span>
        </h1>
        <p className="mt-2 font-medium text-white/80">Prompt Of the day Photo</p>
      </div>

      <div className="relative w-full max-w-sm animate-pop-in rounded-3xl border border-white/40 bg-white/85 p-6 shadow-2xl backdrop-blur-xl dark:border-white/10 dark:bg-neutral-900/70">
        <div className="mb-6 flex rounded-full bg-neutral-100 p-1 dark:bg-neutral-800">
          <button
            type="button"
            onClick={() => setMode('login')}
            className={`flex-1 rounded-full py-2 text-sm font-semibold transition ${
              mode === 'login'
                ? 'bg-white text-pop-purple shadow dark:bg-neutral-700 dark:text-white'
                : 'text-neutral-500'
            }`}
          >
            Accedi
          </button>
          <button
            type="button"
            onClick={() => setMode('signup')}
            className={`flex-1 rounded-full py-2 text-sm font-semibold transition ${
              mode === 'signup'
                ? 'bg-white text-pop-purple shadow dark:bg-neutral-700 dark:text-white'
                : 'text-neutral-500'
            }`}
          >
            Registrati
          </button>
        </div>

        {confirmationSent ? (
          <p className="text-center text-sm text-neutral-600 dark:text-neutral-300">
            📬 Controlla la tua email per confermare l'account, poi accedi.
          </p>
        ) : (
          <form onSubmit={handleSubmit} className="flex flex-col gap-4">
            {mode === 'signup' && (
              <div>
                <label className="mb-1 block text-sm font-medium text-neutral-700 dark:text-neutral-300">
                  Username
                </label>
                <input
                  required
                  minLength={3}
                  value={username}
                  onChange={(e) => setUsername(e.target.value)}
                  className={inputClasses}
                  placeholder="mario_rossi"
                />
              </div>
            )}
            <div>
              <label className="mb-1 block text-sm font-medium text-neutral-700 dark:text-neutral-300">
                Email
              </label>
              <input
                required
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                className={inputClasses}
                placeholder="tu@esempio.com"
              />
            </div>
            <div>
              <label className="mb-1 block text-sm font-medium text-neutral-700 dark:text-neutral-300">
                Password
              </label>
              <input
                required
                minLength={6}
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                className={inputClasses}
                placeholder="••••••••"
              />
            </div>

            {error && <p className="text-sm text-red-500">{error}</p>}

            <Button type="submit" size="lg" fullWidth disabled={submitting} className="mt-2">
              {submitting ? 'Un attimo...' : mode === 'login' ? 'Accedi' : 'Crea account'}
            </Button>
          </form>
        )}
      </div>
    </div>
  )
}
