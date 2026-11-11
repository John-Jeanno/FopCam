import { useEffect, useState } from 'react'
import { useRouter } from 'next/router'
import Link from 'next/link'

export default function ProductDetail(){
  const router = useRouter()
  const { id } = router.query
  const [product, setProduct] = useState(null)
  const [user, setUser] = useState(null)
  const [loading, setLoading] = useState(true)
  const apiUrl = process.env.NEXT_PUBLIC_API_URL || 'http://127.0.0.1:8000'

  const buildMediaUrl = (path) => {
    if (!path) return ''
    if (path.startsWith('http')) return path
    if (path.startsWith('/')) return apiUrl + path
    return apiUrl + '/media/' + path
  }

  useEffect(()=>{
    if(!id) return

    const token = localStorage.getItem('access_token')
    const fetchProduct = async () => {
      try {
        const res = await fetch(`${apiUrl}/api/products/${id}/`)
        if (res.ok) {
          const data = await res.json()
          setProduct(data)
        }
      } catch (error) {
        console.error('Erreur chargement produit:', error)
      }
    }

    const fetchUser = async () => {
      if (!token) return
      try {
        const res = await fetch(`${apiUrl}/api/auth/profile/`, {
          headers: { Authorization: `Bearer ${token}` },
        })
        if (res.ok) {
          const data = await res.json()
          setUser(data)
        }
      } catch (error) {
        console.warn('Impossible de charger le profil connecté', error)
      }
    }

    Promise.all([fetchProduct(), fetchUser()]).finally(() => setLoading(false))
  },[id])

  // If user clicked Commander from a product card, auto add to cart and go to checkout
  useEffect(() => {
    if (!router.isReady) return
    if (!router.query?.buy) return
    if (!product) return

    // If not logged, addToCart will redirect to login
    const doBuy = async () => {
      if (!user) {
        router.push(`/login?next=/products/${product.id}?buy=1`)
        return
      }
      const cart = JSON.parse(localStorage.getItem('cart')||'[]')
      cart.push({
        product_id: product.id,
        title: product.title,
        price: product.price,
        qty: 1,
        shop_id: product.shop?.id,
        shop_name: product.shop?.name
      })
      localStorage.setItem('cart', JSON.stringify(cart))
      router.push(`/checkout?product=${product.id}`)
    }

    doBuy()
  }, [router, product, user])

  const addToCart = () => {
    if (!user) {
      router.push(`/login?next=${encodeURIComponent(router.asPath)}`)
      return
    }

    const cart = JSON.parse(localStorage.getItem('cart')||'[]')
    cart.push({
      product_id: product.id,
      title: product.title,
      price: product.price,
      qty: 1,
      shop_id: product.shop?.id,
      shop_name: product.shop?.name
    })
    localStorage.setItem('cart', JSON.stringify(cart))
    alert('Ajouté au panier')
  }

  const contactVendor = async () => {
    if (!user) {
      router.push(`/login?next=/products/${product.id}`)
      return
    }

    try {
      const token = localStorage.getItem('access_token')
      const response = await fetch(`${apiUrl}/api/messages/start_conversation/`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          recipient_id: product.shop.owner.id,
        }),
      })

      if (response.ok) {
        const data = await response.json()
        // Rediriger vers la page de messagerie avec la room_id
        router.push(`/messages?room=${data.room_id}`)
      } else {
        alert('Erreur lors de la création de la conversation')
      }
    } catch (error) {
      console.error('Erreur:', error)
      alert('Erreur lors de la connexion')
    }
  }

  if(loading) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-future-50 via-white to-fopcam-50 flex items-center justify-center">
        <p className="text-future-700">Chargement du produit…</p>
      </div>
    )
  }

  if(!product) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-future-50 via-white to-fopcam-50 flex items-center justify-center px-4 py-10">
        <div className="max-w-3xl w-full rounded-3xl bg-white p-10 shadow-xl border border-future-200 text-center">
          <p className="text-future-700 text-xl font-semibold mb-4">Produit introuvable.</p>
          <Link href="/" className="inline-flex items-center gap-2 rounded-2xl bg-fopcam-600 px-5 py-3 text-white font-semibold hover:bg-fopcam-700 transition">
            Retour à l'accueil
          </Link>
        </div>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-future-50 via-white to-fopcam-50 px-4 py-10">
      <div className="max-w-4xl mx-auto">
        <div className="rounded-3xl bg-white/95 p-8 shadow-xl border border-white/80">
          <div className="grid gap-8 md:grid-cols-2">
            {/* Image du produit */}
            <div className="space-y-4">
              {product.image ? (
                <img
                  src={buildMediaUrl(product.image)}
                  alt={product.title}
                  className="w-full rounded-2xl object-cover shadow-lg"
                />
              ) : (
                <div className="w-full h-64 bg-gradient-fopcam rounded-2xl flex items-center justify-center">
                  <span className="text-6xl">🍎</span>
                </div>
              )}
            </div>

            {/* Informations du produit */}
            <div className="space-y-6">
              <div>
                <h1 className="text-3xl font-bold text-future-900 mb-2">{product.title}</h1>
                <p className="text-future-600">{product.description}</p>
              </div>

              <div className="space-y-4">
                <div className="flex items-center justify-between">
                  <span className="text-2xl font-bold text-fopcam-600">{product.price} FCFA</span>
                  {product.category && (
                    <span className="px-3 py-1 bg-future-100 text-future-700 rounded-full text-sm">
                      {product.category.name}
                    </span>
                  )}
                </div>

                {product.shop && (
                  <div className="p-4 bg-future-50 rounded-2xl border border-future-200 space-y-3">
                    <div>
                      <p className="text-sm text-future-500 mb-1">Vendu par</p>
                      <Link
                        href={`/shop/${product.shop.id}`}
                        className="font-semibold text-fopcam-700 hover:text-fopcam-800"
                      >
                        {product.shop.name}
                      </Link>
                    </div>
                    <div className="flex flex-wrap gap-3">
                      <button
                        onClick={contactVendor}
                        className="inline-flex items-center justify-center rounded-2xl border border-fopcam-500 bg-fopcam-50 px-4 py-3 text-sm font-semibold text-fopcam-700 hover:bg-fopcam-100 transition"
                      >
                        💬 Contacter le vendeur
                      </button>
                      <Link
                        href={`/shop/${product.shop.id}`}
                        className="inline-flex items-center justify-center rounded-2xl border border-fopcam-300 bg-white px-4 py-3 text-sm font-semibold text-fopcam-700 hover:bg-fopcam-100 transition"
                      >
                        Voir la boutique du vendeur
                      </Link>
                      <Link
                        href="/"
                        className="inline-flex items-center justify-center rounded-2xl border border-future-200 bg-future-100 px-4 py-3 text-sm font-semibold text-fopcam-700 hover:bg-future-200 transition"
                      >
                        Accueil
                      </Link>
                    </div>
                  </div>
                )}
              </div>

              <button
                onClick={addToCart}
                className="w-full rounded-2xl bg-fopcam-600 px-6 py-4 text-white font-semibold hover:bg-fopcam-700 transition"
              >
                {user ? 'Ajouter au panier' : 'Se connecter pour commander'}
              </button>

              {!user && (
                <p className="text-center text-sm text-future-500">
                  Vous devez être connecté pour passer commande
                </p>
              )}
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}
