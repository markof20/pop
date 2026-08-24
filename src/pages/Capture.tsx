import { useEffect, useRef, useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { useDailyChallenge } from '../hooks/useDailyChallenge'
import { usePhotos } from '../hooks/usePhotos'
import { Button } from '../components/ui/Button'

const MAX_ATTEMPTS = 2

export function Capture() {
  const { id } = useParams<{ id: string }>()
  const navigate = useNavigate()
  const { challenge } = useDailyChallenge(id)
  const { submitPhoto } = usePhotos(id, challenge?.id, challenge?.challenge_date)

  const videoRef = useRef<HTMLVideoElement>(null)
  const streamRef = useRef<MediaStream | null>(null)
  const [facingMode, setFacingMode] = useState<'environment' | 'user'>('environment')
  const [cameraError, setCameraError] = useState<string | null>(null)
  const [capturedBlob, setCapturedBlob] = useState<Blob | null>(null)
  const [previewUrl, setPreviewUrl] = useState<string | null>(null)
  const [attempts, setAttempts] = useState(0)
  const [submitting, setSubmitting] = useState(false)
  const [submitError, setSubmitError] = useState<string | null>(null)

  useEffect(() => {
    let cancelled = false

    async function startCamera() {
      try {
        const stream = await navigator.mediaDevices.getUserMedia({
          video: {
            facingMode,
            width: { ideal: 1920 },
            height: { ideal: 1920 },
          },
          audio: false,
        })
        if (cancelled) {
          stream.getTracks().forEach((t) => t.stop())
          return
        }
        streamRef.current = stream
        if (videoRef.current) videoRef.current.srcObject = stream
        setCameraError(null)
      } catch {
        setCameraError('Non riesco ad accedere alla fotocamera. Controlla i permessi del browser.')
      }
    }

    if (!capturedBlob) startCamera()

    return () => {
      cancelled = true
      streamRef.current?.getTracks().forEach((t) => t.stop())
    }
  }, [capturedBlob, facingMode])

  function handleFlipCamera() {
    setFacingMode((m) => (m === 'environment' ? 'user' : 'environment'))
  }

  function handleCapture() {
    const video = videoRef.current
    if (!video) return

    const canvas = document.createElement('canvas')
    canvas.width = video.videoWidth
    canvas.height = video.videoHeight
    const ctx = canvas.getContext('2d')
    if (!ctx) return
    if (facingMode === 'user') {
      // La preview della frontale è specchiata (aspetto naturale da "selfie"): lo scatto
      // deve esserlo allo stesso modo, altrimenti la foto salvata sembra invertita.
      ctx.translate(canvas.width, 0)
      ctx.scale(-1, 1)
    }
    ctx.drawImage(video, 0, 0, canvas.width, canvas.height)

    canvas.toBlob(
      (blob) => {
        if (!blob) return
        streamRef.current?.getTracks().forEach((t) => t.stop())
        setCapturedBlob(blob)
        setPreviewUrl(URL.createObjectURL(blob))
        setAttempts((n) => n + 1)
      },
      'image/jpeg',
      0.85,
    )
  }

  function handleRetake() {
    if (previewUrl) URL.revokeObjectURL(previewUrl)
    setCapturedBlob(null)
    setPreviewUrl(null)
  }

  async function handleConfirm() {
    if (!capturedBlob) return
    setSubmitting(true)
    setSubmitError(null)
    try {
      await submitPhoto(capturedBlob)
      navigate(`/circles/${id}`)
    } catch (err) {
      setSubmitError(err instanceof Error ? err.message : 'Upload fallito, riprova')
      setSubmitting(false)
    }
  }

  if (cameraError) {
    return (
      <div className="flex h-dvh flex-col items-center justify-center gap-4 p-8 text-center">
        <span className="text-4xl">🚫📷</span>
        <p className="text-red-500">{cameraError}</p>
        <Button variant="outline" onClick={() => navigate(`/circles/${id}`)}>
          Torna indietro
        </Button>
      </div>
    )
  }

  return (
    <div className="relative flex h-dvh flex-col bg-black">
      {previewUrl ? (
        <img
          src={previewUrl}
          alt="Anteprima scatto"
          className="animate-fade-in-up h-full w-full flex-1 object-cover"
        />
      ) : (
        <video
          ref={videoRef}
          autoPlay
          playsInline
          muted
          className={`h-full w-full flex-1 object-cover ${facingMode === 'user' ? 'scale-x-[-1]' : ''}`}
        />
      )}

      <div className="pointer-events-none absolute inset-x-0 top-0 h-32 bg-gradient-to-b from-black/60 to-transparent" />
      <div className="pointer-events-none absolute inset-x-0 bottom-0 h-48 bg-gradient-to-t from-black/70 to-transparent" />

      <div className="absolute inset-x-0 top-0 flex items-center justify-between p-4">
        <button
          onClick={() => navigate(`/circles/${id}`)}
          className="rounded-full bg-black/40 px-3 py-1.5 text-sm font-medium text-white backdrop-blur-sm transition active:scale-95"
        >
          ✕ Annulla
        </button>
        {!previewUrl && (
          <button
            onClick={handleFlipCamera}
            aria-label="Cambia fotocamera"
            className="group flex h-11 w-11 items-center justify-center rounded-full bg-black/40 text-white backdrop-blur-sm transition active:scale-90"
          >
            <svg
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              strokeWidth={2}
              strokeLinecap="round"
              strokeLinejoin="round"
              className="h-5 w-5 transition-transform duration-300 group-active:rotate-180"
            >
              <path d="M17 2l4 4-4 4" />
              <path d="M3 11V9a4 4 0 0 1 4-4h14" />
              <path d="M7 22l-4-4 4-4" />
              <path d="M21 13v2a4 4 0 0 1-4 4H3" />
            </svg>
          </button>
        )}
      </div>

      <div className="absolute inset-x-0 bottom-0 flex flex-col items-center gap-3 p-6">
        {submitError && <p className="text-sm font-medium text-red-400">{submitError}</p>}

        {!previewUrl ? (
          <button
            onClick={handleCapture}
            aria-label="Scatta foto"
            className="animate-pulse-ring h-20 w-20 rounded-full border-4 border-white bg-white/30 transition active:scale-90"
          />
        ) : (
          <div className="flex gap-4">
            {attempts < MAX_ATTEMPTS && (
              <button
                onClick={handleRetake}
                disabled={submitting}
                className="rounded-full bg-white/20 px-5 py-3 font-semibold text-white backdrop-blur-sm transition active:scale-95 disabled:opacity-50"
              >
                Riscatta ({MAX_ATTEMPTS - attempts} rimasti)
              </button>
            )}
            <button
              onClick={handleConfirm}
              disabled={submitting}
              className="rounded-full bg-pop-purple px-6 py-3 font-semibold text-white shadow-lg shadow-pop-purple/40 transition active:scale-95 disabled:opacity-50"
            >
              {submitting ? 'Caricamento...' : '✅ Usa questa foto'}
            </button>
          </div>
        )}
      </div>
    </div>
  )
}
