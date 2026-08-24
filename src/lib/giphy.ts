const GIPHY_API_KEY = import.meta.env.VITE_GIPHY_API_KEY as string
const BASE_URL = 'https://api.giphy.com/v1/gifs'

export interface GifResult {
  id: string
  url: string
  previewUrl: string
}

interface GiphyApiImage {
  url: string
}

interface GiphyApiGif {
  id: string
  images: {
    fixed_height: GiphyApiImage
    fixed_height_small: GiphyApiImage
  }
}

function assertApiKey() {
  if (!GIPHY_API_KEY) {
    throw new Error(
      'Manca VITE_GIPHY_API_KEY. Crea una app gratuita su developers.giphy.com e incolla la key in .env.local.',
    )
  }
}

function mapResults(data: GiphyApiGif[]): GifResult[] {
  return data.map((gif) => ({
    id: gif.id,
    url: gif.images.fixed_height.url,
    previewUrl: gif.images.fixed_height_small.url,
  }))
}

export async function searchGifs(query: string): Promise<GifResult[]> {
  assertApiKey()
  const params = new URLSearchParams({
    api_key: GIPHY_API_KEY,
    q: query,
    limit: '24',
    rating: 'pg-13',
    lang: 'it',
  })
  const res = await fetch(`${BASE_URL}/search?${params}`)
  if (!res.ok) throw new Error('Ricerca GIF non riuscita, riprova')
  const { data } = (await res.json()) as { data: GiphyApiGif[] }
  return mapResults(data)
}

export async function trendingGifs(): Promise<GifResult[]> {
  assertApiKey()
  const params = new URLSearchParams({ api_key: GIPHY_API_KEY, limit: '24', rating: 'pg-13' })
  const res = await fetch(`${BASE_URL}/trending?${params}`)
  if (!res.ok) throw new Error('Caricamento GIF di tendenza non riuscito')
  const { data } = (await res.json()) as { data: GiphyApiGif[] }
  return mapResults(data)
}
