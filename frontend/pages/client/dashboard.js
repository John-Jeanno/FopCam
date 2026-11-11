import { useEffect, useState } from 'react'
import { useRouter } from 'next/router'
import Link from 'next/link'
import { motion } from 'framer-motion'
import {
  ShoppingBagIcon,
  ChatBubbleLeftRightIcon,
  ClockIcon,
  CheckCircleIcon,
  XCircleIcon,
  TruckIcon,
  ArrowLeftIcon,
  UserIcon,
  PencilIcon,
  PhotoIcon
} from '@heroicons/react/24/outline'

export default function ClientDashboard() {
  const [user, setUser] = useState(null)
  const [orders, setOrders] = useState([])
  const [messages, setMessages] = useState([])
  const [profiles, setProfiles] = useState([])
  const [loadingProfiles, setLoadingProfiles] = useState(true)
  const [loading, setLoading] = useState(true)
  const router = useRouter()
  const apiUrl = process.env.NEXT_PUBLIC_API_URL || 'http://127.0.0.1:8000'

  useEffect(() => {
    const checkAuth = async () => {
      const token = localStorage.getItem('access_token')
      if (!token) {
        router.push('/login')
        return
      }

      try {
        // Vérifier le profil utilisateur
        const profileRes = await fetch(apiUrl + '/api/auth/profile/', {
          headers: { Authorization: `Bearer ${token}` }
        })

        if (profileRes.ok) {
          const profile = await profileRes.json()
          setUser(profile)

          // Charger les données
          await loadClientData(token)
        } else {
          localStorage.removeItem('access')
          localStorage.removeItem('access_token')
          router.push('/login')
        }
      } catch (error) {
        console.error('Erreur d\'authentification:', error)
        router.push('/login')
      } finally {
        setLoading(false)
      }
    }

    checkAuth()
  }, [])

  const loadClientData = async (token) => {
    try {
      // Charger les commandes
      const ordersRes = await fetch(apiUrl + '/api/orders/', {
        headers: { Authorization: `Bearer ${token}` }
      })

      if (ordersRes.ok) {
        const ordersData = await ordersRes.json()
        setOrders(Array.isArray(ordersData) ? ordersData : ordersData.results || [])
      }

      // Charger les messages
      const messagesRes = await fetch(apiUrl + '/api/messages/', {
        headers: { Authorization: `Bearer ${token}` }
      })

      if (messagesRes.ok) {
        const messagesData = await messagesRes.json()
        setMessages(Array.isArray(messagesData) ? messagesData : messagesData.results || [])
      }

      // Charger les profils vendeurs
      const profilesRes = await fetch(apiUrl + '/api/profiles/?role=producer', {
        headers: { Authorization: `Bearer ${token}` }
      })

      if (profilesRes.ok) {
        const profilesData = await profilesRes.json()
        const loadedProfiles = Array.isArray(profilesData) ? profilesData : profilesData.results || []
        setProfiles(loadedProfiles)
      }
    } catch (error) {
      console.error('Erreur lors du chargement des données:', error)
    } finally {
      setLoadingProfiles(false)
    }
  }

  const handleLogout = () => {
    localStorage.removeItem('access')
    localStorage.removeItem('access_token')
    router.push('/')
  }

  const getStatusIcon = (status) => {
    switch (status) {
      case 'pending':
        return <ClockIcon className="w-5 h-5 text-yellow-500" />
      case 'paid':
        return <CheckCircleIcon className="w-5 h-5 text-blue-500" />
      case 'shipped':
        return <TruckIcon className="w-5 h-5 text-purple-500" />
      case 'completed':
        return <CheckCircleIcon className="w-5 h-5 text-green-500" />
      case 'cancelled':
        return <XCircleIcon className="w-5 h-5 text-red-500" />
      default:
        return <ClockIcon className="w-5 h-5 text-gray-500" />
    }
  }

  const getStatusText = (status) => {
    const statusMap = {
      'pending': 'En attente',
      'paid': 'Payé',
      'shipped': 'Expédié',
      'completed': 'Terminé',
      'cancelled': 'Annulé'
    }
    return statusMap[status] || status
  }

  const startConversationWithProducer = (profile) => {
    const currentUsername = user?.user?.username || user?.username
    const producerUsername = profile?.user?.username || profile?.username
    if (!currentUsername || !producerUsername) return
    const participants = [currentUsername, producerUsername].sort()
    const room = `private_${participants.join('_')}`
    router.push(`/messages?room=${encodeURIComponent(room)}`)
  }

  const buildMediaUrl = (path) => {
    if (!path) return null
    if (path.startsWith('http')) return path
    return `${apiUrl}${path.startsWith('/') ? path : `/${path}`}`
  }

  if (loading) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-future-900 via-future-800 to-fopcam-900 flex items-center justify-center">
        <div className="text-white text-xl">Chargement...</div>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-future-900 via-future-800 to-fopcam-900">
      {/* Header */}
      <header className="bg-black/20 backdrop-blur-sm border-b border-white/10">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between items-center h-16">
            <div className="flex items-center space-x-4">
              <Link href="/" className="flex items-center text-white hover:text-fopcam-300 transition-colors">
                <ArrowLeftIcon className="w-5 h-5 mr-2" />
                Retour à l'accueil
              </Link>
              <div className="text-white">
                <h1 className="text-xl font-bold">Mon Espace Client</h1>
                <p className="text-sm text-future-300">Bienvenue, {user?.user?.first_name || user?.user?.username}</p>
              </div>
            </div>
            <button
              onClick={handleLogout}
              className="px-4 py-2 bg-fopcam-600 hover:bg-fopcam-700 text-white rounded-lg transition-colors"
            >
              Déconnexion
            </button>
          </div>
        </div>
      </header>

      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
          {/* Historique des achats */}
          <div className="lg:col-span-2">
            <motion.div
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              className="glass-effect rounded-3xl p-6"
            >
              <div className="flex items-center mb-6">
                <ShoppingBagIcon className="w-8 h-8 text-fopcam-400 mr-3" />
                <h2 className="text-2xl font-bold text-white">Historique des achats</h2>
              </div>

              {orders.length === 0 ? (
                <div className="text-center py-12">
                  <ShoppingBagIcon className="w-16 h-16 text-future-400 mx-auto mb-4" />
                  <p className="text-future-300 text-lg">Aucun achat pour le moment</p>
                  <p className="text-future-400 text-sm mt-2">Découvrez nos produits et commencez vos achats !</p>
                  <Link
                    href="/"
                    className="inline-flex items-center mt-4 px-6 py-3 bg-fopcam-600 hover:bg-fopcam-700 text-white rounded-xl transition-colors"
                  >
                    Explorer les produits
                  </Link>
                </div>
              ) : (
                <div className="space-y-4">
                  {orders.map((order) => (
                    <motion.div
                      key={order.id}
                      initial={{ opacity: 0, x: -20 }}
                      animate={{ opacity: 1, x: 0 }}
                      className="bg-white/5 rounded-xl p-4 border border-white/10"
                    >
                      <div className="flex items-center justify-between mb-3">
                        <div className="flex items-center space-x-3">
                          {getStatusIcon(order.status)}
                          <div>
                            <p className="text-white font-medium">Commande #{order.id}</p>
                            <p className="text-future-300 text-sm">
                              {new Date(order.created_at).toLocaleDateString('fr-FR')}
                            </p>
                          </div>
                        </div>
                        <div className="text-right">
                          <p className="text-white font-bold">{order.total} FCFA</p>
                          <p className="text-future-300 text-sm">{getStatusText(order.status)}</p>
                        </div>
                      </div>

                      {order.items && order.items.length > 0 && (
                        <div className="mt-3 pt-3 border-t border-white/10">
                          <p className="text-future-300 text-sm mb-2">Articles:</p>
                          <div className="space-y-1">
                            {order.items.map((item, index) => (
                              <div key={index} className="flex justify-between text-sm">
                                <span className="text-future-200">
                                  {item.product?.title || 'Produit'} (x{item.quantity})
                                </span>
                                <span className="text-white">{item.price} FCFA</span>
                              </div>
                            ))}
                          </div>
                        </div>
                      )}
                    </motion.div>
                  ))}
                </div>
              )}
            </motion.div>
          </div>

          <div className="lg:col-span-1">
            {/* Mon Profil */}
            <motion.div
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              className="glass-effect rounded-3xl p-6 mb-6"
            >
              <div className="flex items-center justify-between mb-6">
                <div className="flex items-center">
                  <UserIcon className="w-8 h-8 text-fopcam-400 mr-3" />
                  <h2 className="text-2xl font-bold text-white">Mon Profil</h2>
                </div>
                <Link
                  href="/profile/edit"
                  className="inline-flex items-center px-3 py-2 bg-fopcam-600 hover:bg-fopcam-700 text-white rounded-lg transition-colors text-sm"
                >
                  <PencilIcon className="w-4 h-4 mr-2" />
                  Modifier
                </Link>
              </div>

              <div className="space-y-4">
                {/* Photo de profil */}
                <div className="flex items-center space-x-4">
                  <div className="w-16 h-16 rounded-full overflow-hidden bg-gray-800 flex items-center justify-center">
                    {user?.profile_image ? (
                      <img
                        src={buildMediaUrl(user.profile_image)}
                        alt="Photo de profil"
                        className="w-full h-full object-cover"
                      />
                    ) : (
                      <UserIcon className="w-8 h-8 text-future-300" />
                    )}
                  </div>
                  <div>
                    <p className="text-white font-semibold">
                      {user?.user?.first_name} {user?.user?.last_name}
                    </p>
                    <p className="text-future-300 text-sm">@{user?.user?.username}</p>
                  </div>
                </div>

                {/* Informations du profil */}
                <div className="space-y-2">
                  {user?.phone && (
                    <div className="flex items-center text-future-200 text-sm">
                      <span className="w-16 text-future-400">Téléphone:</span>
                      <span>{user.phone}</span>
                    </div>
                  )}
                  {user?.city && (
                    <div className="flex items-center text-future-200 text-sm">
                      <span className="w-16 text-future-400">Ville:</span>
                      <span>{user.city}</span>
                    </div>
                  )}
                  {user?.bio && (
                    <div className="text-future-200 text-sm">
                      <span className="text-future-400">Bio:</span>
                      <p className="mt-1 text-xs leading-relaxed">{user.bio}</p>
                    </div>
                  )}
                </div>

                {/* Photo de couverture */}
                {user?.cover_image && (
                  <div className="mt-4">
                    <p className="text-future-400 text-sm mb-2">Photo de couverture:</p>
                    <div className="w-full h-20 rounded-lg overflow-hidden">
                      <img
                        src={buildMediaUrl(user.cover_image)}
                        alt="Photo de couverture"
                        className="w-full h-full object-cover"
                      />
                    </div>
                  </div>
                )}
              </div>
            </motion.div>

            {/* Discuter avec un vendeur */}
            <motion.div
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              className="glass-effect rounded-3xl p-6"
            >
              <div className="flex items-center mb-6">
                <UserIcon className="w-8 h-8 text-fopcam-400 mr-3" />
                <h2 className="text-2xl font-bold text-white">Discuter avec un vendeur</h2>
              </div>

              {loadingProfiles ? (
                <div className="text-center py-8">
                  <div className="inline-flex items-center justify-center w-10 h-10 rounded-full border border-white/20 animate-spin">
                    <div className="w-5 h-5 border-t-2 border-white"></div>
                  </div>
                  <p className="text-future-300 mt-3">Chargement des profils...</p>
                </div>
              ) : profiles.length === 0 ? (
                <div className="text-center py-8 text-future-300">Aucun vendeur disponible pour le moment.</div>
              ) : (
                <div className="space-y-3">
                  {profiles.map((profile) => (
                    <button
                      key={profile.id}
                      onClick={() => startConversationWithProducer(profile)}
                      className="w-full text-left bg-white/5 border border-white/10 rounded-3xl p-4 transition hover:bg-white/10"
                    >
                      <div className="flex items-center gap-4">
                        <div className="w-14 h-14 rounded-full overflow-hidden bg-gray-800 flex items-center justify-center">
                          {profile.profile_image ? (
                            <img
                              src={buildMediaUrl(profile.profile_image)}
                              alt={profile.user?.username || 'Vendeur'}
                              className="w-full h-full object-cover"
                            />
                          ) : (
                            <UserIcon className="w-6 h-6 text-future-300" />
                          )}
                        </div>
                        <div className="flex-1 min-w-0">
                          <p className="text-white font-semibold truncate">
                            {profile.user?.first_name || profile.user?.username}
                          </p>
                          <p className="text-future-300 text-sm truncate">
                            {profile.shop_name || profile.city || 'Vendeur'}
                          </p>
                        </div>
                        <span className="text-sm text-fopcam-300">Chat</span>
                      </div>
                    </button>
                  ))}
                </div>
              )}
            </motion.div>
          </div>
        </div>
      </div>
    </div>
  )
}
