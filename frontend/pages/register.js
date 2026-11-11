import { useState, useEffect } from 'react'
import { useRouter } from 'next/router'
import Link from 'next/link'
import { motion } from 'framer-motion'
import { EyeIcon, EyeSlashIcon, ArrowLeftIcon, UserIcon, EnvelopeIcon, LockClosedIcon, PhoneIcon, MapPinIcon } from '@heroicons/react/24/outline'
import { GoogleOAuthProvider, GoogleLogin } from '@react-oauth/google'

export default function RegisterPage() {
  const googleClientId = process.env.NEXT_PUBLIC_GOOGLE_CLIENT_ID?.trim() || ''

  return (
    <Register googleClientId={googleClientId} />
  )
}

function Register({ googleClientId }) {
  const [form, setForm] = useState({
    username: '',
    email: '',
    password: '',
    first_name: '',
    last_name: '',
    phone: '',
    motorcycle_plate: '',
    address: '',
    city: '',
    country: 'Sénégal',
    latitude: '',
    longitude: ''
  })
  const [profileImage, setProfileImage] = useState(null)
  const [message, setMessage] = useState(null)
  const [fieldErrors, setFieldErrors] = useState({})
  const [loading, setLoading] = useState(false)
  const [showPassword, setShowPassword] = useState(false)
  const [userType, setUserType] = useState('buyer')
  const [locationLoading, setLocationLoading] = useState(false)
  const [locationError, setLocationError] = useState(null)
  const router = useRouter()

  const isGoogleConfigured = !!googleClientId && !googleClientId.toLowerCase().includes('your_google_client_id')

  // Vérifier si Google OAuth est correctement configuré
  const [googleConfigError, setGoogleConfigError] = useState(null)

  useEffect(() => {
    if (!isGoogleConfigured) {
      return
    }

    const handleGoogleScriptError = (e) => {
      if (e.message && e.message.includes('The given origin is not allowed')) {
        setGoogleConfigError('L\'origine http://localhost:3000 n\'est pas autorisée dans votre configuration Google OAuth. Veuillez ajouter cette URL dans la console Google Developers.')
      }
    }

    const timeout = setTimeout(() => {
      const gsiScript = document.querySelector('script[src*="accounts.google.com"]')
      if (gsiScript) {
        window.addEventListener('error', handleGoogleScriptError)
      }
    }, 2000)

    return () => {
      clearTimeout(timeout)
      window.removeEventListener('error', handleGoogleScriptError)
    }
  }, [isGoogleConfigured])


  // Renvoie une Promise pour obtenir la position. options peut être passé
  const getCurrentPosition = (options = { enableHighAccuracy: true, timeout: 15000, maximumAge: 60000 }) => {
    return new Promise((resolve, reject) => {
      if (!navigator.geolocation) {
        reject(new Error('Géolocalisation non disponible sur cet appareil.'))
        return
      }

      navigator.geolocation.getCurrentPosition(
        position => resolve(position),
        error => reject(error),
        options
      )
    })
  }

  const apiUrl = process.env.NEXT_PUBLIC_API_URL?.trim().replace(/%$/, '') || 'http://127.0.0.1:8000'

  const formatErrorText = (errorData, fallback) => {
    if (!errorData) return fallback
    if (typeof errorData === 'string') return errorData
    if (typeof errorData.error === 'string') return errorData.error
    if (typeof errorData.detail === 'string') return errorData.detail
    if (errorData.error) return JSON.stringify(errorData.error)
    if (errorData.detail) return JSON.stringify(errorData.detail)
    return JSON.stringify(errorData)
  }

  const handleGoogleSuccess = async (credentialResponse) => {
    try {
      setLoading(true)
      setMessage({ type: 'info', text: 'Authentification Google en cours...' })

      if (!credentialResponse?.credential) {
        throw new Error('Aucun jeton Google reçu.')
      }

      const res = await fetch(apiUrl + '/api/auth/google/', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          id_token: credentialResponse.credential,
          provider: 'google'
        })
      })

      if (res.ok) {
        const data = await res.json()
        
        // Store tokens in localStorage for development
        if (data.access && data.refresh) {
          localStorage.setItem('access_token', data.access)
          localStorage.setItem('refresh_token', data.refresh)
          localStorage.setItem('access', data.access)
          localStorage.setItem('refresh', data.refresh)
        }

        // Try to get profile with token from localStorage
        const accessToken = localStorage.getItem('access_token')
        const profileRes = await fetch(apiUrl + '/api/auth/profile/', {
          headers: {
            'Authorization': `Bearer ${accessToken}`
          }
        })
        const profile = profileRes.ok ? await profileRes.json() : null
        const isProducerCandidate = profile?.role === 'producer' || !!profile?.shop_id
        const redirectUrl = router.query.next || (isProducerCandidate ? '/producer/dashboard' : '/client/dashboard')

        setMessage({ type: 'success', text: 'Connexion réussie avec Google ! Redirection en cours...' })
        setTimeout(() => {
          router.replace(redirectUrl)
        }, 500)
      } else {
        const errorData = await res.json().catch(() => null)
        setMessage({ type: 'error', text: formatErrorText(errorData, 'Erreur lors de la connexion Google') })
      }
    } catch (error) {
      setMessage({ type: 'error', text: 'Erreur: ' + (error?.message || 'Échec de la connexion Google') })
    } finally {
      setLoading(false)
    }
  }


  const requestDeviceLocation = async () => {
    setLocationLoading(true)
    setLocationError(null)

    // 1) Essayer d'abord une position rapide (faible précision, timeout court)
    const quickOptions = { enableHighAccuracy: false, timeout: 3000, maximumAge: 600000 }
    let quickPosition = null

    try {
      quickPosition = await getCurrentPosition(quickOptions)
      setForm(prev => ({
        ...prev,
        latitude: quickPosition.coords.latitude.toFixed(6),
        longitude: quickPosition.coords.longitude.toFixed(6)
      }))
      // on considère que la position rapide est suffisante pour l'inscription
      setLocationLoading(false)
      setLocationError(null)
    } catch (err) {
      // quick attempt failed — on va essayer la haute précision ci-dessous (bloquant)
    }

    // 2) En arrière-plan, tenter une version haute précision mais ne pas bloquer l'UI
    (async () => {
      try {
        const highOptions = { enableHighAccuracy: true, timeout: 10000, maximumAge: 60000 }
        const highPos = await getCurrentPosition(highOptions)
        setForm(prev => ({
          ...prev,
          latitude: highPos.coords.latitude.toFixed(6),
          longitude: highPos.coords.longitude.toFixed(6)
        }))
        setLocationError(null)
      } catch (error) {
        // Si aucune position n'a jamais été définie, remonter l'erreur.
        if (!quickPosition) {
          const errorMessage = error?.message || 'Impossible d\'obtenir la position de l\'appareil.'
          setLocationError(errorMessage)
        }
      } finally {
        // Assurer que l'état loading est remis à false si la tentative background arrive en dernier
        setLocationLoading(false)
      }
    })()
  }

  useEffect(() => {
    requestDeviceLocation()
  }, [])

  const submit = async (e) => {
    e.preventDefault()
    setLoading(true)
    setMessage(null)
    setFieldErrors({})

    try {
      // Préparer les données
      const submissionData = { ...form }

      if (!submissionData.latitude || !submissionData.longitude) {
        // Ne pas bloquer trop longtemps l'envoi : essayer une tentative rapide puis continuer
        try {
          setMessage({ type: 'info', text: 'Obtention rapide de votre position...' })
          const quickOpts = { enableHighAccuracy: false, timeout: 3000, maximumAge: 600000 }
          const position = await getCurrentPosition(quickOpts)
          submissionData.latitude = position.coords.latitude.toFixed(6)
          submissionData.longitude = position.coords.longitude.toFixed(6)
          setForm(prev => ({
            ...prev,
            latitude: submissionData.latitude,
            longitude: submissionData.longitude
          }))
        } catch (error) {
          // Tentative rapide échouée : on passe sans bloquer. L'utilisateur pourra ajouter plus tard.
          setMessage({ type: 'warning', text: 'Inscription sans géolocalisation. Vous pourrez ajouter votre position plus tard.' })
        }
      }

      const formData = new FormData()

      // Ajouter les champs du formulaire
      Object.keys(submissionData).forEach(key => {
        const value = submissionData[key]

        if (key === 'latitude' || key === 'longitude') {
          if (value !== '' && value !== null && value !== undefined && !Number.isNaN(Number(value))) {
            formData.append(key, value.toString())
          }
        } else {
          formData.append(key, value)
        }
      })

      // Ajouter le type d'utilisateur
      formData.append('user_type', userType)

      // Ajouter l'image de profil si elle existe
      if (profileImage) {
        formData.append('profile_image', profileImage)
      }

      const res = await fetch(apiUrl + '/api/auth/register/', {
        method: 'POST',
        body: formData // Pas de Content-Type header pour FormData
      })

      if (res.ok) {
        const nextQuery = router.query.next ? `&next=${encodeURIComponent(router.query.next)}` : ''
        setMessage({ type: 'success', text: 'Inscription réussie ! Redirection vers la page de connexion...' })
        setTimeout(() => router.push(`/login?registered=1${nextQuery}`), 1000)
      } else {
        let errorBody = null
        let errorText = null

        try {
          errorBody = await res.json()
        } catch {
          errorText = await res.text().catch(() => null)
          errorBody = { detail: `Erreur serveur ${res.status}: ${errorText || res.statusText}` }
        }

        // Extraire les erreurs par champ
        const errors = {}
        let hasFieldErrors = false

        if (errorBody && typeof errorBody === 'object') {
          Object.keys(errorBody).forEach(key => {
            const value = errorBody[key]
            if (Array.isArray(value)) {
              errors[key] = value.join(', ')
              hasFieldErrors = true
            } else if (typeof value === 'object' && value !== null && value.message) {
              errors[key] = value.message
              hasFieldErrors = true
            } else if (typeof value === 'string' && key !== 'detail') {
              errors[key] = value
              hasFieldErrors = true
            }
          })

          if (!hasFieldErrors && typeof errorBody.detail === 'string') {
            errors.non_field_errors = errorBody.detail
          }
        }

        if (hasFieldErrors) {
          setFieldErrors(errors)
          const fields = Object.keys(errors).filter(key => key !== 'non_field_errors')
          const fieldLabel = fields.length === 1 ? `le champ « ${fields[0]} »` : fields.length > 1 ? `les champs « ${fields.join(' », « ')} »` : null
          const fieldMessage = fieldLabel ? `Erreur sur ${fieldLabel}.` : 'Veuillez corriger les erreurs ci-dessous.'
          setMessage({ type: 'error', text: fieldMessage })
        } else {
          setMessage({
            type: 'error',
            text: errorBody.detail || errorBody.error || `Erreur lors de l'inscription. (${res.status} ${res.statusText})`
          })
        }
      }
    } catch (error) {
      setMessage({ type: 'error', text: error?.message || 'Erreur de connexion au serveur' })
    } finally {
      setLoading(false)
    }
  }

  const inputFields = [
    {
      name: 'username',
      label: 'Nom d\'utilisateur',
      type: 'text',
      placeholder: 'Votre nom d\'utilisateur',
      icon: UserIcon,
      required: true
    },
    {
      name: 'email',
      label: 'Adresse email',
      type: 'email',
      placeholder: 'votre.email@exemple.com',
      icon: EnvelopeIcon,
      required: true
    },
    {
      name: 'first_name',
      label: 'Prénom',
      type: 'text',
      placeholder: 'Votre prénom',
      required: true
    },
    {
      name: 'last_name',
      label: 'Nom',
      type: 'text',
      placeholder: 'Votre nom de famille',
      required: true
    },
    {
      name: 'phone',
      label: 'Téléphone',
      type: 'tel',
      placeholder: '+221 XX XXX XX XX',
      icon: PhoneIcon,
      required: true
    },
    {
      name: 'address',
      label: 'Adresse',
      type: 'text',
      placeholder: 'Votre adresse complète',
      icon: MapPinIcon,
      required: true
    },
    {
      name: 'city',
      label: 'Ville',
      type: 'text',
      placeholder: 'Votre ville',
      required: true
    },
    {
      name: 'country',
      label: 'Pays',
      type: 'text',
      placeholder: 'Votre pays',
      required: true
    },
  ]

  return (
    <div className="min-h-screen bg-gradient-to-br from-future-900 via-future-800 to-fopcam-900 flex items-center justify-center p-4">
      {/* Background Pattern */}
      <div className="absolute inset-0 opacity-10">
        <div className="absolute inset-0" style={{
          backgroundImage: `url("data:image/svg+xml,%3Csvg width='60' height='60' viewBox='0 0 60 60' xmlns='http://www.w3.org/2000/svg'%3E%3Cg fill='none' fill-rule='evenodd'%3E%3Cg fill='%23ffffff' fill-opacity='0.1'%3E%3Ccircle cx='30' cy='30' r='2'/%3E%3C/g%3E%3C/g%3E%3C/svg%3E")`,
        }}></div>
      </div>

      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        className="relative w-full max-w-2xl"
      >
        {/* Back Button */}
        <Link href="/" className="inline-flex items-center text-future-300 hover:text-white transition-colors mb-8">
          <ArrowLeftIcon className="w-5 h-5 mr-2" />
          Retour à l'accueil
        </Link>

        {/* Register Card */}
        <div className="glass-effect rounded-3xl p-8 shadow-2xl">
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ delay: 0.2 }}
            className="text-center mb-8"
          >
            <div className="w-40 h-40 rounded-2xl flex items-center justify-center mx-auto mb-4 overflow-hidden bg-white/10">
              <img src={`${process.env.NEXT_PUBLIC_BASE_PATH || ''}/fopcam-logo.png`} alt="FopCam" className="w-full h-full object-contain" />
            </div>
            <p className="text-future-300">Créez votre compte et commencez votre aventure</p>
          </motion.div>

          {/* User Type Selection */}
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.3 }}
            className="mb-8"
          >
            <label className="block text-sm font-medium text-future-200 mb-4">
              Je suis :
            </label>
            <div className="grid grid-cols-1 gap-4 sm:grid-cols-3">
              <button
                type="button"
                onClick={() => setUserType('buyer')}
                className={`p-4 rounded-xl border-2 transition-all ${
                  userType === 'buyer'
                    ? 'border-fopcam-400 bg-fopcam-400/20 text-fopcam-200'
                    : 'border-white/20 bg-white/5 text-future-300 hover:border-white/40'
                }`}
              >
                <UserIcon className="w-8 h-8 mx-auto mb-2" />
                <div className="font-medium">Visiteur</div>
                <div className="text-sm opacity-75">Découvrir les produits</div>
              </button>
              <button
                type="button"
                onClick={() => setUserType('producer')}
                className={`p-4 rounded-xl border-2 transition-all ${
                  userType === 'producer'
                    ? 'border-fopcam-400 bg-fopcam-400/20 text-fopcam-200'
                    : 'border-white/20 bg-white/5 text-future-300 hover:border-white/40'
                }`}
              >
                <UserIcon className="w-8 h-8 mx-auto mb-2" />
                <div className="font-medium">Vendeur</div>
                <div className="text-sm opacity-75">Vendre mes produits</div>
              </button>
              <button
                type="button"
                onClick={() => setUserType('driver')}
                className={`p-4 rounded-xl border-2 transition-all ${
                  userType === 'driver'
                    ? 'border-fopcam-400 bg-fopcam-400/20 text-fopcam-200'
                    : 'border-white/20 bg-white/5 text-future-300 hover:border-white/40'
                }`}
              >
                <UserIcon className="w-8 h-8 mx-auto mb-2" />
                <div className="font-medium">Livreur</div>
                <div className="text-sm opacity-75">Livrer des commandes</div>
              </button>
            </div>
            {fieldErrors['user_type'] && (
              <p className="text-red-400 text-sm mt-2">{fieldErrors['user_type']}</p>
            )}
            {userType === 'driver' && (
              <p className="mt-4 text-sm text-future-300">Les livreurs doivent fournir le matricule de la moto pour s'inscrire.</p>
            )}
          </motion.div>

          {/* OAuth Sign In */}
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.35 }}
            className="mb-8"
          >
            <div className="relative mb-6">
              <div className="absolute inset-0 flex items-center">
                <div className="w-full border-t border-white/20"></div>
              </div>
              <div className="relative flex justify-center text-sm">
                <span className="px-2 bg-gradient-to-br from-future-900 via-future-800 to-fopcam-900 text-future-300">
                  Ou s'inscrire avec
                </span>
              </div>
            </div>

            <div className="grid grid-cols-1 gap-4">
              {/* Google OAuth */}
              <motion.div
                initial={{ opacity: 0, x: -10 }}
                animate={{ opacity: 1, x: 0 }}
                transition={{ delay: 0.38 }}
              >
                {isGoogleConfigured ? (
                  <GoogleOAuthProvider clientId={googleClientId}>
                    <GoogleLogin
                      onSuccess={handleGoogleSuccess}
                      onError={() => setMessage({ type: 'error', text: 'Erreur lors de la connexion Google' })}
                      text="signup_with"
                      locale="fr_FR"
                    />
                  </GoogleOAuthProvider>
                ) : (
                  <button
                    type="button"
                    disabled
                    className="w-full px-4 py-2.5 bg-white/10 border border-white/20 text-future-400 rounded-lg cursor-not-allowed"
                  >
                    Google non configuré
                  </button>
                )}
              </motion.div>
            </div>
            {!isGoogleConfigured && (
              <div className="mt-4 text-sm text-yellow-200">
                Google OAuth n'est pas configuré. Vérifiez `NEXT_PUBLIC_GOOGLE_CLIENT_ID` dans `frontend/.env.local`.
              </div>
            )}
            {googleConfigError && (
              <div className="mt-4 text-sm text-red-300 bg-red-900/20 border border-red-500/30 rounded-lg p-3">
                <strong>Configuration Google OAuth incomplète:</strong><br />
                {googleConfigError}
              </div>
            )}
          </motion.div>

          <form onSubmit={submit} className="space-y-6">
            <div className="grid md:grid-cols-2 gap-6">
                {inputFields.map((field, index) => (
                <motion.div
                  key={field.name}
                  initial={{ opacity: 0, x: index % 2 === 0 ? -20 : 20 }}
                  animate={{ opacity: 1, x: 0 }}
                  transition={{ delay: 0.4 + index * 0.1 }}
                  className={field.name === 'username' || field.name === 'email' ? 'md:col-span-2' : ''}
                >
                  <label className="block text-sm font-medium text-future-200 mb-2">
                    {field.label} {field.required && <span className="text-red-400">*</span>}
                  </label>
                  <div className="relative">
                    <input
                      type={field.type}
                      name={field.name}
                      value={form[field.name]}
                      onChange={e => {
                        const newValue = e.target.value
                        setForm(prev => ({ ...prev, [field.name]: newValue }))
                        if (field.name === 'address' || field.name === 'city' || field.name === 'country') {
                          setLocationError(null)
                        }
                      }}
                      className={`input-field bg-white/10 text-white placeholder-future-400 focus:ring-fopcam-400/20 ${
                        fieldErrors[field.name]
                          ? 'border-red-400/50 focus:border-red-400'
                          : 'border-white/20 focus:border-fopcam-400'
                      }`}
                      placeholder={field.placeholder}
                      required={field.required}
                      step={field.step}
                    />
                    {field.icon && (
                      <div className="absolute left-3 top-1/2 transform -translate-y-1/2 text-future-400">
                        <field.icon className="w-5 h-5" />
                      </div>
                    )}
                  </div>
                  {fieldErrors[field.name] && (
                    <p className="text-red-400 text-sm mt-1">{fieldErrors[field.name]}</p>
                  )}
                </motion.div>
              ))}

              {userType === 'driver' && (
                <motion.div
                  initial={{ opacity: 0, x: -20 }}
                  animate={{ opacity: 1, x: 0 }}
                  transition={{ delay: 0.45 }}
                  className=""
                >
                  <label className="block text-sm font-medium text-future-200 mb-2">
                    Matricule de la moto <span className="text-red-400">*</span>
                  </label>
                  <div className="relative">
                    <input
                      type="text"
                      name="motorcycle_plate"
                      value={form.motorcycle_plate}
                      onChange={e => setForm(prev => ({ ...prev, motorcycle_plate: e.target.value }))}
                      className={`input-field bg-white/10 text-white placeholder-future-400 focus:ring-fopcam-400/20 ${
                        fieldErrors['motorcycle_plate']
                          ? 'border-red-400/50 focus:border-red-400'
                          : 'border-white/20 focus:border-fopcam-400'
                      }`}
                      placeholder="1234AB56"
                      required
                    />
                  </div>
                  {fieldErrors['motorcycle_plate'] && (
                    <p className="text-red-400 text-sm mt-1">{fieldErrors['motorcycle_plate']}</p>
                  )}
                </motion.div>
              )}

              {/* Password Field */}
              <motion.div
                initial={{ opacity: 0, x: -20 }}
                animate={{ opacity: 1, x: 0 }}
                transition={{ delay: 0.8 }}
                className="md:col-span-2"
              >
                <label className="block text-sm font-medium text-future-200 mb-2">
                  Mot de passe <span className="text-red-400">*</span>
                </label>
                <div className="relative">
                  <input
                    type={showPassword ? "text" : "password"}
                    name="password"
                    value={form.password}
                    onChange={e => setForm({ ...form, password: e.target.value })}
                    className={`input-field bg-white/10 text-white placeholder-future-400 focus:ring-fopcam-400/20 pr-12 ${
                      fieldErrors['password']
                        ? 'border-red-400/50 focus:border-red-400'
                        : 'border-white/20 focus:border-fopcam-400'
                    }`}
                    placeholder="Votre mot de passe"
                    required
                  />
                  <button
                    type="button"
                    onClick={() => setShowPassword(!showPassword)}
                    className="absolute right-3 top-1/2 transform -translate-y-1/2 text-future-400 hover:text-future-200 transition-colors"
                  >
                    {showPassword ? (
                      <EyeSlashIcon className="w-5 h-5" />
                    ) : (
                      <EyeIcon className="w-5 h-5" />
                    )}
                  </button>
                </div>
                {fieldErrors['password'] && (
                  <p className="text-red-400 text-sm mt-1">{fieldErrors['password']}</p>
                )}
              </motion.div>
            </div>
            {locationLoading && (
              <motion.div
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: 0.75 }}
                className="md:col-span-2"
              >
                <div className="text-sm text-fopcam-200 bg-white/5 border border-fopcam-400/20 rounded-xl p-4">
                  <div className="flex items-center gap-2">
                    <div className="h-3 w-3 rounded-full border border-fopcam-400 border-t-transparent animate-spin" />
                    <span>Obtention de votre position exacte...</span>
                  </div>
                </div>
              </motion.div>
            )}
            {!locationLoading && form.latitude && form.longitude && (
              <motion.div
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: 0.75 }}
                className="md:col-span-2"
              >
                <div className="text-sm text-green-300 bg-white/5 border border-green-400/20 rounded-xl p-4">
                  Position exacte détectée automatiquement.
                </div>
              </motion.div>
            )}
            {!locationLoading && locationError && (
              <motion.div
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: 0.75 }}
                className="md:col-span-2"
              >
                <div className="text-sm text-red-300 bg-white/5 border border-red-400/20 rounded-xl p-4">
                  {locationError}
                </div>
              </motion.div>
            )}

            {/* Profile Image Field */}
            <motion.div
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.85 }}
              className="md:col-span-2"
            >
              <label className="block text-sm font-medium text-future-200 mb-2">
                Photo de profil (optionnel)
              </label>
              <div className="relative">
                <input
                  type="file"
                  accept="image/*"
                  onChange={e => setProfileImage(e.target.files[0])}
                  className="input-field bg-white/10 border-white/20 text-white placeholder-future-400 focus:border-fopcam-400 focus:ring-fopcam-400/20 file:mr-4 file:py-2 file:px-4 file:rounded-lg file:border-0 file:text-sm file:font-medium file:bg-fopcam-400 file:text-white hover:file:bg-fopcam-500"
                />
              </div>
              {profileImage && (
                <div className="mt-2">
                  <img
                    src={URL.createObjectURL(profileImage)}
                    alt="Aperçu"
                    className="w-16 h-16 rounded-full object-cover border-2 border-fopcam-400"
                  />
                </div>
              )}
            </motion.div>

            <motion.div
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.9 }}
            >
              <button
                type="submit"
                disabled={loading}
                className="w-full btn-primary bg-gradient-fopcam hover:bg-gradient-fopcam disabled:opacity-50 disabled:cursor-not-allowed disabled:transform-none"
              >
                {loading ? (
                  <div className="flex items-center justify-center">
                    <div className="animate-spin rounded-full h-5 w-5 border-b-2 border-white mr-2"></div>
                    Inscription...
                  </div>
                ) : (
                  'Créer mon compte'
                )}
              </button>
            </motion.div>
          </form>

          {/* Message */}
          {message && (
            <motion.div
              initial={{ opacity: 0, scale: 0.9 }}
              animate={{ opacity: 1, scale: 1 }}
              className={`mt-6 p-4 rounded-xl ${
                message.type === 'success'
                  ? 'bg-fopcam-500/20 border border-fopcam-400/30 text-fopcam-200'
                  : 'bg-red-500/20 border border-red-400/30 text-red-200'
              }`}
            >
              {message.text}
            </motion.div>
          )}

          {/* Links */}
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ delay: 1.0 }}
            className="mt-8 text-center"
          >
            <p className="text-future-300">
              Déjà un compte ?{' '}
              <Link href="/login" className="text-fopcam-400 hover:text-fopcam-300 font-medium transition-colors">
                Se connecter
              </Link>
            </p>
          </motion.div>
        </div>

        {/* Footer */}
        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ delay: 1.2 }}
          className="text-center mt-8 text-future-400 text-sm px-4"
        >
          <p className="break-words">© 2025 FopCam - Le premier réseau social et marketplace pour connecter vendeurs et consommateurs en circuit court</p>
        </motion.div>
      </motion.div>
    </div>
  )
}
