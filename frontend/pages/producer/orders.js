import { useEffect, useState } from 'react'
import { useRouter } from 'next/router'
import Link from 'next/link'
import { ArrowLeftIcon, ShoppingBagIcon } from '@heroicons/react/24/outline'

const buildMediaUrl = (path) => {
  if (!path) return ''
  if (path.startsWith('http')) return path
  if (path.startsWith('/')) return process.env.NEXT_PUBLIC_API_URL + path
  return process.env.NEXT_PUBLIC_API_URL + '/media/' + path
}

export default function ProducerOrders() {
  const [orders, setOrders] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const router = useRouter()

  useEffect(() => {
    const token = localStorage.getItem('access')
    if (!token) {
      router.replace('/login')
      return
    }

    fetch(process.env.NEXT_PUBLIC_API_URL + '/api/orders/sales/', {
      headers: { 'Authorization': 'Bearer ' + token }
    })
      .then(async (response) => {
        if (response.status === 401 || response.status === 403) {
          router.replace('/login')
          throw new Error('Unauthorized')
        }
        if (!response.ok) {
          const err = await response.text()
          throw new Error(err || 'Erreur de chargement')
        }
        return response.json()
      })
      .then(data => {
        if (Array.isArray(data)) {
          setOrders(data)
        } else if (data.results) {
          setOrders(data.results)
        } else {
          setOrders([])
        }
      })
      .catch(err => {
        console.error('Erreur chargement commandes vendeur', err)
        setError('Impossible de récupérer vos commandes pour le moment.')
      })
      .finally(() => setLoading(false))
  }, [router])

  return (
    <div className="min-h-screen bg-gradient-to-br from-future-900 via-future-800 to-fopcam-900 p-4">
      <div className="max-w-6xl mx-auto">
        <div className="mb-8 flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <h1 className="text-3xl font-bold text-white">Mes commandes</h1>
            <p className="text-future-300">Liste des commandes contenant des produits de votre boutique.</p>
          </div>
          <div className="flex gap-3 flex-wrap">
            <Link href="/producer/dashboard" className="inline-flex items-center gap-2 rounded-2xl border border-white/10 bg-white/5 px-4 py-2 text-sm font-semibold text-white hover:border-fopcam-400 hover:text-fopcam-100 transition">
              <ArrowLeftIcon className="w-4 h-4" />
              Retour au dashboard
            </Link>
            <Link href="/producer/create-shop" className="inline-flex items-center gap-2 rounded-2xl border border-fopcam-400/30 bg-fopcam-500/15 px-4 py-2 text-sm font-semibold text-fopcam-100 hover:bg-fopcam-500/25 transition">
              <ShoppingBagIcon className="w-4 h-4" />
              Voir ma boutique
            </Link>
          </div>
        </div>

        {loading ? (
          <div className="min-h-[40vh] flex items-center justify-center">
            <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-fopcam-400"></div>
          </div>
        ) : error ? (
          <div className="rounded-3xl border border-red-500/20 bg-red-500/10 p-6 text-red-100">{error}</div>
        ) : orders.length === 0 ? (
          <div className="rounded-3xl border border-white/10 bg-white/5 p-8 text-center">
            <ShoppingBagIcon className="mx-auto mb-4 h-12 w-12 text-fopcam-400" />
            <h2 className="text-2xl font-semibold text-white mb-2">Aucune commande trouvée</h2>
            <p className="text-future-300">Vos produits n'ont pas encore été commandés.</p>
          </div>
        ) : (
          <div className="grid gap-6">
            {orders.map(order => (
              <div key={order.id} className="glass-effect rounded-3xl border border-white/10 p-6 shadow-2xl">
                <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
                  <div>
                    <p className="text-sm uppercase tracking-[0.3em] text-future-400">Commande #{order.id}</p>
                    <h2 className="text-2xl font-bold text-white">{order.status_display || order.status}</h2>
                  </div>
                  <div className="rounded-full bg-fopcam-500/15 px-4 py-2 text-sm font-semibold text-fopcam-100">
                    {order.created_at_formatted || order.created_at}
                  </div>
                </div>
                <div className="mt-4 grid gap-4 lg:grid-cols-3">
                  <div className="rounded-3xl border border-white/10 bg-white/5 p-4">
                    <p className="text-xs uppercase tracking-[0.28em] text-future-400">Total</p>
                    <p className="text-xl font-bold text-white mt-2">{order.total} FCFA</p>
                  </div>
                  <div className="rounded-3xl border border-white/10 bg-white/5 p-4">
                    <p className="text-xs uppercase tracking-[0.28em] text-future-400">Visiteur</p>
                    <p className="text-white mt-2">{order.buyer_username || `Utilisateur ${order.buyer}`}</p>
                  </div>
                  <div className="rounded-3xl border border-white/10 bg-white/5 p-4">
                    <p className="text-xs uppercase tracking-[0.28em] text-future-400">Articles</p>
                    <p className="text-white mt-2">{order.items?.length || 0}</p>
                  </div>
                </div>

                <div className="mt-6 space-y-4">
                  {order.items?.map(item => (
                    <div key={item.id} className="rounded-3xl border border-white/10 bg-future-950/80 p-4 grid gap-4 sm:grid-cols-[80px_minmax(0,_1fr)] items-center">
                      <div className="h-20 w-20 overflow-hidden rounded-3xl bg-white/5 flex items-center justify-center">
                        {item.product_image ? (
                          <img
                            src={buildMediaUrl(item.product_image)}
                            alt={item.product_title}
                            className="h-full w-full object-cover"
                          />
                        ) : (
                          <ShoppingBagIcon className="h-10 w-10 text-future-400" />
                        )}
                      </div>
                      <div>
                        <p className="font-semibold text-white">{item.product_title || 'Produit inconnu'}</p>
                        <p className="text-future-300 text-sm">Boutique : {item.shop_name || '—'}</p>
                        <p className="text-future-300 text-sm">Quantité : {item.quantity} × {item.price} FCFA</p>
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  )
}
