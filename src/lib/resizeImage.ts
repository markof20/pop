export function resizeImageToSquareJpeg(file: File, size = 480): Promise<Blob> {
  return new Promise((resolve, reject) => {
    const img = new Image()
    const url = URL.createObjectURL(file)

    img.onload = () => {
      const canvas = document.createElement('canvas')
      canvas.width = size
      canvas.height = size
      const ctx = canvas.getContext('2d')
      if (!ctx) {
        URL.revokeObjectURL(url)
        reject(new Error('Canvas non disponibile'))
        return
      }

      const scale = Math.max(size / img.width, size / img.height)
      const sw = size / scale
      const sh = size / scale
      const sx = (img.width - sw) / 2
      const sy = (img.height - sh) / 2
      ctx.drawImage(img, sx, sy, sw, sh, 0, 0, size, size)
      URL.revokeObjectURL(url)

      canvas.toBlob(
        (blob) => {
          if (!blob) {
            reject(new Error("Impossibile elaborare l'immagine"))
            return
          }
          resolve(blob)
        },
        'image/jpeg',
        0.85,
      )
    }

    img.onerror = () => {
      URL.revokeObjectURL(url)
      reject(new Error('Impossibile leggere il file'))
    }

    img.src = url
  })
}
