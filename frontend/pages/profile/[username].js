import { useState, useEffect } from 'react'
import { useRouter } from 'next/router'
import Link from 'next/link'
import {
  ArrowLeftIcon,
  MapPinIcon,
  PhoneIcon,
  GlobeAltIcon,
  StarIcon,
  ShoppingBagIcon,
  UserIcon,
  PencilIcon,
  CameraIcon,
  HomeIcon
} from '@heroicons/react/24/outline'
import { StarIcon as StarIconSolid } from '@heroicons/react/24/solid'

const apiUrl = process.env.NEXT_PUBLIC_API_URL || 'http://127.0.0.1:8000'

function ProfilePage() {
  const router = useRouter()
  const { username } = router.query
  const [profile, setProfile] = useState(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [reviews, setReviews] = useState([])
  const [showReviewForm, setShowReviewForm] = useState(false)
  const [reviewRating, setReviewRating] = useState(5)
  const [reviewComment, setReviewComment] = useState('')
  const [submittingReview, setSubmittingReview] = useState(false)
  const [userReview, setUserReview] = useState(null)
  const [currentUser, setCurrentUser] = useState(null)
  const [isOwnProfile, setIsOwnProfile] = useState(false)
  const [showProfileImage, setShowProfileImage] = useState(false)

  useEffect(() => {
    const token = localStorage.getItem('access_token') || localStorage.getItem('access')
    
    const fetchProfile = async () => {
      try {
        // Fetch current user info if logged in
        let userData = null
        if (token) {
          try {
            const userRes = await fetch(`${apiUrl}/api/auth/profile/`, {
              headers: {
                'Authorization': `Bearer ${token}`,
                'Content-Type': 'application/json',
              },
            })

            if (userRes.ok) {
              const userProfileData = await userRes.json()
              userData = userProfileData
              setCurrentUser(userProfileData)
              const currentUsername = userProfileData?.user?.username || userProfileData?.username
              setIsOwnProfile(currentUsername === username)
            }
          } catch (userErr) {
            console.warn('Could not fetch current user:', userErr)
          }
        }

        // Fetch profile data - no auth required
        const profileRes = await fetch(`${apiUrl}/api/profiles/${username}/`, {
          headers: token ? { 'Authorization': `Bearer ${token}` } : {}
        })

        if (profileRes.ok) {
          const profileData = await profileRes.json()
          setProfile(profileData)

          const canReceiveReviews = profileData.role === 'producer' || !!profileData.shop_id
          if (canReceiveReviews) {
            try {
              const reviewsRes = await fetch(`${apiUrl}/api/producer-reviews/?producer_id=${profileData.user.id}`, {
                headers: token ? { 'Authorization': `Bearer ${token}` } : {}
              })

              if (reviewsRes.ok) {
                const reviewsData = await reviewsRes.json()
                setReviews(reviewsData.results || reviewsData)

                // Check if current user has already reviewed this producer
                if (userData) {
                  const existingReview = reviewsData.results?.find(review => review.reviewer.id === userData.id) ||
                                       reviewsData.find(review => review.reviewer.id === userData.id)
                  setUserReview(existingReview || null)
                }
              }
            } catch (reviewErr) {
              console.warn('Could not fetch reviews:', reviewErr)
            }
          }
        } else {
          setError('Profil non trouvé')
        }
      } catch (err) {
        console.error('Error fetching profile:', err)
        setError('Erreur lors du chargement du profil')
      } finally {
        setLoading(false)
      }
    }

    if (username) {
      fetchProfile()
    }
  }, [username, router])

  const buildMediaUrl = (path) => {
    if (!path) return null
    if (path.startsWith('http')) return path
    return `${apiUrl}${path.startsWith('/') ? path : `/${path}`}`
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
    if (!currentUser || !profile) return

    setSubmittingReview(true)
    try {
      const token = localStorage.getItem('access_token')
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
          producer_id: profile.user.id,
          rating: reviewRating * 2,
          comment: reviewComment.trim() || ''
        })
      })

      if (response.ok) {
        const updatedReview = await response.json()

        // Refresh reviews
        const reviewsRes = await fetch(`${apiUrl}/api/producer-reviews/?producer_id=${profile.user.id}`, {
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

        // Refresh profile to get updated average rating
        const profileRes = await fetch(`${apiUrl}/api/profiles/${username}/`, {
          headers: {
            'Authorization': `Bearer ${token}`,
            'Content-Type': 'application/json',
          },
        })

        if (profileRes.ok) {
          const profileData = await profileRes.json()
          setProfile(profileData)
        }

        setShowReviewForm(false)
        setReviewComment('')
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
      <div className="min-h-screen bg-gradient-to-br from-fopcam-50 to-blue-50 flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin rounded-full h-16 w-16 border-4 border-fopcam-500 border-t-transparent mx-auto mb-4"></div>
          <p className="text-gray-600 font-medium">Chargement du profil...</p>
        </div>
      </div>
    )
  }

  if (error || !profile) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-fopcam-50 to-blue-50 flex items-center justify-center">
        <div className="text-center bg-white rounded-xl shadow-lg p-8 max-w-md">
          <div className="text-red-500 mb-4">
            <svg className="w-16 h-16 mx-auto" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L3.732 16.5c-.77.833.192 2.5 1.732 2.5z" />
            </svg>
          </div>
          <h3 className="text-xl font-semibold text-gray-900 mb-2">Erreur</h3>
          <p className="text-gray-600 mb-6">{error || 'Profil non trouvé'}</p>
          <Link href="/" className="inline-flex items-center px-4 py-2 bg-fopcam-500 text-white rounded-lg hover:bg-fopcam-600 transition-colors">
            <ArrowLeftIcon className="w-4 h-4 mr-2" />
            Retour à l'accueil
          </Link>
        </div>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-fopcam-50 via-blue-50 to-green-50">
      <div className="max-w-4xl mx-auto px-4 py-6">
        {/* Header */}
        <div className="mb-6">
          <div className="flex items-center justify-between">
            <div className="flex items-center space-x-4">
              <Link href="/" className="inline-flex items-center text-gray-600 hover:text-fopcam-600 transition-colors">
                <ArrowLeftIcon className="w-5 h-5 mr-2" />
                Retour à l'accueil
              </Link>
              {isOwnProfile && (
                <Link href="/client/dashboard" className="inline-flex items-center text-gray-600 hover:text-fopcam-600 transition-colors">
                  <HomeIcon className="w-5 h-5 mr-2" />
                  Mon Dashboard
                </Link>
              )}
            </div>
            {isOwnProfile && (
              <Link
                href="/profile/edit"
                className="inline-flex items-center px-4 py-2 bg-fopcam-500 text-white rounded-lg hover:bg-fopcam-600 transition-colors"
              >
                <PencilIcon className="w-4 h-4 mr-2" />
                Modifier le profil
              </Link>
            )}
          </div>
        </div>

        {/* Cover Image */}
        <div className="bg-white rounded-2xl shadow-xl overflow-hidden mb-6">
          <div className="relative h-64 bg-gradient-to-r from-fopcam-400 to-fopcam-600">
            {profile.cover_image ? (
              <img
                src={buildMediaUrl(profile.cover_image)}
                alt="Photo de couverture"
                className="w-full h-full object-cover"
              />
            ) : (
              <div className="w-full h-full bg-gradient-to-r from-fopcam-400 to-fopcam-600 flex items-center justify-center">
                <CameraIcon className="w-16 h-16 text-white/50" />
              </div>
            )}
            {isOwnProfile && (
              <Link
                href="/profile/edit"
                className="absolute top-4 right-4 bg-white/20 backdrop-blur-sm text-white px-3 py-2 rounded-lg hover:bg-white/30 transition-colors"
              >
                <CameraIcon className="w-4 h-4 inline mr-2" />
                Modifier
              </Link>
            )}
          </div>

          {/* Profile Info */}
          <div className="relative px-6 pb-6">
            <div className="flex items-end -mt-16 mb-4">
              <div className="relative">
                {profile.profile_image ? (
                  <button
                    type="button"
                    onClick={() => setShowProfileImage(true)}
                    className="block w-32 h-32 rounded-full border-4 border-white shadow-lg overflow-hidden transition-transform hover:-translate-y-0.5 focus:outline-none focus:ring-2 focus:ring-fopcam-500"
                    aria-label="Voir la photo de profil"
                  >
                    <img
                      src={buildMediaUrl(profile.profile_image)}
                      alt={profile.user.username}
                      className="w-full h-full object-cover"
                    />
                  </button>
                ) : (
                  <div className="w-32 h-32 rounded-full bg-gradient-to-br from-fopcam-400 to-fopcam-600 border-4 border-white shadow-lg flex items-center justify-center">
                    <UserIcon className="w-16 h-16 text-white" />
                  </div>
                )}
                {isOwnProfile && (
                  <Link
                    href="/profile/edit"
                    className="absolute bottom-2 right-2 bg-fopcam-500 text-white p-2 rounded-full hover:bg-fopcam-600 transition-colors"
                  >
                    <CameraIcon className="w-4 h-4" />
                  </Link>
                )}
              </div>
              {showProfileImage && profile.profile_image && (
                <div
                  className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4"
                  role="dialog"
                  aria-modal="true"
                  aria-label="Photo de profil"
                  onClick={() => setShowProfileImage(false)}
                >
                  <div
                    className="relative max-w-3xl w-full rounded-3xl overflow-hidden bg-white shadow-2xl"
                    onClick={(event) => event.stopPropagation()}
                  >
                    <button
                      type="button"
                      onClick={() => setShowProfileImage(false)}
                      className="absolute right-4 top-4 rounded-full bg-white/90 p-2 text-gray-900 shadow-md hover:bg-white"
                      aria-label="Fermer"
                    >
                      ✕
                    </button>
                    <img
                      src={buildMediaUrl(profile.profile_image)}
                      alt={`${profile.user.username} photo de profil`}
                      className="w-full h-full max-h-[85vh] object-contain bg-black"
                    />
                  </div>
                </div>
              )}
              <div className="ml-6 flex-1">
                <h1 className="text-3xl font-bold text-gray-900">
                  {profile.user.first_name} {profile.user.last_name}
                </h1>
                <p className="text-gray-600">@{profile.user.username}</p>
                <div className="flex items-center gap-4 mt-2">
                  <span className={`px-3 py-1 rounded-full text-sm font-medium ${
                    profile.role === 'producer' || !!profile.shop_id
                      ? 'bg-green-100 text-green-800'
                      : profile.role === 'driver'
                        ? 'bg-yellow-100 text-yellow-800'
                        : 'bg-blue-100 text-blue-800'
                  }`}>
                    {profile.role === 'producer' || !!profile.shop_id ? 'Vendeur' : profile.role === 'driver' ? 'Livreur' : 'Visiteur'}
                  </span>
                  {profile.verified && (
                    <span className="flex items-center text-green-600">
                      <svg className="w-4 h-4 mr-1" fill="currentColor" viewBox="0 0 20 20">
                        <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clipRule="evenodd" />
                      </svg>
                      Vérifié
                    </span>
                  )}
                </div>
              </div>
            </div>

            {/* Bio */}
            {profile.bio && (
              <div className="mb-6">
                <p className="text-gray-700 leading-relaxed">{profile.bio}</p>
              </div>
            )}

            {/* Contact Info */}
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mb-6">
              {profile.phone && (
                <div className="flex items-center text-gray-600">
                  <PhoneIcon className="w-5 h-5 mr-3 text-gray-400" />
                  {profile.phone}
                </div>
              )}
              {(profile.city || profile.country) && (
                <div className="flex items-center text-gray-600">
                  <MapPinIcon className="w-5 h-5 mr-3 text-gray-400" />
                  {[profile.city, profile.country].filter(Boolean).join(', ')}
                </div>
              )}
              {profile.website && (
                <div className="flex items-center text-gray-600">
                  <GlobeAltIcon className="w-5 h-5 mr-3 text-gray-400" />
                  <a
                    href={profile.website}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="text-fopcam-600 hover:text-fopcam-700"
                  >
                    {profile.website}
                  </a>
                </div>
              )}
            </div>

            {/* Stats */}
            <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-6">
              {(profile.role === 'producer' || !!profile.shop_id) && profile.average_rating && (
                <div className="text-center">
                  <div className="flex items-center justify-center mb-1">
                    {renderStars(Math.round(profile.average_rating / 2))}
                  </div>
                  <p className="text-sm text-gray-600">Note moyenne</p>
                  <p className="font-semibold text-gray-900">{Math.round(profile.average_rating / 2)}/5</p>
                  <p className="text-sm text-gray-500">{Math.round(profile.average_rating)}/10</p>
                </div>
              )}
              {(profile.role === 'producer' || !!profile.shop_id) && profile.review_count !== undefined && (
                <div className="text-center">
                  <div className="text-2xl font-bold text-fopcam-600 mb-1">
                    {profile.review_count}
                  </div>
                  <p className="text-sm text-gray-600">Avis</p>
                </div>
              )}
              {profile.shop_name && (
                <div className="text-center col-span-2">
                  <div className="flex items-center justify-center mb-2">
                    <ShoppingBagIcon className="w-5 h-5 text-fopcam-600 mr-2" />
                    <span className="font-medium text-gray-900">{profile.shop_name}</span>
                  </div>
                  <Link
                    href={`/shop/${profile.shop_id}`}
                    className="text-sm text-fopcam-600 hover:text-fopcam-700"
                  >
                    Voir la boutique →
                  </Link>
                </div>
              )}
            </div>
          </div>
        </div>

        {/* Reviews Section - Producers and shop owners */}
        {(profile.role === 'producer' || !!profile.shop_id) && (
          <div className="bg-white rounded-2xl shadow-xl p-6 mb-6">
            <div className="flex items-center justify-between mb-6">
              <h2 className="text-2xl font-bold text-gray-900">Avis des clients</h2>
              {!isOwnProfile && (
                currentUser ? (
                  <button
                    onClick={() => {
                      if (userReview) {
                        setReviewRating(Math.round(userReview.rating / 2))
                        setReviewComment(userReview.comment || '')
                      } else {
                        setReviewRating(5)
                        setReviewComment('')
                      }
                      setShowReviewForm(true)
                    }}
                    className="px-4 py-2 bg-fopcam-500 text-white rounded-lg hover:bg-fopcam-600 transition-colors"
                  >
                    {userReview ? 'Modifier mon avis' : 'Laisser un avis'}
                  </button>
                ) : (
                  <Link
                    href="/login"
                    className="px-4 py-2 bg-fopcam-500 text-white rounded-lg hover:bg-fopcam-600 transition-colors inline-block"
                  >
                    Se connecter pour laisser un avis
                  </Link>
                )
              )}
            </div>

            {/* Review Form */}
            {showReviewForm && (
              <div className="mb-6 p-4 bg-gray-50 rounded-lg">
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
                      className="px-4 py-2 bg-fopcam-500 text-white rounded-lg hover:bg-fopcam-600 disabled:opacity-50 disabled:cursor-not-allowed"
                    >
                      {submittingReview ? 'Envoi...' : (userReview ? 'Modifier' : 'Publier')}
                    </button>
                    <button
                      onClick={() => setShowReviewForm(false)}
                      className="px-4 py-2 bg-gray-300 text-gray-700 rounded-lg hover:bg-gray-400"
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
                      <div className="flex items-center gap-2">
                        <div className="flex">
                          {renderStars(review.rating)}
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
                {!isOwnProfile && currentUser && (
                  <p className="text-sm mt-2">Soyez le premier à laisser un avis !</p>
                )}
              </div>
            )}
          </div>
        )}
      </div>
    </div>
  )
}

export default ProfilePage