import { useEffect, useMemo, useState } from 'react'
import { useRouter } from 'next/router'
import Link from 'next/link'
import { motion } from 'framer-motion'
import { BuildingStorefrontIcon, PlusIcon, UserIcon, MapPinIcon, PhoneIcon, EnvelopeIcon, ArrowLeftIcon, TrashIcon, PencilIcon, ShoppingBagIcon, StarIcon } from '@heroicons/react/24/outline'
import { StarIcon as StarIconSolid } from '@heroicons/react/24/solid'
import FilterPanel from '../../components/FilterPanel'
import { fetchWithAuth, getAccessToken } from '../../utils/tokenManager'

const DEFAULT_FILTERS = {
  from: '',
  to: '',
  quick: 'all',
  status: 'all',
  category: 'all',
  product: 'all',
  search: '',
}

const buildMediaUrl = (path) => {
  if (!path) return ''
  if (path.startsWith('http')) return path
  if (path.startsWith('/')) return process.env.NEXT_PUBLIC_API_URL + path
  return process.env.NEXT_PUBLIC_API_URL + '/media/' + path
}

export default function Dashboard(){
  const [user, setUser] = useState(null)
  const [shop, setShop] = useState(null)
  const [products, setProducts] = useState([])
  const [friendRequests, setFriendRequests] = useState([])
  const [acceptedFriends, setAcceptedFriends] = useState([])
  const [reviews, setReviews] = useState([])
  const [averageRating, setAverageRating] = useState(null)
  const [loading, setLoading] = useState(true)
  const [seeding, setSeeding] = useState(false)
  const [seedMessage, setSeedMessage] = useState('')
  const [mode, setMode] = useState('all')
  const [filters, setFilters] = useState(DEFAULT_FILTERS)
  const [uploadingProfileImage, setUploadingProfileImage] = useState(false)
  const router = useRouter()
  const apiUrl = process.env.NEXT_PUBLIC_API_URL || 'http://127.0.0.1:8000'

  useEffect(() => {
    const load = async () => {
      try {
        // Charger les informations utilisateur via fetchWithAuth (gère cookies/httpOnly)
        const profileRes = await fetchWithAuth(process.env.NEXT_PUBLIC_API_URL + '/api/auth/profile/')
        if (profileRes.status === 401 || profileRes.status === 403) {
          router.replace('/login')
          return
        }
        const profile = await profileRes.json()
        setUser(profile)

        // Charger la boutique
        try {
          const shopRes = await fetchWithAuth(process.env.NEXT_PUBLIC_API_URL + '/api/shops/my/')
          if (shopRes.ok) {
            const shopData = await shopRes.json()
            if (shopData && shopData.id) setShop(shopData)
          }
        } catch (e) {
          console.log('Pas de boutique', e)
        }

        // Charger les produits du vendeur
        try {
          const productsRes = await fetchWithAuth(process.env.NEXT_PUBLIC_API_URL + '/api/products/my/')
          if (productsRes.ok) {
            const data = await productsRes.json()
            if (data.results) setProducts(data.results)
            else if (Array.isArray(data)) setProducts(data)
          }
        } catch (e) {
          console.log('Erreur chargement produits', e)
        }
      } catch (err) {
        console.log('Erreur chargement profil/shop/products', err)
      } finally {
        setLoading(false)
      }
    }

    load()
  }, [])

  useEffect(() => {
    if (user) {
      loadFriendRequests()
      loadReviews()
    }
  }, [user])

  const filteredProducts = useMemo(() => {
    const search = filters.search.trim().toLowerCase()
    return products.filter(product => {
      const matchesSearch = search
        ? [product.title, product.description, product.category?.name]
            .filter(Boolean)
            .some(value => value.toLowerCase().includes(search))
        : true

      const matchesStatus =
        filters.status === 'all'
          ? true
          : filters.status === 'low'
          ? product.quantity <= 5
          : filters.status === 'available'
          ? product.quantity > 5
          : true

      const matchesCategory =
        filters.category === 'all'
          ? true
          : product.category?.name === filters.category

      const matchesProduct =
        filters.product === 'all'
          ? true
          : product.title === filters.product

      return matchesSearch && matchesStatus && matchesCategory && matchesProduct
    })
  }, [products, filters])

  const handleFilterChange = (field, value) => {
    setFilters(prev => ({ ...prev, [field]: value }))
  }

  const handleClearFilters = () => {
    setFilters(DEFAULT_FILTERS)
    setMode('all')
  }

  const handleProfileImageUpload = async (event) => {
    const file = event.target.files[0]
    if (!file) return

    // Tokens are now in httpOnly cookies, automatically included in requests
    setUploadingProfileImage(true)

    const formData = new FormData()
    formData.append('profile_image', file)

    try {
      const response = await fetch(process.env.NEXT_PUBLIC_API_URL + '/api/auth/profile/', {
        method: 'PATCH',
        body: formData,
      })

      if (response.ok) {
        const updatedProfile = await response.json()
        setUser(prev => ({ ...prev, profile_image: updatedProfile.profile_image }))
        alert('Photo de profil mise à jour avec succès!')
      } else {
        alert('Erreur lors de la mise à jour de la photo de profil.')
      }
    } catch (error) {
      console.error('Erreur upload:', error)
      alert('Erreur lors de l\'upload de l\'image.')
    } finally {
      setUploadingProfileImage(false)
    }
  }

  const loadFriendRequests = async () => {
    const token = getAccessToken()
    if (!token) return

    try {
      const response = await fetch(apiUrl + '/api/friends/', {
        headers: { 'Authorization': 'Bearer ' + token }
      })
      if (!response.ok) return

      const data = await response.json()
      const results = Array.isArray(data) ? data : data.results || []
      const currentUserId = user?.user?.id || user?.id
      
      // Séparer les demandes en attente et les clients acceptés
      const pending = results.filter(request => request.receiver?.id === currentUserId && request.status === 'pending')
      const accepted = results.filter(request => (request.receiver?.id === currentUserId || request.requester?.id === currentUserId) && request.status === 'accepted')
      
      setFriendRequests(pending)
      setAcceptedFriends(accepted)
    } catch (error) {
      console.error('Erreur chargement demandes client', error)
    }
  }

  const loadReviews = async () => {
    const token = getAccessToken()
    if (!token || !user) return

    const producerId = user?.user?.id || user?.id
    try {
      const response = await fetch(apiUrl + `/api/producer-reviews/?producer_id=${producerId}`, {
        headers: { 'Authorization': 'Bearer ' + token }
      })
      if (!response.ok) return
      const data = await response.json()
      const reviewsList = Array.isArray(data) ? data : data.results || []
      setReviews(reviewsList)

      if (reviewsList.length > 0) {
        const average = reviewsList.reduce((sum, review) => sum + (review.rating || 0), 0) / reviewsList.length
        setAverageRating(Math.round(average * 10) / 10)
      } else {
        setAverageRating(null)
      }
    } catch (error) {
      console.error('Erreur chargement des notations', error)
    }
  }

  const renderStars = (rating) => {
    const count = rating ? Math.round(rating / 2) : 0
    return (
      <div className="flex items-center gap-1">
        {Array.from({ length: 5 }, (_, index) => (
          <StarIconSolid
            key={index}
            className={`w-4 h-4 ${index < count ? 'text-fopcam-400' : 'text-future-500'}`}
          />
        ))}
      </div>
    )
  }

  const handleFriendRequestAction = async (requestId, action) => {
    const token = getAccessToken()
    if (!token) return

    try {
      const response = await fetch(apiUrl + `/api/friends/${requestId}/${action}/`, {
        method: 'POST',
        headers: { 'Authorization': 'Bearer ' + token }
      })
      if (response.ok) {
        await loadFriendRequests()
      } else {
        const errorData = await response.json().catch(() => null)
        console.error(`Erreur ${action} demande client`, errorData)
      }
    } catch (error) {
      console.error(`Erreur ${action} demande client`, error)
    }
  }

  const handleRemoveClient = async (friendshipId) => {
    if (!confirm('Êtes-vous sûr de vouloir retirer ce client ?')) return

    const token = getAccessToken()
    if (!token) return

    try {
      const response = await fetch(apiUrl + `/api/friends/${friendshipId}/`, {
        method: 'DELETE',
        headers: { 'Authorization': 'Bearer ' + token }
      })
      if (response.ok) {
        await loadFriendRequests()
      } else {
        const errorData = await response.json().catch(() => null)
        console.error('Erreur suppression client', errorData)
        alert('Erreur lors de la suppression du client')
      }
    } catch (error) {
      console.error('Erreur suppression client', error)
      alert('Erreur lors de la suppression du client')
    }
  }

  const handleSeedProducts = async () => {
    if (!shop) return
    const token = getAccessToken()
    if (!token) return

    setSeeding(true)
    setSeedMessage('')

    const response = await fetch(process.env.NEXT_PUBLIC_API_URL + '/api/shops/seed_products/', {
      method: 'POST',
      headers: {
        'Authorization': 'Bearer ' + token,
        'Content-Type': 'application/json',
      },
    })

    if (response.ok) {
      const data = await response.json()
      setSeedMessage(data.detail || 'Produits d’exemple ajoutés.')
      const productsResponse = await fetch(process.env.NEXT_PUBLIC_API_URL + '/api/products/my/', {
        headers: { 'Authorization': 'Bearer ' + token },
      })
      const productsData = await productsResponse.json()
      if (productsData.results) setProducts(productsData.results)
      else if (Array.isArray(productsData)) setProducts(productsData)
    } else {
      const errorData = await response.json().catch(() => null)
      setSeedMessage(errorData?.detail || 'Impossible de générer les produits.')
    }

    setSeeding(false)
  }

  const categoryOptions = Array.from(
    new Set(products.map(p => p.category?.name).filter(Boolean))
  ).map(name => ({ value: name, label: name }))

  const productOptions = Array.from(
    new Set(products.map(p => p.title).filter(Boolean))
  ).map(title => ({ value: title, label: title }))

  const statusOptions = [
    { value: 'available', label: 'Disponible' },
    { value: 'low', label: 'Faible stock' },
  ]

  const totalProducts = products.length
  const lowStockCount = products.filter(p => p.quantity > 0 && p.quantity <= 5).length
  const outOfStockCount = products.filter(p => p.quantity === 0).length
  const hasShop = Boolean(shop)

  if (loading) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-future-900 via-future-800 to-fopcam-900 flex items-center justify-center">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-fopcam-400"></div>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-future-900 via-future-800 to-fopcam-900 p-4">
      <div className="max-w-6xl mx-auto">
        {/* Header avec bouton de retour */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          className="mb-8 flex flex-col gap-6 lg:flex-row lg:items-center lg:justify-between"
        >
          <div>
            <h1 className="text-3xl font-bold text-white mb-2">Tableau de bord Vendeur</h1>
            <p className="text-future-300">Gérez votre boutique et vos produits</p>
          </div>
          <Link
            href="/"
            className="inline-flex items-center text-future-300 hover:text-fopcam-400 transition-colors border border-future-300 hover:border-fopcam-400 rounded-lg px-4 py-2"
          >
            <ArrowLeftIcon className="w-5 h-5 mr-2" />
            Accueil
          </Link>
        </motion.div>

        <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4 mb-8">
          <div className="glass-effect rounded-3xl p-6 border border-white/10 shadow-2xl">
            <p className="text-sm uppercase tracking-[0.28em] text-future-400 mb-3">Produits</p>
            <p className="text-4xl font-black text-white">{totalProducts}</p>
            <p className="text-future-300 mt-2">Articles publiés</p>
          </div>
          <div className="glass-effect rounded-3xl p-6 border border-white/10 shadow-2xl">
            <p className="text-sm uppercase tracking-[0.28em] text-future-400 mb-3">Stock faible</p>
            <p className="text-4xl font-black text-fopcam-400">{lowStockCount}</p>
            <p className="text-future-300 mt-2">Produits à surveiller</p>
          </div>
          <div className="glass-effect rounded-3xl p-6 border border-white/10 shadow-2xl">
            <p className="text-sm uppercase tracking-[0.28em] text-future-400 mb-3">Rupture</p>
            <p className="text-4xl font-black text-red-400">{outOfStockCount}</p>
            <p className="text-future-300 mt-2">Produits en rupture</p>
          </div>
          <div className="glass-effect rounded-3xl p-6 border border-white/10 shadow-2xl">
            <p className="text-sm uppercase tracking-[0.28em] text-future-400 mb-3">Boutique</p>
            <p className="text-4xl font-black text-white">{hasShop ? 'Active' : 'À créer'}</p>
            <p className="text-future-300 mt-2">{hasShop ? shop?.name : 'Créez votre boutique'}</p>
          </div>
        </div>

        <div className="grid lg:grid-cols-3 gap-8">
          {/* Profil Utilisateur */}
          <motion.div
            initial={{ opacity: 0, x: -20 }}
            animate={{ opacity: 1, x: 0 }}
            transition={{ delay: 0.1 }}
            className="lg:col-span-1"
          >
            <div className="glass-effect rounded-3xl overflow-hidden shadow-2xl border border-white/10">
              <div className="bg-gradient-to-br from-fopcam-400 via-fopcam-500 to-future-800 p-6 text-center">
                <div className="relative w-28 h-28 rounded-full mx-auto mb-4 overflow-hidden shadow-lg border-4 border-white/20 bg-future-950 flex items-center justify-center">
                  {user?.profile_image ? (
                    <img
                      src={buildMediaUrl(user.profile_image)}
                      alt="Photo de profil"
                      className="w-28 h-28 rounded-full object-cover"
                    />
                  ) : (
                    <UserIcon className="w-14 h-14 text-white" />
                  )}
                  <label
                    htmlFor="profile-image-upload"
                    className="absolute inset-0 bg-black/50 flex items-center justify-center opacity-0 hover:opacity-100 transition-opacity cursor-pointer rounded-full"
                  >
                    <PencilIcon className="w-6 h-6 text-white" />
                  </label>
                  <input
                    id="profile-image-upload"
                    type="file"
                    accept="image/*"
                    onChange={handleProfileImageUpload}
                    disabled={uploadingProfileImage}
                    className="hidden"
                  />
                </div>
                {uploadingProfileImage && (
                  <div className="text-white text-sm mb-2">Upload en cours...</div>
                )}
                <h3 className="text-2xl font-bold text-white">
                  {user?.first_name} {user?.last_name}
                </h3>
                <p className="text-fopcam-200 font-medium">{user?.email}</p>
                {user?.phone && (
                  <div className="flex items-center justify-center mt-3 text-future-300">
                    <PhoneIcon className="w-4 h-4 mr-2" />
                    {user.phone}
                  </div>
                )}
                {user?.city && (
                  <div className="flex items-center justify-center mt-2 text-future-300">
                    <MapPinIcon className="w-4 h-4 mr-2" />
                    {user.city}, {user.country}
                  </div>
                )}
              </div>

              <div className="grid gap-3 p-6 bg-future-950/80">
                <div className="rounded-3xl border border-white/10 bg-white/5 p-4 text-left">
                  <p className="text-sm text-future-300">Statut de la boutique</p>
                  <p className="text-base font-semibold text-white mt-1">{hasShop ? 'En ligne' : 'Non configurée'}</p>
                </div>
                <div className="grid gap-3">
                <Link
                  href="/producer/create-shop"
                  className="w-full btn-secondary bg-white/10 hover:bg-white/20 border-white/20 flex items-center justify-center text-white hover:text-white"
                >
                  <BuildingStorefrontIcon className="w-5 h-5 mr-2" />
                  {shop ? 'Modifier ma boutique' : 'Créer ma boutique'}
                </Link>

                <Link
                  href="/producer/orders"
                  className="w-full btn-secondary bg-fopcam-500/15 hover:bg-fopcam-500/25 border border-fopcam-400/30 text-fopcam-100 flex items-center justify-center transition-all rounded-2xl px-4 py-2"
                >
                  <ShoppingBagIcon className="w-5 h-5 mr-2" />
                  Voir mes commandes
                </Link>

                <button
                  type="button"
                  onClick={() => {
                    document.getElementById('friend-request-section')?.scrollIntoView({ behavior: 'smooth' })
                  }}
                  className="w-full btn-secondary bg-white/10 hover:bg-white/20 border-white/20 flex items-center justify-center text-white hover:text-white"
                >
                  <UserIcon className="w-5 h-5 mr-2" />
                  Demandes clients
                </button>

                <button
                  type="button"
                  onClick={() => {
                    document.getElementById('accepted-clients-section')?.scrollIntoView({ behavior: 'smooth' })
                  }}
                  className="w-full btn-secondary bg-white/10 hover:bg-white/20 border-white/20 flex items-center justify-center text-white hover:text-white"
                >
                  <UserIcon className="w-5 h-5 mr-2" />
                  Mes clients ({acceptedFriends.length})
                </button>

                <Link
                  href="/producer/new-product"
                  className="w-full btn-primary bg-gradient-fopcam hover:bg-gradient-fopcam flex items-center justify-center"
                >
                  <PlusIcon className="w-5 h-5 mr-2" />
                  Ajouter un produit
                </Link>
                </div>
              </div>
            </div>
          </motion.div>

          {/* Contenu principal */}
          <motion.div
            initial={{ opacity: 0, x: 20 }}
            animate={{ opacity: 1, x: 0 }}
            transition={{ delay: 0.2 }}
            className="lg:col-span-2"
          >
            {/* Demandes Devenir Client */}
            <div id="friend-request-section" className="glass-effect rounded-3xl overflow-hidden shadow-2xl mb-8 border border-white/10">
              <div className="bg-gradient-to-r from-fopcam-400 via-fopcam-500 to-future-800 p-6 text-white">
                <div className="flex items-center justify-between gap-4">
                  <div>
                    <p className="text-sm uppercase tracking-[0.25em] text-white/80 mb-2">Demandes</p>
                    <h2 className="text-2xl font-bold">Demandes Devenir Client</h2>
                  </div>
                  <span className="rounded-full bg-white/10 px-3 py-1 text-xs uppercase tracking-[0.25em] text-white/90">
                    {friendRequests.length} en attente
                  </span>
                </div>
                <p className="text-white/80 mt-3">Gérez les demandes clients pour votre boutique.</p>
              </div>
              <div className="p-6 bg-future-950/80">
                {friendRequests.length === 0 ? (
                  <div className="rounded-3xl border border-white/10 bg-white/5 p-6 text-center text-future-300">
                    Aucune demande en attente pour le moment.
                  </div>
                ) : (
                  <div className="space-y-4">
                    {friendRequests.map(request => (
                      <div key={request.id} className="rounded-3xl border border-white/10 bg-white/5 p-5">
                        <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
                          <div>
                            <p className="text-sm text-future-300">Client potentiel</p>
                            <p className="text-white font-semibold">{request.requester?.first_name || request.requester?.username || 'Utilisateur'}</p>
                            <p className="text-future-400 text-sm">@{request.requester?.username}</p>
                          </div>
                          <div className="flex gap-2 flex-wrap">
                            <Link
                              href={`/profile/${request.requester?.username}`}
                              className="btn-secondary bg-white/10 hover:bg-white/20 text-white text-sm px-4 py-2 rounded-2xl"
                            >
                              Voir profil
                            </Link>
                            <button
                              type="button"
                              onClick={() => handleFriendRequestAction(request.id, 'accept')}
                              className="btn-primary bg-gradient-fopcam hover:bg-gradient-fopcam text-sm px-4 py-2 rounded-2xl"
                            >
                              Accepter
                            </button>
                            <button
                              type="button"
                              onClick={() => handleFriendRequestAction(request.id, 'decline')}
                              className="btn-secondary bg-white/10 hover:bg-white/20 text-white text-sm px-4 py-2 rounded-2xl"
                            >
                              Refuser
                            </button>
                          </div>
                        </div>
                      </div>
                    ))}
                  </div>
                )}
              </div>
            </div>

            {/* Mes Clients */}
            <div id="accepted-clients-section" className="glass-effect rounded-3xl overflow-hidden shadow-2xl mb-8 border border-white/10">
              <div className="bg-gradient-to-r from-fopcam-400 via-fopcam-500 to-future-800 p-6 text-white">
                <div className="flex items-center justify-between gap-4">
                  <div>
                    <p className="text-sm uppercase tracking-[0.25em] text-white/80 mb-2">Clients</p>
                    <h2 className="text-2xl font-bold">Mes Clients</h2>
                  </div>
                  <span className="rounded-full bg-white/10 px-3 py-1 text-xs uppercase tracking-[0.25em] text-white/90">
                    {acceptedFriends.length} client{acceptedFriends.length !== 1 ? 's' : ''}
                  </span>
                </div>
                <p className="text-white/80 mt-3">Gérez vos clients acceptés et supprimez-les si nécessaire.</p>
              </div>
              <div className="p-6 bg-future-950/80">
                {acceptedFriends.length === 0 ? (
                  <div className="rounded-3xl border border-white/10 bg-white/5 p-6 text-center text-future-300">
                    Aucun client pour le moment.
                  </div>
                ) : (
                  <div className="space-y-4">
                    {acceptedFriends.map(friend => {
                      const currentUserId = user?.user?.id || user?.id
                      const isRequester = friend.requester?.id === currentUserId
                      const clientInfo = isRequester ? friend.receiver : friend.requester
                      return (
                        <div key={friend.id} className="rounded-3xl border border-white/10 bg-white/5 p-5">
                          <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
                            <div>
                              <p className="text-sm text-future-300">Client</p>
                              <p className="text-white font-semibold">{clientInfo?.first_name || clientInfo?.username || 'Utilisateur'}</p>
                              <p className="text-future-400 text-sm">@{clientInfo?.username}</p>
                            </div>
                            <div className="flex gap-2 flex-wrap">
                              <Link
                                href={`/profile/${clientInfo?.username}`}
                                className="btn-secondary bg-white/10 hover:bg-white/20 text-white text-sm px-4 py-2 rounded-2xl"
                              >
                                Voir profil
                              </Link>
                              <button
                                type="button"
                                onClick={() => handleRemoveClient(friend.id)}
                                className="btn-secondary bg-red-500/20 hover:bg-red-500/30 text-red-400 hover:text-red-300 text-sm px-4 py-2 rounded-2xl flex items-center gap-2"
                              >
                                <TrashIcon className="w-4 h-4" />
                                Retirer
                              </button>
                            </div>
                          </div>
                        </div>
                      )
                    })}
                  </div>
                )}
              </div>
            </div>

            {/* Notes reçues par le vendeur */}
            <div className="glass-effect rounded-3xl overflow-hidden shadow-2xl mb-8 border border-white/10">
              <div className="bg-gradient-to-r from-fopcam-400 via-fopcam-500 to-future-800 p-6 text-white">
                <div className="flex items-center justify-between gap-4">
                  <div>
                    <p className="text-sm uppercase tracking-[0.25em] text-white/80 mb-2">Notations</p>
                    <h2 className="text-2xl font-bold">Notes reçues</h2>
                  </div>
                  <span className="rounded-full bg-white/10 px-3 py-1 text-xs uppercase tracking-[0.25em] text-white/90">
                    {reviews.length} avis
                  </span>
                </div>
                <p className="text-white/80 mt-3">Consultez les notations et commentaires laissés par vos clients.</p>
              </div>
              <div className="p-6 bg-future-950/80 space-y-6">
                <div className="grid gap-4 md:grid-cols-3">
                  <div className="rounded-3xl border border-white/10 bg-white/5 p-4">
                    <p className="text-sm text-future-300">Moyenne</p>
                    <p className="text-3xl font-bold text-white mt-3">{averageRating ? Math.round(averageRating) : '—'}</p>
                    <p className="text-future-400 text-sm mt-1">sur 10</p>
                  </div>
                  <div className="rounded-3xl border border-white/10 bg-white/5 p-4">
                    <p className="text-sm text-future-300">Étoiles</p>
                    <div className="mt-3">{renderStars(averageRating)}</div>
                  </div>
                  <div className="rounded-3xl border border-white/10 bg-white/5 p-4">
                    <p className="text-sm text-future-300">Nombre d’avis</p>
                    <p className="text-3xl font-bold text-white mt-3">{reviews.length}</p>
                  </div>
                </div>

                {reviews.length === 0 ? (
                  <div className="rounded-3xl border border-white/10 bg-white/5 p-6 text-center text-future-300">
                    Aucun avis reçu pour le moment.
                  </div>
                ) : (
                  <div className="space-y-4">
                    {reviews.map(review => (
                      <div key={review.id} className="rounded-3xl border border-white/10 bg-white/5 p-5">
                        <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
                          <div>
                            <p className="text-sm text-future-300">Client</p>
                            <p className="text-white font-semibold">{review.reviewer?.first_name || review.reviewer?.username || 'Utilisateur'}</p>
                            <p className="text-future-400 text-sm">@{review.reviewer?.username}</p>
                            <p className="text-future-400 text-sm mt-2">{new Date(review.created_at).toLocaleDateString('fr-FR')}</p>
                          </div>
                          <div className="flex items-center gap-2">
                            <span className="text-white font-bold text-lg">{review.rating}/10</span>
                            {renderStars(review.rating)}
                          </div>
                        </div>
                        {review.comment && (
                          <div className="mt-4 rounded-3xl border border-white/10 bg-future-950/70 p-4 text-future-300">
                            {review.comment}
                          </div>
                        )}
                      </div>
                    ))}
                  </div>
                )}
              </div>
            </div>

            {shop && (
              <div className="glass-effect rounded-3xl overflow-hidden shadow-2xl mb-8 border border-white/10">
                <div className="bg-gradient-to-r from-fopcam-400 via-fopcam-500 to-future-800 p-6 text-white">
                  <div className="flex items-center justify-between gap-4">
                    <div className="flex items-center gap-4">
                      <div className="relative">
                        {shop.logo ? (
                          <img
                            src={buildMediaUrl(shop.logo)}
                            alt="Logo de la boutique"
                            className="w-16 h-16 rounded-full object-cover border-2 border-white/20"
                          />
                        ) : (
                          <div className="w-16 h-16 rounded-full bg-white/10 flex items-center justify-center">
                            <BuildingStorefrontIcon className="w-8 h-8 text-white" />
                          </div>
                        )}
                        <button
                          onClick={() => {
                            // TODO: Implement logo upload
                            alert('Fonctionnalité de modification du logo à venir')
                          }}
                          className="absolute -bottom-1 -right-1 w-6 h-6 bg-fopcam-400 rounded-full flex items-center justify-center border-2 border-white hover:bg-fopcam-500 transition-colors"
                        >
                          <PencilIcon className="w-3 h-3 text-white" />
                        </button>
                      </div>
                      <div>
                        <p className="text-sm uppercase tracking-[0.25em] text-white/80 mb-2">Ma boutique</p>
                        <h2 className="text-2xl font-bold">{shop.name}</h2>
                      </div>
                    </div>
                    <span className="rounded-full bg-white/10 px-3 py-1 text-xs uppercase tracking-[0.25em] text-white/90">
                      {shop.active ? 'Active' : 'En pause'}
                    </span>
                  </div>
                  <p className="text-white/80 mt-3">{shop.description}</p>
                </div>
                <div className="p-6 bg-future-950/80 grid gap-4 md:grid-cols-2">
                  <div className="rounded-3xl border border-white/10 bg-white/5 p-4">
                    <p className="text-sm text-future-300">Localisation</p>
                    <p className="text-white mt-2">{shop.location}</p>
                  </div>
                  {shop.phone && (
                    <div className="rounded-3xl border border-white/10 bg-white/5 p-4">
                      <p className="text-sm text-future-300">Téléphone</p>
                      <p className="text-white mt-2">{shop.phone}</p>
                    </div>
                  )}
                  {shop.email && (
                    <div className="rounded-3xl border border-white/10 bg-white/5 p-4">
                      <p className="text-sm text-future-300">Email</p>
                      <p className="text-white mt-2">{shop.email}</p>
                    </div>
                  )}
                  <Link
                    href="/producer/create-shop"
                    className="rounded-3xl border border-fopcam-400/30 bg-fopcam-500/10 px-4 py-3 text-sm font-semibold text-fopcam-200 text-center hover:bg-fopcam-500/20 transition"
                  >
                    Modifier la boutique
                  </Link>
                </div>
              </div>
            )}

            {/* Produits */}
            <div className="glass-effect rounded-3xl p-6 shadow-2xl">
              <div className="flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between mb-6">
                <div>
                  <h2 className="text-2xl font-bold text-white">Mes Produits</h2>
                  <p className="text-future-400 text-sm">Consultez et filtrez votre catalogue selon vos modes.</p>
                </div>
                <div className="flex flex-col gap-3 sm:flex-row sm:items-center">
                  {shop && products.length === 0 && (
                    <button
                      onClick={handleSeedProducts}
                      disabled={seeding}
                      className="btn-secondary bg-white/10 hover:bg-white/20 text-white font-semibold rounded-2xl px-4 py-2 transition-all duration-300"
                    >
                      {seeding ? 'Génération en cours…' : 'Ajouter des produits d’exemple'}
                    </button>
                  )}
                  <Link
                    href="/producer/new-product"
                    className="btn-primary bg-gradient-fopcam hover:bg-gradient-fopcam text-sm px-4 py-2"
                  >
                    <PlusIcon className="w-4 h-4 mr-1" />
                    Nouveau produit
                  </Link>
                </div>
              </div>
              {seedMessage && (
                <div className="mb-4 rounded-3xl border border-fopcam-400/30 bg-fopcam-500/10 p-4 text-sm text-white">
                  {seedMessage}
                </div>
              )}

              <FilterPanel
                mode={mode}
                onModeChange={setMode}
                values={filters}
                onChange={handleFilterChange}
                onApply={() => {}}
                onClear={handleClearFilters}
                categoryOptions={categoryOptions}
                productOptions={productOptions}
                statusOptions={statusOptions}
              />

              {filteredProducts.length === 0 ? (
                <div className="text-center py-12">
                  <BuildingStorefrontIcon className="w-16 h-16 text-future-400 mx-auto mb-4" />
                  <h3 className="text-xl font-medium text-white mb-2">Aucun produit</h3>
                  <p className="text-future-300 mb-6">Commencez par créer votre premier produit</p>
                  <Link
                    href="/producer/new-product"
                    className="btn-primary bg-gradient-fopcam hover:bg-gradient-fopcam"
                  >
                    Créer mon premier produit
                  </Link>
                </div>
              ) : (
                <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-6">
                  {filteredProducts.map(p => (
                    <motion.div
                      key={p.id}
                      initial={{ opacity: 0, scale: 0.9 }}
                      animate={{ opacity: 1, scale: 1 }}
                      className="glass-effect rounded-xl overflow-hidden border border-white/10 hover:border-fopcam-400/30 transition-all hover:shadow-lg hover:shadow-fopcam-400/20"
                    >
                      {/* Image du produit */}
                      <div className="relative w-full h-48 bg-gradient-to-br from-future-700 to-future-900 overflow-hidden flex items-center justify-center">
                        {p.image ? (
                          <img
                            src={buildMediaUrl(p.image)}
                            alt={p.title}
                            className="w-full h-full object-cover hover:scale-105 transition-transform duration-300"
                          />
                        ) : (
                          <div className="flex flex-col items-center justify-center">
                            <BuildingStorefrontIcon className="w-12 h-12 text-future-400 mb-2" />
                            <p className="text-future-400 text-sm">Aucune image</p>
                          </div>
                        )}
                      </div>

                      {/* Infos du produit */}
                      <div className="p-4">
                        <h3 className="text-lg font-semibold text-white mb-1 line-clamp-2">{p.title}</h3>
                        <p className="text-future-300 text-sm line-clamp-2 mb-3">{p.description}</p>

                        {/* Prix et quantité */}
                        <div className="mb-4 p-3 bg-white/5 rounded-lg border border-fopcam-400/20">
                          <div className="flex justify-between items-center">
                            <span className="text-fopcam-400 font-bold text-lg">{p.price} FCFA</span>
                            <span className={`text-sm font-medium px-2 py-1 rounded-lg ${
                              p.quantity > 0 
                                ? 'bg-fopcam-500/20 text-fopcam-200' 
                                : 'bg-red-500/20 text-red-200'
                            }`}>
                              {p.quantity} stock
                            </span>
                          </div>
                        </div>
                              
                        {/* Actions */}
                        <div className="flex gap-2 flex-wrap">
                          <Link
                            href={`/producer/edit/${p.id}`}
                            className="flex-1 min-w-[120px] inline-flex items-center justify-center text-fopcam-400 hover:text-fopcam-300 text-sm font-medium py-2 px-3 rounded-xl border border-fopcam-400/30 hover:border-fopcam-400 transition-all"
                          >
                            <PencilIcon className="w-4 h-4 mr-1" />
                            Modifier
                          </Link>
                          <button
                            onClick={async (e) => {
                              e.preventDefault()
                              if (!confirm('Supprimer ce produit ?')) return
                              try {
                                const res = await fetchWithAuth(process.env.NEXT_PUBLIC_API_URL + `/api/products/${p.id}/`, {
                                  method: 'DELETE'
                                })
                                if (res.ok) {
                                  setProducts(products.filter(x => x.id !== p.id))
                                } else {
                                  const errorData = await res.json().catch(() => null)
                                  console.error('Erreur suppression produit', errorData)
                                  alert(errorData?.detail || 'Erreur lors de la suppression du produit')
                                }
                              } catch (error) {
                                console.error('Erreur suppression produit', error)
                                alert('Erreur lors de la suppression du produit')
                              }
                            }}
                            className="inline-flex items-center justify-center text-red-400 hover:text-red-300 text-sm font-medium py-2 px-3 rounded-lg border border-red-400/30 hover:border-red-400 transition-all"
                           >
                            <TrashIcon className="w-4 h-4 mr-1" />
                            Supprimer
                          </button>
                        </div>
                      </div>
                    </motion.div>
                  ))}
                </div>
              )}
            </div>
          </motion.div>
        </div>
      </div>
    </div>
  )
}
