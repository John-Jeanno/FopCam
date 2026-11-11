import { useRouter } from 'next/router'
import { useEffect, useState } from 'react'
import Link from 'next/link'
import { fetchWithAuth } from '../utils/tokenManager'

export default function CheckoutPage() {
  const router = useRouter()
  const { product, shop } = router.query
  const [productData, setProductData] = useState(null)
  const [cart, setCart] = useState([])
  const [drivers, setDrivers] = useState([])
  const [driversLoading, setDriversLoading] = useState(false)
  const [driversError, setDriversError] = useState(null)
  const [loading, setLoading] = useState(false)
  const apiUrl = process.env.NEXT_PUBLIC_API_URL || 'http://127.0.0.1:8000'

  const orderItems = cart.length > 0
    ? cart
    : productData
      ? [{ product_id: productData.id, title: productData.title, price: productData.price, qty: 1, shop_name: productData.shop?.name }]
      : []

  const orderTotal = orderItems.reduce((sum, item) => sum + ((item.price || 0) * (item.qty || 1)), 0)

  useEffect(() => {
    const storedCart = JSON.parse(localStorage.getItem('cart') || '[]')
    setCart(Array.isArray(storedCart) ? storedCart : [])
  }, [])

  useEffect(() => {
    if (!product) return
    const load = async () => {
      try {
        const res = await fetch(`${apiUrl}/api/products/${product}/`)
        if (res.ok) {
          const data = await res.json()
          setProductData(data)
        }
      } catch (err) {
        console.error('Erreur loading product for checkout', err)
      }
    }
    load()
  }, [product])

  useEffect(() => {
    const shopId = cart.length > 0 ? cart[0].shop_id : productData?.shop?.id
    if (!shopId) {
      setDrivers([])
      setDriversError(null)
      return
    }

    const loadDrivers = async () => {
      setDriversLoading(true)
      setDriversError(null)
      try {
        const res = await fetch(`${apiUrl}/api/profiles/?role=driver&shop_id=${shopId}`)
        if (!res.ok) {
          throw new Error(`Erreur lors du chargement des livreurs (${res.status})`)
        }
        const data = await res.json()
        setDrivers(Array.isArray(data) ? data : [])
      } catch (error) {
        console.error(error)
        setDriversError('Impossible de charger les livreurs proches.')
      } finally {
        setDriversLoading(false)
      }
    }

    loadDrivers()
  }, [apiUrl, cart, productData])

  const handlePlaceOrder = async () => {
    setLoading(true)
    try {
      const items = orderItems.length > 0
        ? orderItems.map(c => ({ product: c.product_id, quantity: c.qty || 1 }))
        : []

      if (items.length === 0) {
        alert('Aucun produit sélectionné pour la commande.')
        setLoading(false)
        return
      }

      const payload = {
        items,
        payment_method: 'cash_on_delivery'
      }

      const res = await fetchWithAuth(`${apiUrl}/api/orders/`, {
        method: 'POST',
        body: JSON.stringify(payload),
        headers: { 'Content-Type': 'application/json' }
      })

      if (res.ok) {
        await res.json()
        localStorage.removeItem('cart')
        setCart([])
        // Rediriger vers le tableau de bord client après une commande réussie
        router.push('/client/dashboard')
      } else {
        const err = await res.json().catch(() => null)
        alert(err?.detail || 'Erreur lors de la création de la commande')
      }
    } catch (error) {
      console.error(error)
      alert('Erreur réseau')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-future-50 via-white to-fopcam-50 py-10 px-4 sm:px-6 lg:px-8">
      <div className="mx-auto max-w-7xl">
        <div className="mb-8 rounded-[2rem] border border-future-200 bg-white/80 p-8 shadow-2xl backdrop-blur-xl">
          <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
            <div>
              <p className="text-xs uppercase tracking-[0.3em] text-fopcam-700">Paiement</p>
              <h1 className="mt-3 text-4xl font-black text-future-900">Finalisez votre commande</h1>
            </div>
            <div className="inline-flex items-center gap-3 rounded-full border border-future-200 bg-future-50 px-5 py-3 text-sm font-semibold text-future-700">
              <span className="inline-flex h-10 w-10 items-center justify-center rounded-full bg-fopcam-800 text-white">✓</span>
              Mode sécurisé / Paiement à la livraison
            </div>
          </div>
        </div>

        <div className="grid gap-8 lg:grid-cols-[1.8fr_1fr]">
          <section className="rounded-[2rem] border border-future-200 bg-white shadow-2xl p-8">
            <div className="mb-8 rounded-3xl bg-future-50 p-6 shadow-sm">
              <p className="text-sm uppercase tracking-[0.3em] text-future-500">Résumé de la commande</p>
              <h2 className="mt-3 text-3xl font-bold text-future-900">Détails du panier</h2>
              <p className="mt-2 text-future-500">Vérifiez les produits et le total avant de valider.</p>
            </div>

            {orderItems.length > 0 ? (
              <div className="space-y-6">
                {orderItems.map((item, index) => (
                  <div key={index} className="rounded-3xl border border-future-200 bg-future-50 p-6 shadow-sm">
                    <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
                      <div>
                        <p className="text-sm uppercase tracking-[0.3em] text-future-500">{item.shop_name || 'Boutique'}</p>
                        <h3 className="mt-2 text-xl font-semibold text-future-900">{item.title}</h3>
                      </div>
                      <div className="text-right">
                        <p className="text-lg font-bold text-fopcam-800">{item.price} FCFA</p>
                        <p className="text-sm text-future-500">Quantité : {item.qty}</p>
                      </div>
                    </div>
                  </div>
                ))}

                <div className="rounded-3xl bg-white p-6 shadow-sm border border-future-200">
                  <div className="flex items-center justify-between gap-4 text-future-500">
                    <span>Sous-total</span>
                    <span>{orderTotal} FCFA</span>
                  </div>
                  <div className="mt-4 flex items-center justify-between gap-4 text-future-600">
                    <span>Frais de livraison</span>
                    <span>0 FCFA</span>
                  </div>
                  <div className="mt-6 flex items-center justify-between gap-4 border-t border-future-200 pt-5 text-xl font-bold text-future-900">
                    <span>Total</span>
                    <span>{orderTotal} FCFA</span>
                  </div>
                </div>
              </div>
            ) : (
              <div className="rounded-3xl border border-dashed border-future-200 bg-future-50 p-10 text-center text-future-500">
                <p className="text-lg font-semibold text-future-900">Aucun produit sélectionné</p>
                <p className="mt-3">Ajoutez un produit à votre panier pour finaliser votre commande.</p>
                <Link href="/" className="mt-6 inline-flex items-center justify-center rounded-full border border-fopcam-300 bg-white px-6 py-3 text-sm font-semibold text-future-900 hover:bg-future-100 transition">
                  Retour à l'accueil
                </Link>
              </div>
            )}
          </section>

          <aside className="rounded-[2rem] border border-future-200 bg-future-950/95 p-8 text-white shadow-2xl">
            <div className="mb-8 rounded-3xl bg-fopcam-900/90 p-6 shadow-lg">
              <p className="text-xs uppercase tracking-[0.3em] text-fopcam-200">Paiement sécurisé</p>
              <h2 className="mt-3 text-3xl font-bold">Choisissez votre mode</h2>
              <p className="mt-3 text-future-300">Paiement à la livraison disponible pour toutes vos commandes.</p>
            </div>

            <div className="space-y-4">
              <div className="rounded-3xl border border-fopcam-700 bg-fopcam-900/80 p-5">
                <p className="text-sm uppercase tracking-[0.25em] text-fopcam-200">Mode</p>
                <p className="mt-2 text-lg font-semibold">Paiement à la livraison</p>
                <p className="mt-2 text-sm text-future-400">Aucun paiement en ligne nécessaire. Vous réglez à la réception.</p>
              </div>
              <div className="rounded-3xl border border-fopcam-700 bg-fopcam-900/80 p-5">
                <p className="text-sm uppercase tracking-[0.25em] text-fopcam-200">Service</p>
                <p className="mt-2 text-lg font-semibold">Livraison rapide</p>
                <p className="mt-2 text-sm text-future-400">Nos partenaires assurent une livraison locale fiable et rapide.</p>
              </div>
            </div>

            <div className="mt-8 rounded-3xl border border-fopcam-700 bg-fopcam-900/80 p-6">
              <p className="text-sm uppercase tracking-[0.3em] text-fopcam-200">Livreurs proches</p>
              <div className="mt-4 space-y-4 text-sm text-future-300">
                {driversLoading ? (
                  <p>Recherche des livreurs proches du vendeur...</p>
                ) : driversError ? (
                  <p className="text-red-300">{driversError}</p>
                ) : drivers.length === 0 ? (
                  <p>Aucun livreur disponible trouvé pour ce vendeur.</p>
                ) : (
                  drivers.map(driver => (
                    <div key={driver.id} className="rounded-2xl border border-future-700 bg-future-950/80 p-4">
                      <p className="font-semibold text-future-100">{driver.user.first_name || driver.user.username} {driver.user.last_name || ''}</p>
                      <p>Téléphone : {driver.phone || 'N/A'}</p>
                      <p>Matricule : {driver.motorcycle_plate || 'N/A'}</p>
                      <p className="text-xs text-future-500">{driver.city ? `${driver.city}, ${driver.country || ''}` : driver.country || 'Local'}</p>
                    </div>
                  ))
                )}
              </div>
            </div>

            <div className="mt-8 rounded-3xl border border-fopcam-700 bg-fopcam-900/80 p-6">
              <p className="text-sm uppercase tracking-[0.3em] text-fopcam-200">Info commande</p>
              <div className="mt-4 space-y-3 text-sm text-future-300">
                <p><span className="font-semibold text-future-100">Sécurité :</span> Connexion HTTPS active</p>
                <p><span className="font-semibold text-future-100">Support :</span> support@fopcam.com</p>
                <p><span className="font-semibold text-future-100">Retour :</span> Facile et rapide</p>
              </div>
            </div>

            <div className="mt-8 flex flex-col gap-4">
              <button onClick={handlePlaceOrder} disabled={loading || orderItems.length === 0} className="btn-primary w-full text-center">
                {loading ? 'Traitement...' : 'Valider la commande'}
              </button>
              <Link href="/" className="btn-secondary w-full text-center">
                Retour à l'accueil
              </Link>
            </div>
          </aside>
        </div>
      </div>
    </div>
  )
}
