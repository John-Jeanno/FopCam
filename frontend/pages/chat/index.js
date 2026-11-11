import { useEffect, useState } from 'react'
import Link from 'next/link'
import { useRouter } from 'next/router'
import {
  ArrowLeftIcon,
  ChatBubbleBottomCenterIcon,
  ShoppingBagIcon,
  UserIcon,
  MapPinIcon,
} from '@heroicons/react/24/outline'

export default function ChatDirectory() {
  const [profiles, setProfiles] = useState([])
  const [user, setUser] = useState(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const router = useRouter()
  const apiUrl = process.env.NEXT_PUBLIC_API_URL || 'http://127.0.0.1:8000'

  const buildMediaUrl = (path) => {
    if (!path) return ''
    if (path.startsWith('http')) return path
    if (path.startsWith('/')) return `${apiUrl}${path}`
    return `${apiUrl}/media/${path}`
  }

  useEffect(() => {
    const token = localStorage.getItem('access')

    const loadProfiles = async () => {
      try {
        const res = await fetch(`${apiUrl}/api/profiles/`)
        const data = await res.json()
        setProfiles(Array.isArray(data) ? data : data.results || [])
      } catch (err) {
        setError('Impossible de charger les profils pour le moment.')
      }
    }

    const loadUserProfile = async () => {
      if (!token) return
      try {
        const res = await fetch(`${apiUrl}/api/auth/profile/`, {
          headers: { Authorization: `Bearer ${token}` },
        })
        if (res.ok) {
          const profile = await res.json()
          setUser(profile)
        }
      } catch (err) {
        console.warn('Unable to load authenticated profile', err)
      }
    }

    Promise.all([loadProfiles(), loadUserProfile()]).finally(() => setLoading(false))
  }, [])

  const handleChat = (profile) => {
    // Redirect to unified messages page
    router.push('/messages')
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-future-50 via-white to-fopcam-50 px-4 py-10">
      <div className="max-w-6xl mx-auto">
        <div className="flex items-center justify-between mb-8">
          <Link href="/" className="inline-flex items-center gap-2 text-future-700 hover:text-fopcam-700">
            <ArrowLeftIcon className="w-5 h-5" /> Retour à l'accueil
          </Link>
          <div className="rounded-3xl bg-white/90 px-5 py-4 shadow-lg border border-white/70">
            <p className="text-sm text-future-700">{user ? `Connecté en tant que ${user.user?.first_name || user.user?.username}` : 'Connectez-vous pour démarrer une conversation'}</p>
          </div>
        </div>

        <div className="grid gap-6 lg:grid-cols-[1fr_320px]">
          <div className="space-y-6">
            <div className="rounded-3xl bg-white/95 p-8 shadow-xl border border-white/80">
              <div className="flex items-start gap-4 mb-6">
                <div className="rounded-3xl bg-fopcam-600 p-4 text-white">
                  <ChatBubbleBottomCenterIcon className="w-8 h-8" />
                </div>
                <div>
                  <h1 className="text-3xl font-bold text-future-900">Messagerie</h1>
                  <p className="mt-2 text-future-600">Découvrez tous les vendeurs et visiteurs inscrits. Démarrez une conversation pour discuter directement avec eux.</p>
                </div>
              </div>
              <div className="grid gap-4">
                <button
                  type="button"
                  onClick={() => router.push('/products')}
                  className="w-full inline-flex items-center justify-center gap-2 rounded-2xl bg-fopcam-600 px-5 py-4 text-white font-semibold shadow-lg hover:bg-fopcam-700 transition"
                >
                  <ShoppingBagIcon className="w-5 h-5" /> Explorer les produits
                </button>
                {!user && (
                  <div className="rounded-3xl bg-future-100 p-4 text-future-700 border border-future-200">
                    <p>Vous n'êtes pas connecté. Pour discuter avec un vendeur, connectez-vous ou créez un compte.</p>
                    <div className="mt-4 flex flex-col gap-3 sm:flex-row">
                      <Link href="/login?next=/chat" className="btn-primary w-full text-center">Se connecter</Link>
                      <Link href="/register?next=/chat" className="btn-secondary w-full text-center">S'inscrire</Link>
                    </div>
                  </div>
                )}
              </div>
            </div>

            <div className="rounded-3xl bg-white/95 p-8 shadow-xl border border-white/80">
              <h2 className="text-2xl font-bold text-future-900 mb-4">Vendeurs / Visiteurs disponibles</h2>
              {loading ? (
                <p className="text-future-500">Chargement des profils…</p>
              ) : error ? (
                <p className="text-red-500">{error}</p>
              ) : profiles.length === 0 ? (
                <p className="text-future-500">Aucun vendeur trouvé pour le moment.</p>
              ) : (
                <div className="grid gap-4">
                  {profiles.map((profile) => (
                    <div key={profile.user?.username} className="rounded-3xl border border-future-200 bg-future-50 p-5">
                      <div className="flex items-center gap-4 mb-4">
                        <div className="h-16 w-16 rounded-3xl overflow-hidden bg-white/90 shadow-sm flex items-center justify-center">
                          {profile.profile_image ? (
                            <img
                              src={buildMediaUrl(profile.profile_image)}
                              alt={profile.user?.username}
                              className="h-full w-full object-cover"
                            />
                          ) : (
                            <UserIcon className="w-8 h-8 text-future-400" />
                          )}
                        </div>
                        <div>
                          <p className="text-lg font-semibold text-future-900">{profile.user?.first_name || profile.user?.username}</p>
                          <p className="text-sm text-future-500">{profile.role === 'producer' || !!profile.shop_id ? 'Vendeur' : 'Visiteur'}</p>
                        </div>
                      </div>
                      <div className="space-y-2 text-future-600 mb-4">
                        {profile.shop_name ? (
                          <p>{profile.shop_name}</p>
                        ) : (
                          <p>{profile.role === 'producer' || !!profile.shop_id ? 'Boutique non configurée' : 'Aucun magasin associé'}</p>
                        )}
                        {(profile.city || profile.country) && (
                          <p className="flex items-center gap-2 text-sm text-future-500">
                            <MapPinIcon className="w-4 h-4" /> {profile.city || profile.country ? `${profile.city || ''}${profile.city && profile.country ? ', ' : ''}${profile.country || ''}` : 'Localisation indisponible'}
                          </p>
                        )}
                      </div>
                      <div className="flex flex-col gap-3 sm:flex-row">
                        {profile.shop_id ? (
                          <Link
                            href={`/shop/${profile.shop_id}`}
                            className="inline-flex items-center justify-center rounded-2xl border border-fopcam-200 px-4 py-3 text-sm font-semibold text-fopcam-700 hover:bg-fopcam-50 transition"
                          >
                            Voir la boutique
                          </Link>
                        ) : (
                          <div className="inline-flex items-center justify-center rounded-2xl border border-future-200 px-4 py-3 text-sm font-semibold text-future-500 bg-future-100">
                            {profile.role === 'producer' || !!profile.shop_id ? 'Boutique indisponible' : 'Profil Visiteur'}
                          </div>
                        )}
                        <button
                          type="button"
                          onClick={() => handleChat(profile)}
                          className="inline-flex items-center justify-center rounded-2xl bg-fopcam-600 px-4 py-3 text-sm font-semibold text-white hover:bg-fopcam-700 transition"
                        >
                          Envoyer un message
                        </button>
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>
          </div>

          <aside className="rounded-3xl bg-fopcam-950/90 p-8 text-white shadow-xl border border-white/10">
            <h2 className="text-2xl font-bold mb-4">Comment démarrer</h2>
            <ol className="space-y-4 text-future-200">
              <li className="rounded-2xl bg-white/5 p-4">
                <p className="text-sm font-semibold">1. Choisissez un vendeur</p>
                <p className="text-sm">Parcourez la liste et consultez les boutiques locales.</p>
              </li>
              <li className="rounded-2xl bg-white/5 p-4">
                <p className="text-sm font-semibold">2. Visitez sa boutique</p>
                <p className="text-sm">Affichez les produits et les informations du vendeur.</p>
              </li>
              <li className="rounded-2xl bg-white/5 p-4">
                <p className="text-sm font-semibold">3. Lancez la discussion</p>
                <p className="text-sm">Parlez directement au vendeur depuis la messagerie.</p>
              </li>
            </ol>
          </aside>
        </div>
      </div>
    </div>
  )
}
