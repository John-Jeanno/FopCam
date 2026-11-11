import { useEffect, useState, useMemo } from 'react'
import { useRouter } from 'next/router'
import { serverSideTranslations } from 'next-i18next/serverSideTranslations'
import { ArrowLeftIcon, PlayIcon, HeartIcon, EyeIcon } from '@heroicons/react/24/outline'
import { fetchWithAuth } from '../../utils/tokenManager'

const apiUrl = process.env.NEXT_PUBLIC_API_URL || 'http://127.0.0.1:8000'
const themes = ['Tous', 'Produits', 'Recettes', 'Vie locale', 'Tendances']

const ReelsPage = () => {
  const router = useRouter()
  const [reels, setReels] = useState([])
  const [selectedTheme, setSelectedTheme] = useState('Tous')
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [activeReel, setActiveReel] = useState(null)

  const buildMediaUrl = (path) => {
    if (!path) return '/default-avatar.png'
    if (path.startsWith('http')) return path
    return `${apiUrl}${path.startsWith('/') ? '' : '/'}${path}`
  }

  useEffect(() => {
    const fetchReels = async () => {
      setLoading(true)
      setError(null)

      try {
        const response = await fetch(`${apiUrl}/api/reels/`)
        if (!response.ok) {
          throw new Error(`Statut ${response.status}`)
        }

        const json = await response.json()
        const reelsData = Array.isArray(json) ? json : json.results || []
        setReels(reelsData)
      } catch (err) {
        console.error('Erreur chargement clips :', err)
        setError('Impossible de charger les clips pour le moment.')
      } finally {
        setLoading(false)
      }
    }

    fetchReels()
  }, [])

  const filteredReels = useMemo(() => {
    if (selectedTheme === 'Tous') return reels
    return reels.filter((reel) => reel.theme === selectedTheme)
  }, [reels, selectedTheme])

  const handleViewReel = async (reel) => {
    setActiveReel(reel)
    try {
      const response = await fetchWithAuth(`${apiUrl}/api/reels/${reel.id}/view/`, {
        method: 'POST'
      })
      if (response.ok) {
        setReels((current) => current.map((item) =>
          item.id === reel.id
            ? { ...item, views_count: (item.views_count || 0) + 1, is_viewed: true }
            : item
        ))
      }
    } catch (err) {
      console.error('Erreur marquage clip vu :', err)
    }
  }

  const handleLikeReel = async (reelId) => {
    try {
      const response = await fetchWithAuth(`${apiUrl}/api/reels/${reelId}/like/`, {
        method: 'POST'
      })
      if (response.ok) {
        setReels((current) => current.map((item) => {
          if (item.id !== reelId) return item
          const liked = !item.is_liked
          const delta = liked ? 1 : -1
          return {
            ...item,
            is_liked: liked,
            likes_count: Math.max(0, (item.likes_count || 0) + delta)
          }
        }))
      }
    } catch (err) {
      console.error('Erreur like clip :', err)
    }
  }

  return (
    <div className="min-h-screen bg-future-50 text-future-900">
      <header className="border-b border-future-800 bg-future-950/95 backdrop-blur sticky top-0 z-50">
        <div className="mx-auto flex max-w-7xl items-center justify-between px-4 py-4 sm:px-6">
          <div className="flex items-center gap-3">
            <button
              type="button"
              onClick={() => router.push('/')}
              className="inline-flex items-center gap-2 rounded-full border border-future-700 bg-white/5 px-4 py-2 text-sm font-medium text-future-200 hover:bg-future-100/10 transition-colors"
            >
              <ArrowLeftIcon className="w-4 h-4" />
              Retour
            </button>
            <div>
              <p className="text-sm uppercase tracking-[0.3em] text-fopcam-700">Clips</p>
              <h1 className="text-xl font-bold text-future-100">Découvrez les reels</h1>
            </div>
          </div>
          <button
            type="button"
            onClick={() => alert('Création de clips bientôt disponible sur le web.')}
            className="rounded-full bg-fopcam-800 px-5 py-3 text-sm font-semibold text-white hover:bg-fopcam-900 transition"
          >
            Créer un clip
          </button>
        </div>
      </header>

      <main className="mx-auto max-w-7xl px-4 py-10 sm:px-6">
        <div className="mb-6 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
          <div className="flex flex-wrap items-center gap-2">
            {themes.map((theme) => (
              <button
                key={theme}
                type="button"
                onClick={() => setSelectedTheme(theme)}
                className={`rounded-full px-4 py-2 text-sm font-medium transition ${selectedTheme === theme ? 'bg-fopcam-800 text-white' : 'bg-white/90 text-future-800 hover:bg-future-100'}`}
              >
                {theme}
              </button>
            ))}
          </div>
          <div className="text-sm text-future-600">
            {filteredReels.length} clip{filteredReels.length > 1 ? 's' : ''}
          </div>
        </div>

        {loading && (
          <div className="rounded-3xl border border-dashed border-future-300 bg-white/80 p-10 text-center text-future-600">
            Chargement des clips...
          </div>
        )}

        {error && (
          <div className="rounded-3xl border border-red-200 bg-red-50 p-8 text-red-700">
            {error}
          </div>
        )}

        {!loading && !error && filteredReels.length === 0 && (
          <div className="rounded-3xl border border-future-200 bg-white p-10 text-center text-future-600">
            Aucun clip trouvé pour cette catégorie.
          </div>
        )}

        <div className="grid gap-6 xl:grid-cols-3 lg:grid-cols-2">
          {filteredReels.map((reel) => (
            <article key={reel.id} className="overflow-hidden rounded-3xl border border-future-200 bg-white shadow-sm">
              <button
                type="button"
                onClick={() => handleViewReel(reel)}
                className="group relative block h-56 w-full overflow-hidden bg-slate-950"
              >
                <img
                  src={buildMediaUrl(reel.thumbnail || reel.video)}
                  alt={reel.title || 'Clip'}
                  className="h-full w-full object-cover transition duration-200 group-hover:scale-105"
                />
                <div className="absolute inset-0 bg-gradient-to-t from-black/80 to-transparent" />
                <div className="absolute inset-x-0 bottom-0 p-4 text-left text-sm text-white">
                  <p className="font-semibold">{reel.title || 'Titre du clip'}</p>
                  <p className="mt-1 text-xs text-white/80 line-clamp-2">{reel.description || 'Aucune description fournie'}</p>
                </div>
                <div className="absolute right-4 top-4 rounded-full bg-black/60 p-3 text-white">
                  <PlayIcon className="w-5 h-5" />
                </div>
              </button>

              <div className="p-5">
                <div className="flex items-center gap-3 mb-4">
                  <img
                    src={buildMediaUrl(reel.author?.profile_image) || '/default-avatar.png'}
                    alt={reel.author?.username || 'Auteur'}
                    className="h-12 w-12 rounded-full object-cover"
                  />
                  <div>
                    <p className="font-semibold text-future-900">{reel.author?.username || 'Auteur inconnu'}</p>
                    <p className="text-sm text-future-500">{new Date(reel.created_at).toLocaleDateString('fr-FR')}</p>
                  </div>
                </div>

                <div className="flex flex-wrap gap-3 text-sm text-future-600">
                  <span className="inline-flex items-center gap-1 rounded-full bg-future-50 px-3 py-1">
                    <EyeIcon className="h-4 w-4" />
                    {reel.views_count || 0}
                  </span>
                  <span className="inline-flex items-center gap-1 rounded-full bg-future-50 px-3 py-1">
                    <HeartIcon className="h-4 w-4" />
                    {reel.likes_count || 0}
                  </span>
                  {reel.audio_title && (
                    <span className="inline-flex items-center gap-1 rounded-full bg-future-50 px-3 py-1">
                      {reel.audio_title}
                    </span>
                  )}
                </div>

                <div className="mt-6 flex items-center gap-3">
                  <button
                    type="button"
                    onClick={() => handleViewReel(reel)}
                    className="inline-flex items-center justify-center rounded-full border border-future-300 bg-white px-4 py-2 text-sm font-semibold text-future-900 hover:bg-future-100 transition"
                  >
                    Voir
                  </button>
                  <button
                    type="button"
                    onClick={() => handleLikeReel(reel.id)}
                    className={`inline-flex items-center justify-center rounded-full px-4 py-2 text-sm font-semibold transition ${reel.is_liked ? 'bg-rose-500 text-white hover:bg-rose-600' : 'border border-future-300 bg-white text-future-900 hover:bg-future-100'}`}
                  >
                    {reel.is_liked ? 'Retiré' : 'J’aime'}
                  </button>
                </div>
              </div>
            </article>
          ))}
        </div>
      </main>

      {activeReel && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 p-4">
          <div className="relative w-full max-w-4xl overflow-hidden rounded-3xl bg-slate-950 shadow-2xl">
            <button
              type="button"
              onClick={() => setActiveReel(null)}
              className="absolute right-4 top-4 z-10 rounded-full bg-black/60 p-3 text-white hover:bg-black/80"
            >
              ✕
            </button>
            <video
              src={buildMediaUrl(activeReel.video)}
              controls
              autoPlay
              className="h-[60vh] w-full bg-black object-contain"
            />
            <div className="space-y-4 p-6 text-white">
              <div className="flex items-center justify-between gap-4">
                <div>
                  <p className="text-lg font-semibold">{activeReel.title || 'Clip'}</p>
                  <p className="text-sm text-future-400">{activeReel.description || 'Aucune description'}</p>
                </div>
                <button
                  type="button"
                  onClick={() => handleLikeReel(activeReel.id)}
                  className={`rounded-full px-4 py-2 text-sm font-semibold transition ${activeReel.is_liked ? 'bg-rose-500 text-white hover:bg-rose-600' : 'border border-future-300 bg-white text-future-900 hover:bg-future-100'}`}
                >
                  {activeReel.is_liked ? 'Retiré' : 'J’aime'}
                </button>
              </div>
              <div className="flex flex-wrap gap-4 text-sm text-future-400">
                <span>{activeReel.views_count || 0} vues</span>
                <span>{activeReel.likes_count || 0} likes</span>
                {activeReel.audio_title && <span>{activeReel.audio_title}</span>}
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}

export async function getServerSideProps({ locale }) {
  return {
    props: {
      ...(await serverSideTranslations(locale, ['common']))
    }
  }
}

export default ReelsPage
