import { useEffect, useState } from 'react'
import Link from 'next/link'
import { useRouter } from 'next/router'
import { ShoppingBagIcon } from '@heroicons/react/24/outline'

export default function ProductsPage() {
  const router = useRouter()
  const [products, setProducts] = useState([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    fetch(process.env.NEXT_PUBLIC_API_URL + '/api/products/')
      .then(r => r.json())
      .then(data => {
        if (Array.isArray(data)) setProducts(data)
        else if (data && data.results) setProducts(data.results)
      })
      .catch(err => console.error(err))
      .finally(() => setLoading(false))
  }, [])

  return (
    <div className="min-h-screen bg-gradient-to-br from-future-50 via-white to-fopcam-50 py-12">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="mb-10 flex flex-col gap-4 md:flex-row md:items-end md:justify-between">
          <div>
            <p className="text-sm uppercase tracking-[0.35em] text-fopcam-500 mb-2">Catalogue</p>
            <h1 className="text-4xl md:text-5xl font-black text-future-900">Tous les produits</h1>
            <p className="mt-3 text-future-600 max-w-2xl">Explorez l'ensemble des produits disponibles sur FopCam. Filtrez, comparez et trouvez rapidement ce dont vous avez besoin.</p>
          </div>
          <Link href="/" className="inline-flex items-center rounded-3xl border border-fopcam-400/20 bg-white/90 px-5 py-3 text-sm font-semibold text-future-900 shadow-sm transition hover:bg-fopcam-50">
            Retour à l’accueil
          </Link>
        </div>

        <div className="grid gap-6 md:grid-cols-2 xl:grid-cols-3">
          {loading ? (
            <div className="col-span-full rounded-3xl border border-white/10 bg-white/80 p-16 text-center text-future-600 shadow-sm">
              Chargement des produits...
            </div>
          ) : products.length === 0 ? (
            <div className="col-span-full rounded-3xl border border-white/10 bg-white/80 p-16 text-center text-future-600 shadow-sm">
              Aucun produit trouvé pour le moment.
            </div>
          ) : (
            products.map(product => (
              <div
                key={product.id}
                className="group block overflow-hidden rounded-[32px] border border-white/10 bg-white/90 shadow-lg transition hover:-translate-y-1 hover:shadow-fopcam-200/20"
              >
                <div
                  role="button"
                  onClick={() => router.push(`/products/${product.id}`)}
                  className="cursor-pointer"
                >
                  <div className="aspect-[4/3] bg-gradient-to-br from-fopcam-50 to-future-100 flex items-center justify-center">
                    <ShoppingBagIcon className="h-12 w-12 text-fopcam-500" />
                  </div>
                  <div className="p-6">
                    <p className="text-sm font-semibold uppercase tracking-[0.25em] text-fopcam-500 mb-3">{product.category?.name || 'Produit'}</p>
                    <h2 className="text-2xl font-bold text-future-900 mb-3">{product.title}</h2>
                    <p className="text-future-600 mb-5 line-clamp-2">{product.description || 'Description du produit...'}</p>
                    <div className="flex items-center justify-between gap-4 text-sm">
                      <span className="font-semibold text-fopcam-600">{product.price} FCFA</span>
                      <span className="rounded-full bg-fopcam-100 px-3 py-1 text-fopcam-700">{product.quantity} en stock</span>
                    </div>
                  </div>
                </div>

                <div className="p-4 border-t border-white/10 flex items-center justify-between">
                  <Link href={`/products/${product.id}?buy=1`} className="inline-flex items-center gap-2 rounded-full border border-fopcam-300 bg-white px-4 py-2 text-sm font-semibold text-fopcam-700 hover:bg-fopcam-100 transition">
                    Commander
                  </Link>
                  <button
                    onClick={() => {
                      // quick add to cart (localStorage)
                      const token = localStorage.getItem('access_token')
                      if (!token) {
                        router.push(`/login?next=/products/${product.id}`)
                        return
                      }
                      const cart = JSON.parse(localStorage.getItem('cart') || '[]')
                      cart.push({ product_id: product.id, title: product.title, price: product.price, qty: 1 })
                      localStorage.setItem('cart', JSON.stringify(cart))
                      alert('Produit ajouté au panier')
                    }}
                    className="inline-flex items-center justify-center p-2 rounded-full bg-fopcam-700 text-white hover:bg-fopcam-800 transition"
                  >
                    <ShoppingBagIcon className="w-5 h-5" />
                  </button>
                </div>
              </div>
            ))
          )}
        </div>
      </div>
    </div>
  )
}
