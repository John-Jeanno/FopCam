import { useState, useEffect } from 'react'
import { useRouter } from 'next/router'
import { motion } from 'framer-motion'
import { ArrowLeftIcon, MapPinIcon, PhoneIcon, GlobeAltIcon, BuildingStorefrontIcon } from '@heroicons/react/24/outline'

export default function CreateShop() {
  const [form, setForm] = useState({
    name: '',
    description: '',
    location: '',
    latitude: '',
    longitude: '',
    phone: '',
    email: '',
    website: ''
  })
  const [message, setMessage] = useState(null)
  const [loading, setLoading] = useState(false)
  const [existingShop, setExistingShop] = useState(null)
  const router = useRouter()
  const apiUrl = process.env.NEXT_PUBLIC_API_URL || 'http://127.0.0.1:8000'

  useEffect(() => {
    const token = localStorage.getItem('access')
    if (!token) {
      router.replace('/login')
      return
    }

    // Vérifier si l'utilisateur a déjà une boutique
    fetch(apiUrl + '/api/shops/my/', {
      headers: { 'Authorization': 'Bearer ' + token }
    })
      .then(r => {
        if (r.status === 401 || r.status === 403) {
          localStorage.removeItem('access')
          localStorage.removeItem('access_token')
          localStorage.removeItem('refresh')
          router.replace('/login')
          throw new Error('Unauthorized')
        }
        return r.json()
      })
      .then(data => {
        if (data && data.id) {
          setExistingShop(data)
          setForm({
            name: data.name || '',
            description: data.description || '',
            location: data.location || '',
            latitude: data.latitude || '',
            longitude: data.longitude || '',
            phone: data.phone || '',
            email: data.email || '',
            website: data.website || ''
          })
        }
      })
      .catch(err => console.log('Pas de boutique existante', err))
  }, [])

  const submit = async (e) => {
    e.preventDefault()
    setLoading(true)
    setMessage(null)

    const token = localStorage.getItem('access')
    if (!token) {
      setMessage({ type: 'error', text: 'Vous devez être connecté' })
      setLoading(false)
      return
    }

    try {
      const url = existingShop
        ? apiUrl + `/api/shops/${existingShop.id}/`
        : apiUrl + '/api/shops/'

      const res = await fetch(url, {
        method: existingShop ? 'PUT' : 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ' + token
        },
        body: JSON.stringify(form)
      })

      if (res.status === 401 || res.status === 403) {
        localStorage.removeItem('access')
        localStorage.removeItem('access_token')
        localStorage.removeItem('refresh')
        setMessage({
          type: 'error',
          text: 'Session expirée ou non authentifiée. Veuillez vous reconnecter.'
        })
        router.replace('/login')
        return
      }

      if (res.ok) {
        const shopData = await res.json()
        setMessage({
          type: 'success',
          text: existingShop ? 'Boutique mise à jour !' : 'Boutique créée avec succès !'
        })
        setTimeout(() => router.push('/producer/dashboard'), 2000)
      } else {
        const error = await res.json().catch(() => null)
        setMessage({
          type: 'error',
          text: error?.detail || error?.message || 'Erreur lors de la création de la boutique'
        })
      }
    } catch (error) {
      setMessage({ type: 'error', text: error?.message || 'Erreur de connexion au serveur' })
    } finally {
      setLoading(false)
    }
  }

  const inputFields = [
    {
      name: 'name',
      label: 'Nom de la boutique',
      type: 'text',
      placeholder: 'Ma Ferme Bio',
      icon: BuildingStorefrontIcon,
      required: true
    },
    {
      name: 'description',
      label: 'Description',
      type: 'textarea',
      placeholder: 'Décrivez votre exploitation, vos produits, vos valeurs...',
      required: true
    },
    {
      name: 'location',
      label: 'Adresse complète',
      type: 'text',
      placeholder: '123 Rue de la Ferme, Dakar, Sénégal',
      icon: MapPinIcon,
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
      name: 'email',
      label: 'Email professionnel',
      type: 'email',
      placeholder: 'contact@mafermebio.sn'
    },
    {
      name: 'website',
      label: 'Site web (optionnel)',
      type: 'url',
      placeholder: 'https://www.mafermebio.sn',
      icon: GlobeAltIcon
    }
  ]

  return (
    <div className="min-h-screen bg-gradient-to-br from-future-900 via-future-800 to-fopcam-900 p-4">
      <div className="max-w-4xl mx-auto">
        {/* Header */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          className="mb-8"
        >
          <button
            onClick={() => router.back()}
            className="inline-flex items-center text-future-300 hover:text-white transition-colors mb-4"
          >
            <ArrowLeftIcon className="w-5 h-5 mr-2" />
            Retour
          </button>

          <div className="text-center">
            <div className="w-16 h-16 bg-gradient-fopcam rounded-2xl flex items-center justify-center mx-auto mb-4">
              <BuildingStorefrontIcon className="w-8 h-8 text-white" />
            </div>
            <h1 className="text-3xl font-bold text-white mb-2">
              {existingShop ? 'Modifier ma boutique' : 'Créer ma boutique'}
            </h1>
            <p className="text-future-300">
              {existingShop
                ? 'Mettez à jour les informations de votre boutique'
                : 'Configurez votre espace de vente sur FopCam'
              }
            </p>
          </div>
        </motion.div>

        {/* Form */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.2 }}
          className="glass-effect rounded-3xl p-8 shadow-2xl"
        >
          <form onSubmit={submit} className="space-y-6">
            <div className="grid md:grid-cols-2 gap-6">
              {inputFields.map((field, index) => (
                <motion.div
                  key={field.name}
                  initial={{ opacity: 0, x: index % 2 === 0 ? -20 : 20 }}
                  animate={{ opacity: 1, x: 0 }}
                  transition={{ delay: 0.3 + index * 0.1 }}
                  className={field.name === 'description' ? 'md:col-span-2' : ''}
                >
                  <label className="block text-sm font-medium text-future-200 mb-2">
                    {field.label} {field.required && <span className="text-red-400">*</span>}
                  </label>
                  <div className="relative">
                    {field.type === 'textarea' ? (
                      <textarea
                        name={field.name}
                        value={form[field.name]}
                        onChange={e => setForm({ ...form, [field.name]: e.target.value })}
                        className="input-field bg-white/10 border-white/20 text-white placeholder-future-400 focus:border-fopcam-400 focus:ring-fopcam-400/20 min-h-[100px] resize-vertical"
                        placeholder={field.placeholder}
                        required={field.required}
                      />
                    ) : (
                      <input
                        type={field.type}
                        name={field.name}
                        value={form[field.name]}
                        onChange={e => setForm({ ...form, [field.name]: e.target.value })}
                        className="input-field bg-white/10 border-white/20 text-white placeholder-future-400 focus:border-fopcam-400 focus:ring-fopcam-400/20"
                        placeholder={field.placeholder}
                        required={field.required}
                      />
                    )}
                    {field.icon && (
                      <div className="absolute left-3 top-1/2 transform -translate-y-1/2 text-future-400">
                        <field.icon className="w-5 h-5" />
                      </div>
                    )}
                  </div>
                </motion.div>
              ))}
            </div>

            <motion.div
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.9 }}
              className="pt-4"
            >
              <button
                type="submit"
                disabled={loading}
                className="w-full btn-primary bg-gradient-fopcam hover:bg-gradient-fopcam disabled:opacity-50 disabled:cursor-not-allowed disabled:transform-none"
              >
                {loading ? (
                  <div className="flex items-center justify-center">
                    <div className="animate-spin rounded-full h-5 w-5 border-b-2 border-white mr-2"></div>
                    {existingShop ? 'Mise à jour...' : 'Créer ma boutique'}
                  </div>
                ) : (
                  existingShop ? 'Mettre à jour ma boutique' : 'Créer ma boutique'
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
        </motion.div>
      </div>
    </div>
  )
}