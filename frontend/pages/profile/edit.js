import { useState, useEffect, useRef } from 'react'
import { useRouter } from 'next/router'
import Link from 'next/link'
import {
  ArrowLeftIcon,
  CameraIcon,
  UserIcon,
  PencilIcon,
  XMarkIcon,
  HomeIcon
} from '@heroicons/react/24/outline'

const apiUrl = process.env.NEXT_PUBLIC_API_URL || 'http://127.0.0.1:8000'

function EditProfilePage() {
  const router = useRouter()
  const [profile, setProfile] = useState(null)
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState(null)
  const [success, setSuccess] = useState(false)
  const [formData, setFormData] = useState({
    first_name: '',
    last_name: '',
    phone: '',
    address: '',
    city: '',
    country: '',
    bio: '',
    website: '',
  })

  const profileImageRef = useRef(null)
  const coverImageRef = useRef(null)

  useEffect(() => {
    const token = localStorage.getItem('access_token') || localStorage.getItem('access')
    if (!token) {
      router.push('/login')
      return
    }

    const fetchProfile = async () => {
      try {
        const res = await fetch(`${apiUrl}/api/auth/profile/`, {
          headers: {
            'Authorization': `Bearer ${token}`,
            'Content-Type': 'application/json',
          },
        })

        if (res.ok) {
          const profileData = await res.json()
          setProfile(profileData)
          setFormData({
            first_name: profileData.user.first_name || '',
            last_name: profileData.user.last_name || '',
            phone: profileData.phone || '',
            address: profileData.address || '',
            city: profileData.city || '',
            country: profileData.country || '',
            bio: profileData.bio || '',
            website: profileData.website || '',
          })
        } else {
          setError('Erreur lors du chargement du profil')
        }
      } catch (err) {
        console.error('Error fetching profile:', err)
        setError('Erreur lors du chargement du profil')
      } finally {
        setLoading(false)
      }
    }

    fetchProfile()
  }, [router])

  const handleInputChange = (e) => {
    const { name, value } = e.target
    setFormData(prev => ({
      ...prev,
      [name]: value
    }))
  }

  const handleImageChange = (e, type) => {
    const file = e.target.files[0]
    if (file) {
      setProfile(prev => ({
        ...prev,
        [type]: file
      }))
    }
  }

  const removeImage = (type) => {
    setProfile(prev => ({
      ...prev,
      [type]: null
    }))
  }

  const handleSubmit = async (e) => {
    e.preventDefault()
    setSaving(true)
    setError(null)
    setSuccess(false)

    const token = localStorage.getItem('access_token') || localStorage.getItem('access')

    try {
      const submitData = new FormData()

      // Add form data
      Object.keys(formData).forEach(key => {
        if (formData[key]) {
          submitData.append(key, formData[key])
        }
      })

      // Add images if they exist
      if (profile.profile_image instanceof File) {
        submitData.append('profile_image', profile.profile_image)
      }
      if (profile.cover_image instanceof File) {
        submitData.append('cover_image', profile.cover_image)
      }

      const res = await fetch(`${apiUrl}/api/auth/profile/`, {
        method: 'PATCH',
        headers: {
          'Authorization': `Bearer ${token}`,
        },
        body: submitData
      })

      if (res.ok) {
        const updatedProfile = await res.json()
        setProfile(updatedProfile)
        setSuccess(true)
        setTimeout(() => {
          router.push(`/profile/${updatedProfile.user.username}`)
        }, 2000)
      } else {
        const errorData = await res.json()
        setError(errorData.detail || 'Erreur lors de la sauvegarde')
      }
    } catch (err) {
      console.error('Error updating profile:', err)
      setError('Erreur lors de la sauvegarde du profil')
    } finally {
      setSaving(false)
    }
  }

  const buildMediaUrl = (path) => {
    if (!path) return null
    if (path.startsWith('http')) return path
    return `${apiUrl}${path.startsWith('/') ? path : `/${path}`}`
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

  if (error && !profile) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-fopcam-50 to-blue-50 flex items-center justify-center">
        <div className="text-center bg-white rounded-xl shadow-lg p-8 max-w-md">
          <div className="text-red-500 mb-4">
            <svg className="w-16 h-16 mx-auto" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L3.732 16.5c-.77.833.192 2.5 1.732 2.5z" />
            </svg>
          </div>
          <h3 className="text-xl font-semibold text-gray-900 mb-2">Erreur</h3>
          <p className="text-gray-600 mb-6">{error}</p>
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
              <Link href={`/profile/${profile?.user?.username}`} className="inline-flex items-center text-gray-600 hover:text-fopcam-600 transition-colors">
                <ArrowLeftIcon className="w-5 h-5 mr-2" />
                Retour au profil
              </Link>
              <Link href="/client/dashboard" className="inline-flex items-center text-gray-600 hover:text-fopcam-600 transition-colors">
                <HomeIcon className="w-5 h-5 mr-2" />
                Mon Dashboard
              </Link>
            </div>
            <h1 className="text-3xl font-bold text-gray-900">Modifier le profil</h1>
          </div>
        </div>

        <form onSubmit={handleSubmit} className="space-y-6">
          {/* Cover Image */}
          <div className="bg-white rounded-2xl shadow-xl overflow-hidden">
            <div className="relative h-48 bg-gradient-to-r from-fopcam-400 to-fopcam-600">
              {profile?.cover_image && (
                <img
                  src={profile.cover_image instanceof File ? URL.createObjectURL(profile.cover_image) : buildMediaUrl(profile.cover_image)}
                  alt="Photo de couverture"
                  className="w-full h-full object-cover"
                />
              )}
              <div className="absolute inset-0 bg-black/20 flex items-center justify-center">
                <div className="text-center">
                  <input
                    ref={coverImageRef}
                    type="file"
                    accept="image/*"
                    onChange={(e) => handleImageChange(e, 'cover_image')}
                    className="hidden"
                  />
                  <button
                    type="button"
                    onClick={() => coverImageRef.current?.click()}
                    className="bg-white/20 backdrop-blur-sm text-white px-4 py-2 rounded-lg hover:bg-white/30 transition-colors inline-flex items-center"
                  >
                    <CameraIcon className="w-5 h-5 mr-2" />
                    {profile?.cover_image ? 'Changer la photo de couverture' : 'Ajouter une photo de couverture'}
                  </button>
                  {profile?.cover_image && (
                    <button
                      type="button"
                      onClick={() => removeImage('cover_image')}
                      className="ml-2 bg-red-500/20 backdrop-blur-sm text-white px-3 py-2 rounded-lg hover:bg-red-500/30 transition-colors"
                    >
                      <XMarkIcon className="w-4 h-4" />
                    </button>
                  )}
                </div>
              </div>
            </div>
          </div>

          {/* Profile Image */}
          <div className="bg-white rounded-2xl shadow-xl p-6">
            <div className="flex items-center gap-6">
              <div className="relative">
                {profile?.profile_image ? (
                  <img
                    src={profile.profile_image instanceof File ? URL.createObjectURL(profile.profile_image) : buildMediaUrl(profile.profile_image)}
                    alt="Photo de profil"
                    className="w-24 h-24 rounded-full object-cover border-4 border-gray-100"
                  />
                ) : (
                  <div className="w-24 h-24 rounded-full bg-gradient-to-br from-fopcam-400 to-fopcam-600 border-4 border-gray-100 flex items-center justify-center">
                    <UserIcon className="w-12 h-12 text-white" />
                  </div>
                )}
                <input
                  ref={profileImageRef}
                  type="file"
                  accept="image/*"
                  onChange={(e) => handleImageChange(e, 'profile_image')}
                  className="hidden"
                />
                <button
                  type="button"
                  onClick={() => profileImageRef.current?.click()}
                  className="absolute bottom-0 right-0 bg-fopcam-500 text-white p-2 rounded-full hover:bg-fopcam-600 transition-colors"
                >
                  <CameraIcon className="w-4 h-4" />
                </button>
                {profile?.profile_image && (
                  <button
                    type="button"
                    onClick={() => removeImage('profile_image')}
                    className="absolute -top-2 -right-2 bg-red-500 text-white p-1 rounded-full hover:bg-red-600 transition-colors"
                  >
                    <XMarkIcon className="w-3 h-3" />
                  </button>
                )}
              </div>
              <div>
                <h3 className="text-lg font-semibold text-gray-900">Photo de profil</h3>
                <p className="text-gray-600 text-sm">JPG, PNG ou GIF. Taille max: 5MB</p>
              </div>
            </div>
          </div>

          {/* Form Fields */}
          <div className="bg-white rounded-2xl shadow-xl p-6">
            <h2 className="text-xl font-semibold text-gray-900 mb-6">Informations personnelles</h2>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  Prénom
                </label>
                <input
                  type="text"
                  name="first_name"
                  value={formData.first_name}
                  onChange={handleInputChange}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-fopcam-500 focus:border-transparent"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  Nom
                </label>
                <input
                  type="text"
                  name="last_name"
                  value={formData.last_name}
                  onChange={handleInputChange}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-fopcam-500 focus:border-transparent"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  Téléphone
                </label>
                <input
                  type="tel"
                  name="phone"
                  value={formData.phone}
                  onChange={handleInputChange}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-fopcam-500 focus:border-transparent"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  Site web
                </label>
                <input
                  type="url"
                  name="website"
                  value={formData.website}
                  onChange={handleInputChange}
                  placeholder="https://..."
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-fopcam-500 focus:border-transparent"
                />
              </div>

              <div className="md:col-span-2">
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  Adresse
                </label>
                <input
                  type="text"
                  name="address"
                  value={formData.address}
                  onChange={handleInputChange}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-fopcam-500 focus:border-transparent"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  Ville
                </label>
                <input
                  type="text"
                  name="city"
                  value={formData.city}
                  onChange={handleInputChange}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-fopcam-500 focus:border-transparent"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  Pays
                </label>
                <input
                  type="text"
                  name="country"
                  value={formData.country}
                  onChange={handleInputChange}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-fopcam-500 focus:border-transparent"
                />
              </div>

              <div className="md:col-span-2">
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  Biographie
                </label>
                <textarea
                  name="bio"
                  value={formData.bio}
                  onChange={handleInputChange}
                  rows={4}
                  maxLength={500}
                  placeholder="Parlez de vous..."
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-fopcam-500 focus:border-transparent resize-none"
                />
                <p className="text-xs text-gray-500 mt-1">{formData.bio.length}/500 caractères</p>
              </div>
            </div>
          </div>

          {/* Messages */}
          {error && (
            <div className="bg-red-50 border border-red-200 rounded-lg p-4">
              <div className="flex">
                <div className="flex-shrink-0">
                  <XMarkIcon className="h-5 w-5 text-red-400" />
                </div>
                <div className="ml-3">
                  <p className="text-sm text-red-700">{error}</p>
                </div>
              </div>
            </div>
          )}

          {success && (
            <div className="bg-green-50 border border-green-200 rounded-lg p-4">
              <div className="flex">
                <div className="flex-shrink-0">
                  <svg className="h-5 w-5 text-green-400" fill="currentColor" viewBox="0 0 20 20">
                    <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clipRule="evenodd" />
                  </svg>
                </div>
                <div className="ml-3">
                  <p className="text-sm text-green-700">Profil mis à jour avec succès ! Redirection en cours...</p>
                </div>
              </div>
            </div>
          )}

          {/* Actions */}
          <div className="flex gap-4">
            <button
              type="submit"
              disabled={saving}
              className="flex-1 bg-fopcam-500 text-white py-3 px-6 rounded-lg hover:bg-fopcam-600 disabled:opacity-50 disabled:cursor-not-allowed transition-colors font-medium"
            >
              {saving ? (
                <div className="flex items-center justify-center">
                  <div className="animate-spin rounded-full h-5 w-5 border-b-2 border-white mr-2"></div>
                  Sauvegarde...
                </div>
              ) : (
                'Sauvegarder les modifications'
              )}
            </button>
            <Link
              href={`/profile/${profile?.user?.username}`}
              className="px-6 py-3 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50 transition-colors font-medium"
            >
              Annuler
            </Link>
          </div>
        </form>
      </div>
    </div>
  )
}

export default EditProfilePage