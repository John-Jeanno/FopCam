import { useEffect, useState } from 'react'
import { useRouter } from 'next/router'
import Link from 'next/link'
import {
  ArrowLeftIcon,
  MapPinIcon,
  PhoneIcon,
  EnvelopeIcon,
  ChatBubbleBottomCenterIcon,
  StarIcon,
  UserIcon,
} from '@heroicons/react/24/outline'
import { StarIcon as StarIconSolid } from '@heroicons/react/24/solid'
import ProductImageGallery from '../../components/ProductImageGallery'

export default function ProducerProfile() {
  const router = useRouter()
  const { id } = router.query
  const [producer, setProducer] = useState(null)
  const [products, setProducts] = useState([])
  const [loading, setLoading] = useState(true)
  const [user, setUser] = useState(null)
  const [reviews, setReviews] = useState([])
  const [showReviewForm, setShowReviewForm] = useState(false)
  const [reviewRating, setReviewRating] = useState(5)
  const [reviewComment, setReviewComment] = useState('')
  const [submittingReview, setSubmittingReview] = useState(false)
  const [userReview, setUserReview] = useState(null)
  const apiUrl = process.env.NEXT_PUBLIC_API_URL || 'http://127.0.0.1:8000'

  useEffect(() => {
    if (!id) return

    const loadData = async () => {
      try {
        // Load producer profile
        const profileRes = await fetch(`${apiUrl}/api/profiles/${id}/`)
        if (profileRes.ok) {
          const profileData = await profileRes.json()
          setProducer(profileData)

          // Load producer's products
          if (profileData.user?.id) {
            const productsRes = await fetch(`${apiUrl}/api/products/?shop__owner=${profileData.user.id}`)
            if (productsRes.ok) {
              const productsData = await productsRes.json()
              const prods = Array.isArray(productsData) ? productsData : productsData.results || []
              setProducts(prods)
            }

            // Load reviews for this producer
            const reviewsRes = await fetch(`${apiUrl}/api/producer-reviews/?producer_id=${profileData.user.id}`)
            if (reviewsRes.ok) {
              const reviewsData = await reviewsRes.json()
              const reviewsList = reviewsData.results || reviewsData
              setReviews(reviewsList)
            }
          }
        }

        // Load current user for authentication check
        const token = localStorage.getItem('access')
        if (token) {
          const userRes = await fetch(`${apiUrl}/api/auth/profile/`, {
            headers: { Authorization: `Bearer ${token}` }
          })
          if (userRes.ok) {
            const userData = await userRes.json()
            setUser(userData)

            // Check if user has already reviewed this producer
            if (producer?.user?.id) {
              const reviewsRes = await fetch(`${apiUrl}/api/producer-reviews/?producer_id=${producer.user.id}`)
              if (reviewsRes.ok) {
                const reviewsData = await reviewsRes.json()
                const reviewsList = reviewsData.results || reviewsData
                const existingReview = reviewsList.find(r => r.reviewer.id === userData.id)
                if (existingReview) {
                  setUserReview(existingReview)
                }
              }
            }
          }
        }
      } catch (err) {
        console.error('Error loading producer:', err)
      } finally {
        setLoading(false)
      }
    }

    loadData()
  }, [id])

  const buildMediaUrl = (path) => {
    if (!path) return null
    if (/^https?:\/\//.test(path)) return path
    if (path.startsWith('/media/')) return `${apiUrl}${path}`
    return `${apiUrl}/media/${path}`
  }

  const handleChat = () => {
    if (!user) {
      router.push('/login?next=' + router.asPath)
      return
    }
    router.push(`/chat/producer-${producer?.user?.username || id}`)
  }

  const renderStars = (rating) => {
    const stars = []
    const fullStars = Math.floor(rating || 0)
    const hasHalfStar = (rating || 0) % 1 !== 0

    for (let i = 0; i < 5; i++) {
      if (i < fullStars) {
        stars.push(<StarIconSolid key={i} className="w-4 h-4 text-yellow-400" />)
      } else if (i === fullStars && hasHalfStar) {
        stars.push(<StarIcon key={i} className="w-4 h-4 text-yellow-400" />)
      } else {
        stars.push(<StarIcon key={i} className="w-4 h-4 text-gray-300" />)
      }
    }
    return stars
  }

  const renderInteractiveStars = (currentRating, onRatingChange) => {
    const stars = []
    for (let i = 1; i <= 5; i++) {
      stars.push(
        <button
          key={i}
          type="button"
          onClick={() => onRatingChange(i)}
          className="focus:outline-none"
        >
          {i <= currentRating ? (
            <StarIconSolid className="w-6 h-6 text-yellow-400" />
          ) : (
            <StarIcon className="w-6 h-6 text-gray-300 hover:text-yellow-400" />
          )}
        </button>
      )
    }
    return stars
  }

  const submitReview = async () => {
    if (!user || !producer) return

    setSubmittingReview(true)
    try {
      const token = localStorage.getItem('access')
      const method = userReview ? 'PATCH' : 'POST'
      const url = userReview
        ? `${apiUrl}/api/producer-reviews/${userReview.id}/`
        : `${apiUrl}/api/producer-reviews/`

      const response = await fetch(url, {
        method,
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          producer_id: producer.user.id,
          rating: reviewRating * 2,
          comment: reviewComment.trim() || ''
        })
      })

      if (response.ok) {
        const updatedReview = await response.json()

        // Refresh reviews
        const reviewsRes = await fetch(`${apiUrl}/api/producer-reviews/?producer_id=${producer.user.id}`, {
          headers: {
            'Authorization': `Bearer ${token}`,
            'Content-Type': 'application/json',
          },
        })

        if (reviewsRes.ok) {
          const reviewsData = await reviewsRes.json()
          setReviews(reviewsData.results || reviewsData)
          setUserReview(updatedReview)
        }

        // Refresh producer profile to get updated rating
        const profileRes = await fetch(`${apiUrl}/api/profiles/${id}/`)
        if (profileRes.ok) {
          const profileData = await profileRes.json()
          setProducer(profileData)
        }

        setShowReviewForm(false)
        setReviewComment('')
        alert('Avis envoyé avec succès!')
      } else {
        const errorData = await response.json()
        alert('Erreur lors de l\'envoi de l\'avis: ' + (errorData.detail || 'Erreur inconnue'))
      }
    } catch (error) {
      console.error('Error submitting review:', error)
      alert('Erreur lors de l\'envoi de l\'avis')
    } finally {
      setSubmittingReview(false)
    }
  }

  if (loading) {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center">
        <div className="text-center">
          <p className="text-gray-600">Chargement...</p>
        </div>
      </div>
    )
  }

  if (!producer) {
    return (
      <div className="min-h-screen bg-gray-50">
        <div className="max-w-7xl mx-auto px-4 py-8">
          <Link href="/" className="flex items-center gap-2 text-fopcam-600 hover:text-fopcam-700 mb-8">
            <ArrowLeftIcon className="w-5 h-5" />
            Retour à l'accueil
          </Link>
          <div className="card p-8 text-center">
            <p className="text-gray-600">Vendeur non trouvé</p>
          </div>
        </div>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-future-50 via-white to-fopcam-50">
      {/* Header */}
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <Link href="/" className="flex items-center gap-2 text-fopcam-600 hover:text-fopcam-700 mb-8">
          <ArrowLeftIcon className="w-5 h-5" />
          Retour à l'accueil
        </Link>
      </div>

      {/* Profile Section */}
      <section className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
        <div className="card border border-fopcam-100 overflow-hidden">
          {/* Cover Image */}
          <div className="h-48 bg-gradient-to-r from-fopcam-400 to-fopcam-600"></div>

          {/* Profile Content */}
          <div className="px-8 py-8">
            <div className="flex flex-col sm:flex-row sm:items-end sm:gap-6 mb-8">
              {/* Profile Image */}
              <div className="flex-shrink-0 -mt-32 mb-4 sm:mb-0">
                {producer.profile_image ? (
                  <img
                    src={buildMediaUrl(producer.profile_image)}
                    alt={producer.user?.username}
                    className="h-32 w-32 rounded-2xl object-cover border-4 border-white shadow-lg"
                  />
                ) : (
                  <div className="h-32 w-32 rounded-2xl bg-fopcam-100 flex items-center justify-center border-4 border-white shadow-lg">
                    <div className="text-3xl font-bold text-fopcam-600">
                      {producer.user?.first_name?.charAt(0) || producer.user?.username?.charAt(0) || 'P'}
                    </div>
                  </div>
                )}
              </div>

              {/* Profile Info */}
              <div className="flex-1">
                <h1 className="text-3xl font-bold text-future-900 mb-2">
                  {producer.user?.first_name ? `${producer.user.first_name} ${producer.user.last_name}` : producer.user?.username}
                </h1>
                <p className="text-lg text-fopcam-600 font-semibold mb-2">Vendeur Vérifié</p>

                {/* Rating */}
                {producer.average_rating && (
                  <div className="flex flex-wrap items-center gap-2 mb-4">
                    <div className="flex">
                      {renderStars(Math.round(producer.average_rating / 2))}
                    </div>
                    <span className="text-sm font-semibold text-fopcam-600">
                      {Math.round(producer.average_rating / 2)}/5
                    </span>
                    <span className="text-sm text-gray-600">
                      {Math.round(producer.average_rating)}/10
                    </span>
                    {producer.review_count > 0 && (
                      <span className="text-sm text-gray-600">
                        ({producer.review_count} avis)
                      </span>
                    )}
                  </div>
                )}

                {/* Location */}
                {producer.city && (
                  <div className="flex items-center gap-2 text-future-600 mb-4">
                    <MapPinIcon className="w-5 h-5" />
                    <span>{producer.city}</span>
                    {producer.country && <span>, {producer.country}</span>}
                  </div>
                )}
              </div>

              {/* Action Button */}
              <button
                onClick={handleChat}
                className="btn-primary flex items-center gap-2 px-8 py-3"
              >
                <ChatBubbleBottomCenterIcon className="w-5 h-5" />
                Envoyer un message
              </button>
            </div>

            {/* Contact Information */}
            <div className="grid md:grid-cols-3 gap-6 py-8 border-t border-future-100">
              {producer.phone && (
                <div>
                  <div className="flex items-center gap-2 text-future-600 mb-2">
                    <PhoneIcon className="w-5 h-5" />
                    <p className="font-semibold">Téléphone</p>
                  </div>
                  <p className="text-future-900">{producer.phone}</p>
                </div>
              )}

              {producer.user?.email && (
                <div>
                  <div className="flex items-center gap-2 text-future-600 mb-2">
                    <EnvelopeIcon className="w-5 h-5" />
                    <p className="font-semibold">Email</p>
                  </div>
                  <p className="text-future-900 break-all">{producer.user.email}</p>
                </div>
              )}

              {producer.address && (
                <div>
                  <div className="flex items-center gap-2 text-future-600 mb-2">
                    <MapPinIcon className="w-5 h-5" />
                    <p className="font-semibold">Adresse</p>
                  </div>
                  <p className="text-future-900">{producer.address}</p>
                </div>
              )}
            </div>
          </div>
        </div>
      </section>

      {/* Reviews Section */}
      <section className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
        <div className="card border border-fopcam-100 overflow-hidden">
          <div className="p-8">
            <div className="flex items-center justify-between mb-8">
              <div>
                <h2 className="text-3xl font-bold text-future-900">Avis des clients</h2>
                {producer?.average_rating && (
                  <div className="flex items-center gap-3 mt-2">
                    <div className="flex">
                      {renderStars(Math.round(producer.average_rating / 2))} {/* Convert 0-10 to 0-5 */}
                    </div>
                    <span className="text-lg font-semibold text-fopcam-600">
                      {Math.round(producer.average_rating / 2)}/5
                    </span>
                    {producer.review_count > 0 && (
                      <span className="text-gray-600">
                        ({producer.review_count} avis)
                      </span>
                    )}
                  </div>
                )}
              </div>
              {user && user.id !== producer?.user?.id && (
                <button
                  onClick={() => {
                    if (reviews.length > 0) {
                      const existing = reviews.find(r => r.reviewer.id === user.id)
                      if (existing) {
                        setUserReview(existing)
                        setReviewRating(existing.rating / 2) // Convert 0-10 to 0-5
                        setReviewComment(existing.comment || '')
                      }
                    }
                    setShowReviewForm(!showReviewForm)
                  }}
                  className="px-6 py-2 bg-fopcam-500 text-white rounded-lg hover:bg-fopcam-600 transition-colors"
                >
                  {userReview ? 'Modifier mon avis' : 'Laisser un avis'}
                </button>
              )}
            </div>

            {/* Review Form */}
            {showReviewForm && (
              <div className="mb-8 p-6 bg-gray-50 rounded-lg">
                <h3 className="text-lg font-semibold mb-4">
                  {userReview ? 'Modifier votre avis' : 'Laisser un avis'}
                </h3>
                <div className="space-y-4">
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-2">
                      Note (sur 5 étoiles)
                    </label>
                    <div className="flex gap-1">
                      {renderInteractiveStars(reviewRating, setReviewRating)}
                    </div>
                  </div>
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-2">
                      Commentaire (optionnel)
                    </label>
                    <textarea
                      value={reviewComment}
                      onChange={(e) => setReviewComment(e.target.value)}
                      placeholder="Partagez votre expérience avec ce vendeur..."
                      className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-fopcam-500 focus:border-transparent"
                      rows={3}
                    />
                  </div>
                  <div className="flex gap-3">
                    <button
                      onClick={submitReview}
                      disabled={submittingReview}
                      className="px-6 py-2 bg-fopcam-500 text-white rounded-lg hover:bg-fopcam-600 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
                    >
                      {submittingReview ? 'Envoi...' : (userReview ? 'Modifier' : 'Publier')}
                    </button>
                    <button
                      onClick={() => setShowReviewForm(false)}
                      className="px-6 py-2 bg-gray-300 text-gray-700 rounded-lg hover:bg-gray-400 transition-colors"
                    >
                      Annuler
                    </button>
                  </div>
                </div>
              </div>
            )}

            {/* Reviews List */}
            {reviews.length > 0 ? (
              <div className="space-y-4">
                {reviews.map((review) => (
                  <div key={review.id} className="border-b border-gray-200 pb-4 last:border-b-0">
                    <div className="flex items-start justify-between">
                      <div className="flex items-center gap-3">
                        {review.reviewer.profile_image ? (
                          <img
                            src={buildMediaUrl(review.reviewer.profile_image)}
                            alt={review.reviewer.username}
                            className="w-10 h-10 rounded-full object-cover"
                          />
                        ) : (
                          <div className="w-10 h-10 rounded-full bg-gray-300 flex items-center justify-center">
                            <UserIcon className="w-5 h-5 text-gray-600" />
                          </div>
                        )}
                        <div>
                          <p className="font-medium text-gray-900">
                            {review.reviewer.first_name} {review.reviewer.last_name}
                          </p>
                          <p className="text-sm text-gray-500">
                            @{review.reviewer.username}
                          </p>
                        </div>
                      </div>
                      <div className="flex items-center gap-2 flex-col sm:flex-row">
                        <div className="flex">
                          {renderStars(review.rating / 2)} {/* Convert 0-10 to 0-5 */}
                        </div>
                        <span className="text-sm text-gray-500">
                          {new Date(review.created_at).toLocaleDateString('fr-FR')}
                        </span>
                      </div>
                    </div>
                    {review.comment && (
                      <p className="mt-3 text-gray-700">{review.comment}</p>
                    )}
                  </div>
                ))}
              </div>
            ) : (
              <div className="text-center py-8 text-gray-500">
                <StarIcon className="w-12 h-12 mx-auto mb-4 text-gray-300" />
                <p>Aucun avis pour le moment.</p>
                {user && user.id !== producer?.user?.id && (
                  <p className="text-sm mt-2">Soyez le premier à laisser un avis !</p>
                )}
              </div>
            )}
          </div>
        </div>
      </section>

      {/* Products Section */}
      {products.length > 0 && (
        <section className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
          <div className="text-center mb-12">
            <h2 className="text-3xl font-bold text-future-900 mb-2">
              Produits de {producer.user?.first_name ? producer.user.first_name : producer.user?.username}
            </h2>
            <p className="text-lg text-future-600">
              Découvrez tous les produits disponibles
            </p>
          </div>

          <div className="grid grid-cols-1 gap-4 min-[380px]:grid-cols-2 sm:gap-6 lg:grid-cols-3 2xl:grid-cols-4">
            {products.map((product) => (
              <div key={product.id} className="card group hover:shadow-lg transition-shadow">
                <ProductImageGallery product={product} resolveMediaUrl={buildMediaUrl} />
                <div>
                  <div className="p-6">
                    <h3 className="text-lg font-semibold text-future-900 mb-2 group-hover:text-fopcam-600 transition-colors">
                      <Link href={`/products/${product.id}`} className="break-words">
                        {product.title}
                      </Link>
                    </h3>
                    <p className="text-future-600 text-sm mb-4 overflow-hidden" style={{display: '-webkit-box', WebkitLineClamp: 2, WebkitBoxOrient: 'vertical'}}>
                      {product.description}
                    </p>
                    <div className="flex flex-wrap items-center justify-between gap-2">
                      <span className="break-words text-xl font-bold text-fopcam-600">
                        {product.price} FCFA
                      </span>
                      <span className="text-sm text-future-500">
                        {product.quantity > 0 ? `${product.quantity} en stock` : 'Rupture'}
                      </span>
                    </div>
                  </div>
                </div>

                <div className="flex flex-col items-stretch gap-2 border-t border-future-100 p-4 sm:flex-row sm:items-center">
                  <button
                    onClick={() => {
                      if (!user) {
                        router.push(`/login?next=${encodeURIComponent(router.asPath)}`)
                        return
                      }
                      // add to cart
                      const cart = JSON.parse(localStorage.getItem('cart') || '[]')
                      cart.push({ product_id: product.id, title: product.title, price: product.price, qty: 1 })
                      localStorage.setItem('cart', JSON.stringify(cart))
                      alert('Produit ajouté au panier')
                    }}
                    className="flex-1 inline-flex items-center justify-center rounded-full bg-fopcam-700 px-4 py-2 text-white font-semibold hover:bg-fopcam-800 transition"
                  >
                    Ajouter au panier
                  </button>
                  <button
                    onClick={() => {
                      if (!user) {
                        router.push(`/login?next=${encodeURIComponent(router.asPath)}`)
                        return
                      }
                      router.push(`/checkout?product=${product.id}`)
                    }}
                    className="inline-flex items-center justify-center gap-2 rounded-full border border-fopcam-300 bg-white px-4 py-2 text-sm font-semibold text-fopcam-700 transition hover:bg-fopcam-100"
                  >
                    Commander
                  </button>
                </div>
              </div>
            ))}
          </div>
        </section>
      )}

      {/* No Products Message */}
      {products.length === 0 && !loading && (
        <section className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
          <div className="card p-12 text-center">
            <p className="text-xl text-future-600 mb-4">
              Aucun produit disponible pour le moment
            </p>
            <p className="text-future-500">
              Revenez bientôt pour découvrir les produits de ce vendeur
            </p>
          </div>
        </section>
      )}

      {/* Footer CTA */}
      <section className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
        <div className="card bg-gradient-to-r from-fopcam-500 to-fopcam-600 text-white p-12 text-center">
          <h2 className="text-2xl font-bold mb-4">Découvrez plus de vendeurs</h2>
          <p className="text-fopcam-100 mb-8">
            Explorez notre communauté de vendeurs locaux et trouvez vos produits préférés
          </p>
          <Link href="/" className="inline-block btn-white px-8 py-3">
            Retour à l'accueil
          </Link>
        </div>
      </section>
    </div>
  )
}
