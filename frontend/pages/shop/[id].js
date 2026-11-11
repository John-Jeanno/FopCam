import { useEffect, useState } from 'react'
import { useRouter } from 'next/router'
import Link from 'next/link'
import {
  ArrowLeftIcon,
  ChatBubbleBottomCenterIcon,
  ShoppingBagIcon,
  ShareIcon,
} from '@heroicons/react/24/outline'
import ProductImageGallery from '../../components/ProductImageGallery'

export default function ShopDetailPage({ initialShop, initialProducts, initialProducer }) {
  const router = useRouter()
  const { id } = router.query
  const [shop, setShop] = useState(initialShop)
  const [products, setProducts] = useState(initialProducts)
  const [user, setUser] = useState(null)
  const [loading, setLoading] = useState(false)
  const [showShareOptions, setShowShareOptions] = useState(false)
  const [showProfileModal, setShowProfileModal] = useState(false)
  const apiUrl = process.env.NEXT_PUBLIC_API_URL || 'http://127.0.0.1:8000'
  const ownerName = shop?.owner ? [shop.owner.first_name, shop.owner.last_name].filter(Boolean).join(' ') || shop.owner.username : ''
  const ownerInitials = ownerName
    .split(' ')
    .map((item) => item[0])
    .join('')
    .slice(0, 2)
    .toUpperCase()

  const buildMediaUrl = (path) => {
    if (!path) return null
    if (path.startsWith('http')) return path
    return `${apiUrl}${path.startsWith('/') ? path : `/${path}`}`
  }

  useEffect(() => {
    if (!id) return

    // Tokens are now in httpOnly cookies, automatically included in requests
    const fetchUser = async () => {
      try {
        const res = await fetch(`${apiUrl}/api/auth/profile/`, {
          credentials: 'include',
          headers: {
            'Authorization': `Bearer ${localStorage.getItem('access_token') || ''}`
          }
        })
        if (res.ok) {
          const data = await res.json()
          setUser(data)
        }
      } catch (error) {
        console.warn('Impossible de charger le profil connecté', error)
      }
    }

    fetchUser()
  }, [id])

  useEffect(() => {
    const removeNextFouc = () => {
      const foucStyle = document.querySelector('style[data-next-hide-fouc]')
      if (foucStyle) foucStyle.remove()
      document.body.style.display = 'block'
    }

    if (typeof window !== 'undefined') {
      removeNextFouc()
    }
  }, [])

  const handleChat = () => {
    if (!shop?.owner?.username) return
    const room = `user_${shop.owner.username}`
    const nextUrl = `/chat/${room}`
    if (!user) {
      router.push(`/login?next=${encodeURIComponent(nextUrl)}`)
      return
    }
    router.push(nextUrl)
  }

  const handleShareWhatsApp = () => {
    setShowShareOptions((visible) => !visible)
  }

  const handleShareWhatsAppContact = () => {
    if (!shop) return

    const shopUrl = `${window.location.origin}/shop/${id}`
    const message = `Découvrez la boutique "${shop.name}" sur FopCam ! 🍎\n\n${shop.description ? shop.description.substring(0, 100) + '...' : 'Des produits frais et locaux vous attendent.'}\n\n${shopUrl}`
    const whatsappUrl = `https://wa.me/?text=${encodeURIComponent(message)}`
    window.open(whatsappUrl, '_blank')
    setShowShareOptions(false)
  }

  const handleShareWhatsAppStatus = () => {
    if (!shop) return

    const shopUrl = `${window.location.origin}/shop/${id}`
    const message = `Découvrez la boutique "${shop.name}" sur FopCam ! 🍎\n\n${shop.description ? shop.description.substring(0, 100) + '...' : 'Des produits frais et locaux vous attendent.'}\n\n${shopUrl}`
    const whatsappStatusUrl = `whatsapp://send?text=${encodeURIComponent(message)}`
    window.open(whatsappStatusUrl, '_blank')
    setShowShareOptions(false)
  }

  const handleOrderProduct = (productId) => {
    if (!user) {
      router.push(`/login?next=${encodeURIComponent(`/shop/${id}`)}`)
      return
    }
    // Rediriger vers une page de checkout du produit
    router.push(`/checkout?product=${productId}&shop=${id}`)
  }

  if (loading) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-future-50 via-white to-fopcam-50 flex items-center justify-center">
        <p className="text-future-700">Chargement de la boutique…</p>
      </div>
    )
  }

  if (!shop) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-future-50 via-white to-fopcam-50 flex items-center justify-center px-4 py-10">
        <div className="max-w-3xl w-full rounded-3xl bg-white p-10 shadow-xl border border-future-200 text-center">
          <p className="text-future-700 text-xl font-semibold mb-4">Boutique introuvable.</p>
          <Link href="/chat" className="inline-flex items-center gap-2 rounded-2xl bg-fopcam-600 px-5 py-3 text-white font-semibold hover:bg-fopcam-700 transition">
            <ArrowLeftIcon className="w-5 h-5" /> Retour à la liste des vendeurs
          </Link>
        </div>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-future-50 via-white to-fopcam-50 px-4 py-10">
      <div className="mx-auto max-w-6xl">
        <div className="mb-8 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
          <Link href="/chat" className="inline-flex items-center gap-2 text-future-700 hover:text-fopcam-700">
            <ArrowLeftIcon className="w-5 h-5" /> Retour à la liste des vendeurs
          </Link>
          <div className="relative flex flex-wrap items-center gap-2 sm:gap-3">
            <div className="relative">
              <button
                type="button"
                onClick={handleShareWhatsApp}
                className="inline-flex items-center gap-2 rounded-2xl bg-green-600 px-3 py-2.5 text-sm font-semibold text-white transition hover:bg-green-700 sm:px-5 sm:py-3 sm:text-base"
                title="Partager sur WhatsApp"
              >
                <ShareIcon className="w-5 h-5" /> Partager
              </button>
              {showShareOptions && (
                <div className="absolute right-0 top-full mt-2 w-72 rounded-3xl border border-future-200 bg-white p-3 shadow-xl z-20">
                  <p className="text-sm font-semibold text-future-600 mb-2">Partager via WhatsApp</p>
                  <button
                    type="button"
                    onClick={handleShareWhatsAppContact}
                    className="w-full rounded-2xl border border-future-200 bg-future-50 px-4 py-3 text-left text-future-700 hover:bg-future-100 transition mb-2"
                  >
                    Avec un contact
                  </button>
                  <button
                    type="button"
                    onClick={handleShareWhatsAppStatus}
                    className="w-full rounded-2xl border border-future-200 bg-future-50 px-4 py-3 text-left text-future-700 hover:bg-future-100 transition"
                  >
                    Sur mon statut WhatsApp
                  </button>
                </div>
              )}
            </div>
            <button
              type="button"
              onClick={handleChat}
              className="inline-flex items-center gap-2 rounded-2xl bg-fopcam-600 px-3 py-2.5 text-sm font-semibold text-white transition hover:bg-fopcam-700 sm:px-5 sm:py-3 sm:text-base"
            >
              <ChatBubbleBottomCenterIcon className="w-5 h-5" /> Discuter avec le vendeur
            </button>
          </div>
        </div>

        {!user && (
          <div className="mb-6 rounded-3xl border border-yellow-200 bg-yellow-50 p-5 text-yellow-900">
            <p className="font-semibold">Vous pouvez consulter la boutique et voir tous les produits.</p>
            <p className="mt-1 text-sm text-yellow-800">Pour commander, connectez-vous d'abord.</p>
            <Link
              href={`/login?next=/shop/${id}`}
              className="mt-4 inline-flex items-center rounded-full bg-yellow-600 px-4 py-2 text-white font-semibold hover:bg-yellow-700 transition"
            >
              Se connecter pour commander
            </Link>
          </div>
        )}

        <section className="mb-12 rounded-3xl border border-white/80 bg-white/95 p-4 shadow-xl sm:p-8">
          <div className="grid gap-6 lg:grid-cols-[minmax(0,1fr)_320px]">
            <div className="flex flex-col gap-4">
              <div className="flex items-start justify-between gap-4">
                <div>
                  <h1 className="break-words text-3xl font-bold text-future-900 sm:text-4xl">{shop.name}</h1>
                  <p className="text-future-500 mt-2">Boutique de {shop.owner?.first_name || shop.owner?.username}</p>
                </div>
                <div className="rounded-3xl bg-fopcam-600 px-4 py-3 text-white text-sm font-semibold">{shop.active ? 'Active' : 'En pause'}</div>
              </div>
              <p className="text-future-600 leading-7">{shop.description || 'Aucune description fournie pour cette boutique.'}</p>
              <div className="grid gap-3 sm:grid-cols-2 md:grid-cols-4 mt-6">
                {shop.location && <div className="rounded-3xl bg-future-50 p-5 border border-future-200"><p className="text-sm text-future-400">Localisation</p><p className="mt-2 text-future-800">{shop.location}</p></div>}
                {shop.phone && <div className="rounded-3xl bg-future-50 p-5 border border-future-200"><p className="text-sm text-future-400">Téléphone</p><p className="mt-2 text-future-800">{shop.phone}</p></div>}
                {shop.email && <div className="rounded-3xl bg-future-50 p-5 border border-future-200"><p className="text-sm text-future-400">Email</p><p className="mt-2 text-future-800">{shop.email}</p></div>}
                {shop.website && <div className="rounded-3xl bg-future-50 p-5 border border-future-200"><p className="text-sm text-future-400">Site web</p><p className="mt-2 text-future-800"><a href={shop.website} target="_blank" rel="noreferrer" className="underline hover:text-fopcam-700">Visiter</a></p></div>}
              </div>
            </div>
            <aside className="rounded-3xl bg-fopcam-50 p-6 border border-future-200 shadow-sm">
              <div className="flex items-center gap-4">
                {initialProducer?.profile_image ? (
                  <button
                    type="button"
                    onClick={() => setShowProfileModal(true)}
                    className="block rounded-3xl overflow-hidden border-2 border-white shadow-sm transition-transform hover:-translate-y-0.5"
                    title="Voir la photo du vendeur"
                  >
                    <img
                      src={buildMediaUrl(initialProducer.profile_image)}
                      alt={`Photo de ${ownerName}`}
                      className="h-20 w-20 rounded-3xl object-cover"
                    />
                  </button>
                ) : (
                  <div className="flex h-20 w-20 items-center justify-center rounded-3xl bg-fopcam-600 text-3xl font-bold text-white">
                    {ownerInitials || 'P'}
                  </div>
                )}
                <div>
                  <p className="text-sm uppercase tracking-[0.3em] text-fopcam-600 font-semibold">Vendeur</p>
                  <h2 className="text-2xl font-bold text-future-900 mt-2">{ownerName || shop.owner?.username}</h2>
                  <p className="text-sm text-future-500">@{shop.owner?.username}</p>
                </div>
              </div>
              <div className="mt-6 space-y-4 text-future-600">
                <div>
                  <p className="text-sm text-future-400">Nom</p>
                  <p className="mt-1 text-future-900">{ownerName || 'Non renseigné'}</p>
                </div>
                <div>
                  <p className="text-sm text-future-400">Email</p>
                  <p className="mt-1 text-future-900">{shop.owner?.email || 'Non renseigné'}</p>
                </div>
                <div>
                  <p className="text-sm text-future-400">Boutique</p>
                  <p className="mt-1 text-future-900">{shop.name}</p>
                </div>
              </div>
            </aside>
          </div>
        </section>

        <section className="mb-12">
          <div className="mb-6 flex items-center gap-3 sm:mb-8">
            <ShoppingBagIcon className="h-7 w-7 shrink-0 text-fopcam-600 sm:h-8 sm:w-8" />
            <h2 className="text-2xl font-bold text-future-900 sm:text-3xl">Produits en vente</h2>
          </div>
          {products.length === 0 ? (
            <div className="rounded-3xl bg-white/95 p-12 shadow-xl border border-future-200 text-center">
              <p className="text-future-500 text-lg">Aucun produit disponible pour le moment.</p>
            </div>
          ) : (
            <div className="grid grid-cols-2 gap-4 sm:gap-6">
              {products.map((product) => (
                <div
                  key={product.id}
                  className="rounded-3xl bg-white/95 shadow-lg border border-future-200 overflow-hidden hover:shadow-xl transition"
                >
                  <ProductImageGallery product={product} resolveMediaUrl={buildMediaUrl} />
                  <div className="flex flex-col gap-3 p-4 sm:p-5">
                    <div>
                      <p className="font-semibold text-future-900 line-clamp-2">{product.title}</p>
                      <p className="text-xs text-future-500 mt-1">{product.category?.name || 'Sans catégorie'}</p>
                    </div>
                    <div className="flex items-center justify-between gap-2 mt-2">
                      <p className="break-words text-lg font-bold text-fopcam-600 sm:text-xl">{product.price} FCFA</p>
                    </div>
                    <button
                      type="button"
                      onClick={() => handleOrderProduct(product.id)}
                      className="mt-2 w-full rounded-2xl bg-fopcam-600 px-4 py-3 text-white font-semibold hover:bg-fopcam-700 transition text-sm"
                    >
                      Commander
                    </button>
                  </div>
                </div>
              ))}
            </div>
          )}
        </section>
      </div>
      {showProfileModal && initialProducer?.profile_image && (
        <div
          className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 px-4 py-6"
          role="dialog"
          aria-modal="true"
          aria-label="Photo du vendeur"
          onClick={() => setShowProfileModal(false)}
        >
          <div
            className="relative max-w-3xl w-full rounded-3xl overflow-hidden bg-white shadow-2xl"
            onClick={(event) => event.stopPropagation()}
          >
            <button
              type="button"
              onClick={() => setShowProfileModal(false)}
              className="absolute right-4 top-4 rounded-full bg-white/90 p-2 text-future-900 shadow-md hover:bg-white"
              aria-label="Fermer"
            >
              ✕
            </button>
            <img
              src={buildMediaUrl(initialProducer.profile_image)}
              alt={`Photo agrandie de ${ownerName}`}
              className="h-[80vh] w-full object-contain bg-black"
            />
          </div>
        </div>
      )}
    </div>
  )
}

export async function getServerSideProps({ params }) {
  const id = params?.id
  const apiUrl = process.env.NEXT_PUBLIC_API_URL || 'http://127.0.0.1:8000'

  try {
    const [shopRes, productsRes, producersRes] = await Promise.all([
      fetch(`${apiUrl}/api/shops/${id}/`),
      fetch(`${apiUrl}/api/products/?shop=${id}`),
      fetch(`${apiUrl}/api/profiles/?role=producer&page_size=100`),
    ])

    if (!shopRes.ok) {
      return { notFound: true }
    }

    const initialShop = await shopRes.json()
    const productsData = productsRes.ok ? await productsRes.json() : []
    const initialProducts = Array.isArray(productsData) ? productsData : productsData.results || []
    const producersData = producersRes.ok ? await producersRes.json() : []
    const producersList = Array.isArray(producersData)
      ? producersData
      : producersData?.results || []
    const initialProducer = producersList.find(
      (p) =>
        (p.user?.id && p.user.id === initialShop.owner?.id) ||
        (p.user?.username && p.user.username === initialShop.owner?.username)
    ) || null

    return {
      props: {
        initialShop,
        initialProducts,
        initialProducer,
      },
    }
  } catch (error) {
    console.error('Erreur getServerSideProps shop detail:', error)
    return { notFound: true }
  }
}
